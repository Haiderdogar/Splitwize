import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/utils/debt_simplifier.dart';

import 'test_harness.dart';

BillGroup _group(String id, String currency,
        {bool deleted = false, bool joined = true}) =>
    BillGroup(
      id: id,
      name: 'Group $id',
      createdBy: 'me',
      members: joined ? const ['me', 'fa'] : const ['fa'],
      invited: const [],
      currency: currency,
      deleted: deleted,
    );

Bill _bill(String id, String currency,
        {String? groupId = 'g1', bool ledger = true, bool meOwes = false}) =>
    Bill(
      id: id,
      title: 'Expense $id',
      subtotal: 200,
      tipPercent: 0,
      total: 200,
      splitType: 'custom',
      createdBy: meOwes ? 'fa' : 'me',
      createdByName: meOwes ? friendA.displayName : meUser.displayName,
      groupId: groupId,
      groupName: groupId == null ? null : 'Group $groupId',
      participantIds: const ['me', 'fa'],
      splits: const [
        BillSplit(uid: 'me', displayName: 'Me Myself', amount: 80),
        BillSplit(
          uid: 'fa',
          displayName: 'Friend A',
          amount: 120,
          paidAmount: 20,
        ),
      ],
      merchantPayments: ledger ? {meOwes ? 'fa' : 'me': 200} : const {},
      paymentDebts: ledger
          ? [
              BillDebt(
                id: meOwes ? 'me|fa' : 'fa|me',
                debtorUid: meOwes ? 'me' : 'fa',
                debtorName: meOwes ? meUser.displayName : friendA.displayName,
                creditorUid: meOwes ? 'fa' : 'me',
                creditorName: meOwes ? friendA.displayName : meUser.displayName,
                amount: meOwes ? 80 : 120,
                settledAmount: 20,
              ),
            ]
          : const [],
      createdAt: DateTime(2026, 11, 16),
      updatedAt: DateTime(2026, 11, 16),
      currency: currency,
    );

Map<String, dynamic> _withoutCurrency(Bill bill) =>
    bill.toMap()..remove('currency');

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue,
      reason: 'Timed out waiting for a currency update.');
}

