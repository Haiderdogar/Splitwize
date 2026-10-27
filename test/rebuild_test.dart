// Rebuild-isolation tests: prove that only the widgets / listeners
// that actually need to react to a state change do so.
//
// The app's state bug was a global one: AppRepository's change bus
// fires on EVERY local mutation, whatever table it touched, and the
// old watch streams re-emitted fresh model instances on each fire.
// With identity-only model equality, every screen watching any
// stream rebuilt on every mutation anywhere in the app. The fixes
// under test here:
//   * models have value equality (updatedAt excluded: sync
//     bookkeeping, never displayed),
//   * watch streams suppress emissions whose content is unchanged,
//   * checklist rows and dialog buttons watch only their own slice
//     of form state via `.select`,
//   * my profile is a live stream, not a one-shot Future.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart' hide group;
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/screens/create_bill_screen.dart';
import 'package:splitwize/screens/profile_tab.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/services/sync_service.dart';

import 'test_harness.dart';

/// Polls until [condition] holds (or times out and fails).
Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'timed out waiting for condition');
}

void main() {
  group('model value equality', () {
    test('same bill data from two parses is equal', () {
      const map = {
        'title': 'Dinner',
        'subtotal': 100,
        'tipPercent': 10,
        'total': 110,
        'splitType': 'equal',
        'createdBy': 'me',
        'createdByName': 'Me Myself',
        'participantIds': ['me', 'fa'],
        'splits': [
          {'uid': 'me', 'displayName': 'Me Myself', 'amount': 55},
          {'uid': 'fa', 'displayName': 'Friend A', 'amount': 55},
        ],
        'currency': 'PKR',
      };
      final a = Bill.fromMap('b1', map);
      final b = Bill.fromMap('b1', map);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect([a], equals([b]));
    });

    test('only a sync timestamp changing does not count as a change', () {
      final a = Bill.fromMap('b1', {
        'title': 'Dinner',
        'total': 110,
        'splits': [],
        'updatedAt': DateTime(2026, 1, 1),
      });
      final b = Bill.fromMap('b1', {
        'title': 'Dinner',
        'total': 110,
        'splits': [],
        'updatedAt': DateTime(2026, 6, 1),
      });
      expect(a, equals(b));
    });

    test('a share marked paid is a real change', () {
      const split = BillSplit(uid: 'fa', displayName: 'Friend A', amount: 55);
      expect(split, isNot(equals(split.copyWith(paid: true))));
      final user = meUser.copyWith(currency: 'USD');
      expect(user, isNot(equals(meUser.copyWith(currency: 'PKR'))));
      const balance = FriendBalance(
        uid: 'fa',
        displayName: 'Friend A',
        currency: 'PKR',
        net: 100,
        owesMe: 100,
        iOweThem: 0,
        openBills: 1,
      );
      expect(
        balance,
        equals(const FriendBalance(
          uid: 'fa',
          displayName: 'Friend A',
          currency: 'PKR',
          net: 100,
          owesMe: 100,
          iOweThem: 0,
          openBills: 1,
        )),
      );
      const note = AppNotification(
        id: 'n1',
        toUid: 'me',
        title: 'Hi',
        body: 'Body',
        type: 'bill_created',
        read: false,
      );
      expect(note, isNot(equals(note.copyWith(read: true))));
    });
  });

  group('watch stream distinct (repository level)', () {
    setUpAll(() async {
      await initTestEnv();
    });

    const uid = 'me';
    late LocalDatabase db;
    late AppRepository repo;

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
    });

    tearDown(() async {
      repo.dispose();
      await LocalDatabase.deleteForUid(uid);
    });

    test('unrelated mutations do not re-emit the bills list', () async {
      final id = await repo.createBill(
        title: 'Dinner',
        subtotal: 1000,
        tipPercent: 0,
        creator: meUser,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 500),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 500),
        ],
        currency: 'USD',
      );
      final emissions = <List<Bill>>[];
      final sub = repo.watchMyBills().listen(emissions.add);
      addTearDown(sub.cancel);
      await waitFor(() => emissions.isNotEmpty);
      expect(emissions.length, 1);

      // Simulates any unrelated mutation (a notification read, a
      // friend request, a group currency change): the bus fires,
      // the query re-runs, but the content is identical.
      repo.notifyChanged();
      repo.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        emissions.length,
        1,
        reason: 'identical content must not re-emit (else every '
            'list screen rebuilds on every mutation anywhere)',
      );

      // A real change still emits exactly once.
      await repo.setSplitPaid(billId: id, uid: 'fa', paid: true);
      await waitFor(() => emissions.length >= 2);
      expect(emissions.length, 2);
      expect(
        emissions.last
            .firstWhere((b) => b.id == id)
            .splits
            .firstWhere((s) => s.uid == 'fa')
            .paid,
        isTrue,
      );
    });

    test('currentAppUser is live: a currency change emits again', () async {
      final container = ProviderContainer(overrides: [
        currentUidProvider.overrideWith((ref) => 'me'),
        appRepositoryProvider.overrideWith((ref) async => repo),
      ]);
      addTearDown(container.dispose);
      final emitted = <AppUser?>[];
      container.listen(
        currentAppUserProvider,
        (_, next) => emitted.add(next.value),
      );
      await waitFor(() => emitted.isNotEmpty);
      expect(emitted.last?.currencyCode, 'USD');

      // The old one-shot Future provider would never emit this:
      // Profile and the create screens stayed stale until restart.
      await repo.setMyCurrency('PKR');
      await waitFor(() => emitted.length >= 2);
      expect(emitted.last?.currencyCode, 'PKR');
    });
  });

  group('select isolation (provider level)', () {
    test('toggling one member notifies only that member\'s row select', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var rowFbCalls = 0;
      container.listen(
        createBillFormProvider.select((s) => s.selected.contains('fb')),
        (_, __) => rowFbCalls++,
      );
      final form = container.read(createBillFormProvider.notifier);
      form.toggleMember('fa', true);
      expect(rowFbCalls, 0, reason: 'fa tick must not rebuild fb\'s row');
      form.toggleMember('fb', true);
      expect(rowFbCalls, 1);
      form.toggleMember('fa', false);
      expect(rowFbCalls, 1, reason: 'fa untick must not rebuild fb\'s row');
    });

    test('typing an email does not notify the add-friend result/button', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var resultCalls = 0;
      var buttonCalls = 0;
      container.listen(
        addFriendProvider.select((s) => (
              searching: s.searching,
              error: s.error,
              found: s.found,
            )),
        (_, __) => resultCalls++,
      );
      container.listen(
        addFriendProvider.select((s) => (
              searching: s.searching,
              hasFound: s.found != null,
            )),
        (_, __) => buttonCalls++,
      );
      final form = container.read(addFriendProvider.notifier);
      form.setEmail('f');
      form.setEmail('fr');
      form.setEmail('fri@example.com');
      expect(resultCalls, 0, reason: 'keystrokes must not rebuild the result');
      expect(buttonCalls, 0, reason: 'keystrokes must not rebuild the button');
    });

    test('invite button only cares whether anything is selected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var buttonCalls = 0;
      container.listen(
        groupInviteSelectionProvider.select((s) => s.isNotEmpty),
        (_, __) => buttonCalls++,
      );
      final sel = container.read(groupInviteSelectionProvider.notifier);
      sel.toggle('fa', true);
      expect(buttonCalls, 1, reason: 'empty -> non-empty flips the button');
      sel.toggle('fb', true);
      expect(buttonCalls, 1, reason: 'second tick must not rebuild it');
      sel.toggle('fa', false);
      expect(buttonCalls, 1, reason: 'still non-empty, no rebuild');
      sel.toggle('fb', false);
      expect(buttonCalls, 2, reason: 'back to empty flips it again');
    });

    test('simplified debts plan is memoized across unrelated changes', () {
      const bill = Bill(
        id: 'b1',
        title: 'Dinner',
        subtotal: 100,
        tipPercent: 0,
        total: 100,
        splitType: 'equal',
        createdBy: 'me',
        createdByName: 'Me Myself',
        participantIds: ['me', 'fa'],
        splits: [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 50),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 50),
        ],
        currency: 'USD',
      );
      final container = ProviderContainer(overrides: [
        groupBillsProvider('g1').overrideWith((ref) => Stream.value([bill])),
      ]);
      addTearDown(container.dispose);
      final first = container.read(simplifiedDebtsProvider('g1'));
      container.read(tabIndexProvider.notifier).set(3);
      final second = container.read(simplifiedDebtsProvider('g1'));
      expect(
        identical(first, second),
        isTrue,
        reason: 'unrelated state changes must reuse the cached plan, '
            'not re-run the simplification',
      );
    });
  });

  group('widget regressions for the refactored rows', () {
    setUpAll(() async {
      await initTestEnv();
    });

    testWidgets('create-bill: ticking one member checks only that row',
        (tester) async {
      // Tall viewport: the member list is a lazy sliver, so rows
      // below the fold are not built at the default 600px height.
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWith((ref) => 'me'),
            myGroupsProvider.overrideWith((ref) => Stream.value([])),
            currentAppUserProvider.overrideWith((ref) => Stream.value(meUser)),
            createBillMembersProvider
                .overrideWith((ref) async => [meUser, friendA, friendB]),
          ],
          child: const MaterialApp(home: CreateBillScreen()),
        ),
      );
      await tester.pump();
      final boxes = find.byType(Checkbox);
      expect(boxes, findsNWidgets(3));
      // Row order is [me, friendA, friendB]; me's box is disabled.
      await tester.tap(boxes.at(1));
      await tester.pump();
      final container = ProviderScope.containerOf(tester.element(boxes.at(1)));
      expect(
        container.read(createBillFormProvider).selected,
        contains('fa'),
      );
      expect(tester.widget<Checkbox>(boxes.at(1)).value, isTrue);
      expect(tester.widget<Checkbox>(boxes.at(2)).value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile: push tile reads the cached provider status',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWith((ref) => 'me'),
            currentAppUserProvider.overrideWith((ref) => Stream.value(meUser)),
            notificationAuthorizationStatusProvider
                .overrideWith((ref) async => AuthorizationStatus.authorized),
            syncStatusProvider
                .overrideWith((ref) => Stream.value(const SyncState())),
            adFreeStatusProvider.overrideWith(() => _FakeAdFreeStatus(false)),
            themeModeSettingProvider.overrideWith(() => _FakeThemeMode()),
          ],
          child: const MaterialApp(home: Scaffold(body: ProfileTab())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Me Myself'), findsOneWidget);
      expect(
        find.text('On — you will be notified of new bills'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeAdFreeStatus extends AdFreeStatus {
  _FakeAdFreeStatus(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

class _FakeThemeMode extends ThemeModeSetting {
  @override
  Future<AppTheme> build() async => AppTheme.system;
}
