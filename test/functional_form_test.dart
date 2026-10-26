// Functional tests for the create-bill form: driven through the
// real CreateBillForm notifier in a ProviderContainer whose data
// providers are overridden with the real repository (real SQLite),
// so validation, split math and currency resolution are exercised
// exactly as the screen drives them.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart' hide group;
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';

import 'test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  const uid = 'me';
  late LocalDatabase db;
  late AppRepository repo;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<List<AppUser>>> sub;
  late ProviderSubscription<CreateBillFormState> formSub;

  const friendC = AppUser(
    uid: 'fc',
    displayName: 'Friend C',
    email: 'c@example.com',
  );

  setUp(() async {
    await LocalDatabase.deleteForUid(uid);
    db = await LocalDatabase.open(uid);
    repo = AppRepository(
      db: db,
      remote: FirestoreService(),
      secure: SecureStorageService(),
      myUid: uid,
    );
    await db.upsertUser('me', meUser.toProfileMap());
    await db.upsertUser('fa', friendA.toProfileMap());
    await db.upsertUser('fb', friendB.toProfileMap());

    container = ProviderContainer(overrides: [
      currentUidProvider.overrideWithValue(uid),
      appRepositoryProvider.overrideWith((ref) async => repo),
      createBillMembersProvider
          .overrideWith((ref) async => [meUser, friendA, friendB, friendC]),
      myGroupsProvider.overrideWith((ref) => Stream.value(const [])),
    ]);
    // The screen always has the member list loaded before submit is
    // reachable (submit reads its .value), so load it here too and
    // keep it alive for the test.
    sub = container.listen(createBillMembersProvider, (_, __) {});
    await container.read(createBillMembersProvider.future);
    // Likewise, the screen's Consumers keep the (autoDispose) form
    // provider alive while submit() is in flight; mirror that here.
    formSub = container.listen(createBillFormProvider, (_, __) {});
  });

  tearDown(() async {
    formSub.close();
    sub.close();
    container.dispose();
    repo.dispose();
    await LocalDatabase.deleteForUid(uid);
  });

  CreateBillForm form() => container.read(createBillFormProvider.notifier);

  void fillValid() {
    form().setTitle('Team lunch');
    form().setSubtotal('100');
    form().setTip(0);
    form().toggleMember('me', true);
    form().toggleMember('fa', true);
    form().toggleMember('fb', true);
  }

  group('validation', () {
    test('empty title is rejected', () async {
      fillValid();
      form().setTitle('   ');
      expect(await form().submit(), contains('title'));
      expect(await repo.watchMyBills().first, isEmpty);
    });

    test('zero amount is rejected', () async {
      fillValid();
      form().setSubtotal('0');
      expect(await form().submit(), contains('amount'));
    });

    test('nobody selected is rejected', () async {
      form().setTitle('X');
      form().setSubtotal('50');
      expect(await form().submit(), contains('Select at least one'));
    });
  });

  group('split math', () {
    test('equal split distributes whole cents exactly', () async {
      fillValid(); // 100.00 among me + A + B
      expect(await form().submit(), isNull);
      final bills = await repo.watchMyBills().first;
      expect(bills.length, 1);
      final amounts = bills.single.splits.map((s) => s.amount).toList()..sort();
      expect(amounts, [33.33, 33.33, 33.34]);
      final sum = bills.single.splits.fold(0.0, (a, s) => a + s.amount);
      expect(sum, closeTo(100.0, 0.0001));
    });

    test('tip is included in the total before splitting', () async {
      form().setTitle('Dinner');
      form().setSubtotal('1000');
      form().setTip(10);
      form().toggleMember('me', true);
      form().toggleMember('fa', true);
      expect(await form().submit(), isNull);
      final bill = (await repo.watchMyBills().first).single;
      expect(bill.total, 1100);
      expect(bill.splits.map((s) => s.amount), [550, 550]);
    });

    test('percentage split computes shares and stores percents', () async {
      form().setTitle('Rent');
      form().setSubtotal('200');
      form().setTip(0);
      form().setSplitType('percentage');
      form().toggleMember('me', true);
      form().toggleMember('fa', true);
      form().toggleMember('fb', true);
      form().setPercent('me', '50');
      form().setPercent('fa', '25');
      form().setPercent('fb', '25');
      expect(await form().submit(), isNull);
      final bill = (await repo.watchMyBills().first).single;
      final byUid = {for (final s in bill.splits) s.uid: s};
      expect(byUid['me']!.amount, 100);
      expect(byUid['fa']!.amount, 50);
      expect(byUid['fb']!.amount, 50);
      expect(byUid['me']!.percent, 50);
    });

    test('percentages that do not total 100 are rejected', () async {
      form().setTitle('Rent');
      form().setSubtotal('200');
      form().setSplitType('percentage');
      form().toggleMember('me', true);
      form().toggleMember('fa', true);
      form().setPercent('me', '60');
      form().setPercent('fa', '30');
      final err = await form().submit();
      expect(err, contains('100%'));
      expect(await repo.watchMyBills().first, isEmpty);
    });

    test('custom amounts must add up to the total', () async {
      form().setTitle('Shopping');
      form().setSubtotal('90');
      form().setTip(0);
      form().setSplitType('custom');
      form().toggleMember('me', true);
      form().toggleMember('fa', true);
      form().setAmount('me', '40');
      form().setAmount('fa', '45'); // 85 != 90
      final err = await form().submit();
      expect(err, contains('total'));
      expect(await repo.watchMyBills().first, isEmpty);

      form().setAmount('fa', '50');
      expect(await form().submit(), isNull);
      final bill = (await repo.watchMyBills().first).single;
      final byUid = {for (final s in bill.splits) s.uid: s.amount};
      expect(byUid, {'me': 40, 'fa': 50});
    });

    test('comma decimal separator is accepted', () async {
      form().setTitle('Coffee');
      form().setSubtotal('12,50');
      form().setTip(0);
      form().toggleMember('me', true);
      expect(await form().submit(), isNull);
      final bill = (await repo.watchMyBills().first).single;
      expect(bill.total, 12.5);
    });
  });

  group('currency resolution', () {
    test('friend bill uses my default currency', () async {
      await repo.setMyCurrency('PKR');
      fillValid();
      expect(await form().submit(), isNull);
      final bill = (await repo.watchMyBills().first).single;
      expect(bill.currency, 'PKR');
      expect(bill.groupId, isNull);
    });
  });
}