void main() {
  const databaseUid = 'group-currency-repository-tests';
  late LocalDatabase db;
  late AppRepository repo;

  AppRepository repositoryFor(LocalDatabase database) => AppRepository(
        db: database,
        remote: FirestoreService(),
        secure: SecureStorageService(),
        myUid: 'me',
      );

  setUpAll(initTestEnv);

  setUp(() async {
    await LocalDatabase.deleteForUid(databaseUid);
    db = await LocalDatabase.open(databaseUid);
    repo = repositoryFor(db);
    await db.upsertUser('me', meUser.toProfileMap());
    await db.upsertUser('fa', friendA.toProfileMap());
  });

  tearDown(() async {
    repo.dispose();
    await LocalDatabase.deleteForUid(databaseUid);
  });

  test(
      'changing group currency relabels every live bill read without conversion',
      () async {
    await db.upsertGroup('g1', _group('g1', 'USD').toMap());
    final original = _bill('dinner', 'PKR');
    await db.upsertBill(original.id, original.toMap());
    final mine = <List<Bill>>[];
    final inGroup = <List<Bill>>[];
    final details = <Bill?>[];
    final subscriptions = <StreamSubscription<dynamic>>[
      repo.watchMyBills().listen(mine.add),
      repo.watchBillsForGroup('g1').listen(inGroup.add),
      repo.watchBill(original.id).listen(details.add),
    ];
    addTearDown(() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    });
    await _waitFor(
        () => mine.isNotEmpty && inGroup.isNotEmpty && details.isNotEmpty);
    expect(mine.last.single.currency, 'USD');
    expect(inGroup.last.single.currency, 'USD');
    expect(details.last!.currency, 'USD');

    await repo.setGroupCurrency('g1', 'GBP');
    await _waitFor(() =>
        mine.last.single.currency == 'GBP' &&
        inGroup.last.single.currency == 'GBP' &&
        details.last?.currency == 'GBP');
    for (final bill in [
      mine.last.single,
      inGroup.last.single,
      details.last!,
      (await repo.billById(original.id))!,
    ]) {
      expect(_withoutCurrency(bill), _withoutCurrency(original));
    }
    expect((await db.billRow(original.id))!['currency'], 'PKR');
    expect((await db.peekOutbox()).map((operation) => operation['type']),
        ['group.currency'],
        reason:
            'Relabelling must not require rewriting other members\' bills.');
  });

  test(
      'other groups, personal bills and unavailable groups keep their currency',
      () async {
    await db.upsertGroup('g1', _group('g1', 'GBP').toMap());
    await db.upsertGroup('g2', _group('g2', 'EUR').toMap());
    await db.upsertGroup(
        'deleted', _group('deleted', 'CAD', deleted: true).toMap());
    await db.upsertGroup('left', _group('left', 'CHF', joined: false).toMap());
    final bills = [
      _bill('current', 'USD'),
      _bill('other', 'USD', groupId: 'g2'),
      _bill('personal', 'JPY', groupId: null),
      _bill('missing', 'AUD', groupId: 'missing'),
      _bill('deleted', 'NZD', groupId: 'deleted'),
      _bill('left', 'USD', groupId: 'left'),
    ];
    for (final bill in bills) {
      await db.upsertBill(bill.id, bill.toMap());
    }

    final mine = await repo.watchMyBills().first;
    expect({
      for (final bill in mine) bill.id: bill.currency
    }, {
      'current': 'GBP',
      'other': 'EUR',
      'personal': 'JPY',
      'missing': 'AUD',
      'deleted': 'NZD',
      'left': 'CHF',
    });
    await repo.setGroupCurrency('g1', 'SAR');
    expect((await repo.billById('current'))!.currency, 'SAR');
    expect((await repo.billById('other'))!.currency, 'EUR');
    expect((await repo.billById('personal'))!.currency, 'JPY');
    expect((await repo.watchBillsForGroup('missing').first).single.currency,
        'AUD');
  });

  test('regular members cannot relabel a group or queue a currency change',
      () async {
    final group = BillGroup.fromMap('g1', {
      ..._group('g1', 'USD').toMap(),
      'createdBy': 'fa',
    });
    await db.upsertGroup(group.id, group.toMap());
    final original = _bill('dinner', 'PKR');
    await db.upsertBill(original.id, original.toMap());

    await expectLater(repo.setGroupCurrency('g1', 'EUR'), throwsStateError);

    expect((await repo.groupById('g1'))!.toMap(), group.toMap());
    expect(await db.peekOutbox(), isEmpty);
    final readBack = (await repo.billById(original.id))!;
    expect(readBack.currency, 'USD');
    expect(_withoutCurrency(readBack), _withoutCurrency(original));
    expect((await repo.watchMyBills().first).single.currency, 'USD');
    expect((await repo.watchBillsForGroup('g1').first).single.currency, 'USD');
  });

  test('invited people and nonmembers cannot change a group currency',
      () async {
    for (final group in [
      BillGroup.fromMap('invited', {
        ..._group('invited', 'USD').toMap(),
        'createdBy': 'fa',
        'members': ['fa'],
        'invited': ['me'],
      }),
      _group('former-owner', 'USD', joined: false),
      BillGroup.fromMap('outsider', {
        ..._group('outsider', 'USD').toMap(),
        'createdBy': 'fa',
        'members': ['fa'],
      }),
    ]) {
      await db.upsertGroup(group.id, group.toMap());
      await expectLater(
          repo.setGroupCurrency(group.id, 'EUR'), throwsStateError);
      expect((await repo.groupById(group.id))!.toMap(), group.toMap());
    }
    expect(await db.peekOutbox(), isEmpty);
  });

  test('missing and deleted groups reject currency changes without queuing',
      () async {
    final deleted = _group('deleted', 'USD', deleted: true);
    await db.upsertGroup(deleted.id, deleted.toMap());

    await expectLater(
        repo.setGroupCurrency('missing', 'EUR'), throwsStateError);
    await expectLater(
        repo.setGroupCurrency(deleted.id, 'EUR'), throwsStateError);

    expect(await repo.groupById('missing'), isNull);
    expect((await repo.groupById(deleted.id))!.toMap(), deleted.toMap());
    expect(await db.peekOutbox(), isEmpty);
  });

  test('remote group changes survive subsequent pulls of older bill currency',
      () async {
    await db.upsertGroup('g1', _group('g1', 'USD').toMap());
    final original = _bill('dinner', 'PKR');
    await db.upsertBill(original.id, original.toMap());
    final emissions = <Bill?>[];
    final subscription = repo.watchBill(original.id).listen(emissions.add);
    addTearDown(subscription.cancel);
    await _waitFor(() => emissions.isNotEmpty);

    await repo.applyRemoteGroup(_group('g1', 'EUR'));
    repo.notifyChanged();
    await _waitFor(() => emissions.last?.currency == 'EUR');
    await repo.applyRemoteBill(original);
    repo.notifyChanged();

    final refreshed = (await repo.billById(original.id))!;
    expect(refreshed.currency, 'EUR');
    expect(_withoutCurrency(refreshed), _withoutCurrency(original));
    expect((await db.billRow(original.id))!['currency'], 'PKR');
  });

  test('selected group currency is restored when the offline database reopens',
      () async {
    await db.upsertGroup('g1', _group('g1', 'USD').toMap());
    final original = _bill('dinner', 'USD');
    await db.upsertBill(original.id, original.toMap());
    await repo.setGroupCurrency('g1', 'AED');
    repo.dispose();
    await LocalDatabase.close();
    db = await LocalDatabase.open(databaseUid);
    repo = repositoryFor(db);

    expect((await repo.groupById('g1'))!.currency, 'AED');
    final bill = (await repo.watchBill(original.id).first)!;
    expect(bill.currency, 'AED');
    expect(_withoutCurrency(bill), _withoutCurrency(original));
  });

  test('a stale group pull keeps queued currency while refreshing other fields',
      () async {
    await db.upsertGroup('g1', _group('g1', 'USD').toMap());
    await db.upsertGroup('g2', _group('g2', 'JPY').toMap());
    final original = _bill('dinner', 'USD');
    await db.upsertBill(original.id, original.toMap());
    await repo.setGroupCurrency('g1', 'GBP');
    // Another group's later change must neither replace nor protect g1's label.
    await repo.setGroupCurrency('g2', 'AUD');
    final remote = BillGroup.fromMap('g1', {
      ..._group('g1', 'USD').toMap(),
      'name': 'Updated remote name',
      'members': ['me', 'fa', 'fb'],
    });

    await repo.applyRemoteGroup(remote);
    repo.notifyChanged();
    final merged = (await repo.groupById('g1'))!;
    expect(merged.currency, 'GBP');
    expect(merged.name, 'Updated remote name');
    expect(merged.members, ['me', 'fa', 'fb']);
    expect((await repo.billById(original.id))!.currency, 'GBP');

    final queued = await db.peekOutbox();
    final groupOperation = queued.singleWhere((operation) =>
        operation['type'] == 'group.currency' &&
        (operation['payload'] as Map)['groupId'] == 'g1');
    await db.removeOutbox(groupOperation['id'] as int);
    await repo.applyRemoteGroup(remote.copyWith(currency: 'EUR'));
    repo.notifyChanged();
    expect((await repo.groupById('g1'))!.currency, 'EUR');
    expect((await repo.billById(original.id))!.currency, 'EUR');
  });

  test('new group bills use the latest group currency even from a stale form',
      () async {
    await db.upsertGroup('g1', _group('g1', 'GBP').toMap());
    final id = await repo.createBill(
      title: 'New expense',
      subtotal: 200,
      tipPercent: 0,
      creator: meUser,
      groupId: 'g1',
      groupName: 'Group g1',
      splitType: 'custom',
      splits: const [
        BillSplit(uid: 'me', displayName: 'Me Myself', amount: 80),
        BillSplit(uid: 'fa', displayName: 'Friend A', amount: 120),
      ],
      merchantPayments: const {'me': 200},
      currency: 'USD',
    );

    final saved = (await repo.billById(id))!;
    expect(saved.currency, 'GBP');
    expect(saved.total, 200);
    expect(saved.splits.map((split) => split.amount), [80, 120]);
    expect((await db.billRow(id))!['currency'], 'GBP');
    final operation = (await db.peekOutbox()).single;
    expect(operation['type'], 'bill.create');
    final queuedBill = (operation['payload'] as Map)['bill'] as Map;
    expect(queuedBill['currency'], 'GBP');
    expect(queuedBill['total'], 200);
  });

  test('settling ledger and legacy bills preserves their raw cached currency',
      () async {
    await db.upsertGroup('g1', _group('g1', 'GBP').toMap());
    final ledger = _bill('ledger', 'USD');
    final legacy = _bill('legacy', 'PKR', ledger: false);
    for (final bill in [ledger, legacy]) {
      await db.upsertBill(bill.id, bill.toMap());
      await repo.setSplitPaid(billId: bill.id, uid: 'fa', paid: true);
      expect((await repo.billById(bill.id))!.currency, 'GBP');
      final raw = Bill.fromMap(bill.id, (await db.billRow(bill.id))!);
      expect(raw.currency, bill.currency);
      expect(raw.total, 200);
      expect(raw.splits.map((split) => split.amount), [80, 120]);
    }
    final rawLedger = Bill.fromMap(ledger.id, (await db.billRow(ledger.id))!);
    expect(rawLedger.paymentDebts.single.settledAmount, 120);
    final rawLegacy = Bill.fromMap(legacy.id, (await db.billRow(legacy.id))!);
    expect(rawLegacy.splits.last.isFullyPaid, isTrue);
  });

  test('settle up filters group bills by their currently selected currency',
      () async {
    await db.upsertGroup('g1', _group('g1', 'EUR').toMap());
    final inGroup = _bill('group-expense', 'USD', meOwes: true);
    final personal =
        _bill('personal-expense', 'USD', groupId: null, meOwes: true);
    for (final bill in [inGroup, personal]) {
      await db.upsertBill(bill.id, bill.toMap());
    }

    expect(await repo.settleUpWithFriend('fa', currency: 'EUR'), 1);
    expect((await repo.billById(inGroup.id))!.fullySettled, isTrue);
    expect((await repo.billById(personal.id))!.fullySettled, isFalse);
    expect((await repo.billById(personal.id))!.currency, 'USD');
  });

  test('group balances and settlement plans use one currency and exact amounts',
      () async {
    await db.upsertGroup('g1', _group('g1', 'GBP').toMap());
    for (final bill in [_bill('dinner', 'USD'), _bill('taxi', 'PKR')]) {
      await db.upsertBill(bill.id, bill.toMap());
    }
    final bills = await repo.watchBillsForGroup('g1').first;
    final balance = repo.computeBalances(bills).single;
    expect(balance.currency, 'GBP');
    expect(balance.owesMe, 200);
    expect(balance.openBills, 2);
    final plan = simplifyGroupDebts(bills);
    final currencyPlan = plan.byCurrency.single;
    expect(currencyPlan.currency, 'GBP');
    expect(currencyPlan.openAmount, 200);
    final payment = currencyPlan.transfers.single;
    expect(payment.amount, 200);
    expect(
        payment.allocations.map((allocation) => allocation.amount), [100, 100]);

    expect(await repo.applySettlementAllocations(payment.allocations), 2);
    final settled = await repo.watchBillsForGroup('g1').first;
    expect(settled.every((bill) => bill.fullySettled), isTrue);
    expect(settled.map((bill) => bill.currency), everyElement('GBP'));
    expect(settled.map((bill) => bill.total), [200, 200]);
  });
}
