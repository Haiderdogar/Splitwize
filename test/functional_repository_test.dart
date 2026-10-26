// Functional tests for AppRepository: every user-facing feature's
// local behavior — bill creation, settlement, balances, groups,
// friends, notifications, profile currency — against the real
// SQLite database. Remote calls are never reached (all profiles are
// seeded locally); SyncService/Firestore behavior is covered by code
// review + the deployed rules.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/utils/debt_simplifier.dart';

import 'test_harness.dart';

void main() {
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
    // Seed profiles so no code path needs the network.
    await db.upsertUser('me', meUser.toProfileMap());
    await db.upsertUser('fa', friendA.toProfileMap());
    await db.upsertUser('fb', friendB.toProfileMap());
  });

  tearDown(() async {
    repo.dispose();
    await LocalDatabase.deleteForUid(uid);
  });

  Future<List<String>> outboxTypes() async =>
      [for (final op in await db.peekOutbox()) op['type'] as String];

  Bill bill({
    required String id,
    required String createdBy,
    required String createdByName,
    required List<BillSplit> splits,
    String currency = 'USD',
    double total = 0,
    String? title,
  }) {
    return Bill(
      id: id,
      title: title ?? 'Bill $id',
      subtotal: total,
      tipPercent: 0,
      total: total,
      splitType: 'equal',
      createdBy: createdBy,
      createdByName: createdByName,
      participantIds: splits.map((s) => s.uid).toSet().toList(),
      splits: splits,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      currency: currency,
    );
  }

  group('bill creation + settlement', () {
    test('createBill stores the bill, computes total with tip, queues create',
        () async {
      final id = await repo.createBill(
        title: 'Dinner',
        subtotal: 1000,
        tipPercent: 10,
        creator: meUser,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 550),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 550),
        ],
        currency: 'PKR',
      );
      final stored = await repo.billById(id);
      expect(stored, isNotNull);
      expect(stored!.total, 1100);
      expect(stored.currency, 'PKR');
      expect(stored.participantIds, containsAll(['me', 'fa']));
      expect(await db.billSyncState(id), 'pending');
      expect(await outboxTypes(), ['bill.create']);

      final mine = await repo.watchMyBills().first;
      expect(mine.map((b) => b.id), [id]);
    });

    test('setSplitPaid flips the flag, stamps paidAt, queues after create',
        () async {
      final id = await repo.createBill(
        title: 'Taxi',
        subtotal: 500,
        tipPercent: 0,
        creator: meUser,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 250),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 250),
        ],
        currency: 'USD',
      );
      await repo.setSplitPaid(billId: id, uid: 'fa', paid: true);
      var stored = await repo.billById(id);
      final faSplit = stored!.splits.firstWhere((s) => s.uid == 'fa');
      expect(faSplit.paid, isTrue);
      expect(faSplit.paidAt, isNotNull);
      // FIFO: the create must reach Firestore before the paid update.
      expect(await outboxTypes(), ['bill.create', 'bill.setPaid']);

      await repo.setSplitPaid(billId: id, uid: 'fa', paid: false);
      stored = await repo.billById(id);
      final back = stored!.splits.firstWhere((s) => s.uid == 'fa');
      expect(back.paid, isFalse);
      expect(back.paidAt, isNull);
    });

    test('setSplitPaid on a missing bill or unchanged flag is a no-op',
        () async {
      await repo.setSplitPaid(billId: 'nope', uid: 'fa', paid: true);
      expect(await outboxTypes(), isEmpty);
    });

    test(
        'removeReceiptPhoto on a pending bill deletes the temp file '
        'and needs no remote op', () async {
      final tmp = await File(
        '${Directory.systemTemp.path}/receipt_test_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      ).writeAsBytes([1, 2, 3]);
      final id = await repo.createBill(
        title: 'Groceries',
        subtotal: 200,
        tipPercent: 0,
        creator: meUser,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 100),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 100),
        ],
        currency: 'USD',
        receiptLocalPath: tmp.path,
      );
      await repo.removeReceiptPhoto(id);
      final stored = await repo.billById(id);
      expect(stored!.receiptLocalPath, isNull);
      expect(stored.receiptImageUrl, isNull);
      expect(await tmp.exists(), isFalse);
      // The queued create reads the local row when it pushes, so it
      // goes out without a receipt — no extra op is queued.
      expect(await outboxTypes(), ['bill.create']);
    });

    test('removeReceiptPhoto on a synced bill queues bill.receiptRemoved',
        () async {
      final id = await repo.createBill(
        title: 'Dinner',
        subtotal: 300,
        tipPercent: 0,
        creator: meUser,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 150),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 150),
        ],
        currency: 'USD',
        receiptLocalPath: '/tmp/whatever.jpg',
      );
      // Simulate the sync having uploaded the photo.
      await repo.applyReceiptUploaded(id, 'https://example.com/r.jpg');
      var stored = await repo.billById(id);
      expect(stored!.receiptImageUrl, 'https://example.com/r.jpg');

      await repo.removeReceiptPhoto(id);
      stored = await repo.billById(id);
      expect(stored!.receiptImageUrl, isNull);
      expect(await outboxTypes(), ['bill.create', 'bill.receiptRemoved']);
    });

    test('removeReceiptPhoto by a non-creator is a no-op', () async {
      final id = await repo.createBill(
        title: 'Their bill',
        subtotal: 100,
        tipPercent: 0,
        creator: friendA,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 50),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 50),
        ],
        currency: 'USD',
        receiptLocalPath: '/tmp/theirs.jpg',
      );
      await repo.applyReceiptUploaded(id, 'https://example.com/t.jpg');
      await repo.removeReceiptPhoto(id);
      final stored = await repo.billById(id);
      expect(stored!.receiptImageUrl, 'https://example.com/t.jpg');
      expect(await outboxTypes(), ['bill.create']);
    });
  });

  group('balances + settle up', () {
    Future<void> seedBills() async {
      // I created; A owes me 300 USD, B owes me 100 USD.
      await repo.applyRemoteBill(bill(
        id: 'b1',
        createdBy: 'me',
        createdByName: 'Me Myself',
        total: 800,
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 400),
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 300),
          BillSplit(uid: 'fb', displayName: 'Friend B', amount: 100),
        ],
      ));
      // A created; I owe A 150 USD and 900 PKR (two bills).
      await repo.applyRemoteBill(bill(
        id: 'b2',
        createdBy: 'fa',
        createdByName: 'Friend A',
        total: 300,
        splits: const [
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 150),
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 150),
        ],
      ));
      await repo.applyRemoteBill(bill(
        id: 'b3',
        createdBy: 'fa',
        createdByName: 'Friend A',
        total: 1800,
        currency: 'PKR',
        splits: const [
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 900),
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 900),
        ],
      ));
      // Fully paid bill — must not affect balances.
      await repo.applyRemoteBill(bill(
        id: 'b4',
        createdBy: 'me',
        createdByName: 'Me Myself',
        total: 50,
        splits: const [
          BillSplit(uid: 'fb', displayName: 'Friend B', amount: 50, paid: true),
        ],
      ));
    }

    test('computeBalances nets per friend per currency, ignores paid',
        () async {
      await seedBills();
      final bills = await repo.watchMyBills().first;
      final balances = repo.computeBalances(bills);
      expect(balances.length, 3);

      final aUsd =
          balances.singleWhere((b) => b.uid == 'fa' && b.currency == 'USD');
      expect(aUsd.net, 150); // 300 owed to me - 150 I owe
      expect(aUsd.owesMe, 300);
      expect(aUsd.iOweThem, 150);
      expect(aUsd.openBills, 2);

      final aPkr =
          balances.singleWhere((b) => b.uid == 'fa' && b.currency == 'PKR');
      expect(aPkr.net, -900);

      final bUsd = balances.singleWhere((b) => b.uid == 'fb');
      expect(bUsd.net, 100);
    });

    test('settleUpWithFriend pays only that friend, only that currency',
        () async {
      await seedBills();
      final count = await repo.settleUpWithFriend('fa', currency: 'PKR');
      expect(count, 1);

      final b3 = await repo.billById('b3');
      expect(b3!.splits.firstWhere((s) => s.uid == 'me').paid, isTrue);
      // The USD bill from A is untouched.
      final b2 = await repo.billById('b2');
      expect(b2!.splits.firstWhere((s) => s.uid == 'me').paid, isFalse);

      final count2 = await repo.settleUpWithFriend('fa');
      expect(count2, 1); // the remaining USD share
      final bills = await repo.watchMyBills().first;
      final aBalances = repo
          .computeBalances(bills)
          .where((b) => b.uid == 'fa' && b.iOweThem > 0);
      expect(aBalances, isEmpty);
    });
  });

  group('groups', () {
    test('createGroup stores it, queues create, creator is member', () async {
      final id = await repo.createGroup(
        name: 'Trip',
        creator: meUser,
        invitees: const [friendA],
        currency: 'EUR',
      );
      final g = await repo.groupById(id);
      expect(g!.name, 'Trip');
      expect(g.members, ['me']);
      expect(g.invited, ['fa']);
      expect(g.currency, 'EUR');
      expect(await outboxTypes(), ['group.create']);
      final mine = await repo.watchMyGroups().first;
      expect(mine.map((x) => x.id), [id]);
    });

    test('invite -> accept flow for an invited group', () async {
      final remote = BillGroup(
        id: 'g-remote',
        name: 'Flatmates',
        createdBy: 'fa',
        members: const ['fa'],
        invited: const ['me'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.applyRemoteGroup(remote);
      var invites = await repo.watchGroupInvites().first;
      expect(invites.map((g) => g.id), ['g-remote']);
      expect(await repo.watchMyGroups().first, isEmpty);

      await repo.acceptGroupInvite('g-remote');
      final g = await repo.groupById('g-remote');
      expect(g!.members, contains('me'));
      expect(g.invited, isNot(contains('me')));
      expect(await outboxTypes(), ['group.accept']);
      expect((await repo.watchMyGroups().first).length, 1);
      invites = await repo.watchGroupInvites().first;
      expect(invites, isEmpty);
    });

    test('decline removes me from invited and queues the op', () async {
      await repo.applyRemoteGroup(BillGroup(
        id: 'g2',
        name: 'Nope',
        createdBy: 'fa',
        members: const ['fa'],
        invited: const ['me'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.declineGroupInvite('g2');
      final g = await repo.groupById('g2');
      expect(g!.invited, isNot(contains('me')));
      expect(await outboxTypes(), ['group.decline']);
    });

    test('setGroupCurrency updates locally and queues the op', () async {
      final id = await repo.createGroup(
        name: 'G',
        creator: meUser,
        invitees: const [],
        currency: 'USD',
      );
      await repo.setGroupCurrency(id, 'GBP');
      expect((await repo.groupById(id))!.currency, 'GBP');
      expect(await outboxTypes(), ['group.create', 'group.currency']);
    });

    test('a pending local group is not overwritten by a remote pull', () async {
      final id = await repo.createGroup(
        name: 'Local name',
        creator: meUser,
        invitees: const [],
        currency: 'USD',
      );
      await repo.applyRemoteGroup(BillGroup(
        id: id,
        name: 'Stale remote name',
        createdBy: 'me',
        members: const ['me'],
        invited: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect((await repo.groupById(id))!.name, 'Local name');
    });
  });

  group('friends', () {
    test('sendConnectionRequest shows outgoing + queues send', () async {
      await repo.sendConnectionRequest(from: meUser, to: friendA);
      final out = await repo.watchOutgoingRequests().first;
      expect(out.length, 1);
      expect(out.first.toUid, 'fa');
      expect(out.first.id, startsWith('local-'));
      expect(await outboxTypes(), ['conn.send']);
    });

    test('sending to an existing connection is a no-op', () async {
      await db.upsertConnection('fa', friendA.toProfileMap());
      await repo.sendConnectionRequest(from: meUser, to: friendA);
      expect(await repo.watchOutgoingRequests().first, isEmpty);
      expect(await outboxTypes(), isEmpty);
    });

    test('accept incoming request connects us and queues accept', () async {
      final req = ConnectionRequest(
        id: 'r1',
        fromUid: 'fb',
        fromName: 'Friend B',
        toUid: 'me',
        toName: 'Me Myself',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.applyRemoteRequest(req);
      expect((await repo.watchIncomingRequests().first).length, 1);

      await repo.acceptConnectionRequest(req);
      expect(await repo.watchIncomingRequests().first, isEmpty);
      final conns = await repo.watchConnections().first;
      expect(conns.map((u) => u.uid), ['fb']);
      expect(await outboxTypes(), ['conn.accept']);
    });

    test('decline + cancel remove rows and queue ops', () async {
      final req = ConnectionRequest(
        id: 'r2',
        fromUid: 'fb',
        fromName: 'Friend B',
        toUid: 'me',
        toName: 'Me Myself',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.applyRemoteRequest(req);
      await repo.declineConnectionRequest('r2');
      expect(await repo.watchIncomingRequests().first, isEmpty);

      await repo.sendConnectionRequest(from: meUser, to: friendA);
      final out = await repo.watchOutgoingRequests().first;
      await repo.cancelConnectionRequest(out.first.id);
      expect(await repo.watchOutgoingRequests().first, isEmpty);
      expect(await outboxTypes(), ['conn.decline', 'conn.send', 'conn.cancel']);
    });

    test('removeConnection deletes the mirror and queues the op', () async {
      await db.upsertConnection('fa', friendA.toProfileMap());
      await repo.removeConnection('fa');
      expect(await repo.watchConnections().first, isEmpty);
      expect(await outboxTypes(), ['conn.remove']);
    });

    test('a remotely accepted request clears my outgoing row', () async {
      await repo.sendConnectionRequest(from: meUser, to: friendA);
      final local = (await repo.watchOutgoingRequests().first).first;
      // Simulate the send landing: re-key, then the acceptance delta.
      await repo.remapRequestId(local.id, 'remote-1');
      await repo.applyRemoteRequest(ConnectionRequest(
        id: 'remote-1',
        fromUid: 'me',
        fromName: 'Me Myself',
        toUid: 'fa',
        toName: 'Friend A',
        status: 'accepted',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(await repo.watchOutgoingRequests().first, isEmpty);
    });
  });

  group('notifications (local side)', () {
    AppNotification notif(String id, {bool read = false}) => AppNotification(
          id: id,
          toUid: 'me',
          title: 'Title $id',
          body: 'Body',
          type: 'bill_created',
          read: read,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    test('remote notifications land in the inbox', () async {
      await repo.applyRemoteNotification(notif('n1'));
      await repo.applyRemoteNotification(notif('n2'));
      final list = await repo.watchNotifications().first;
      expect(list.length, 2);
    });

    test('a pull never un-reads a notification read while offline', () async {
      await repo.applyRemoteNotification(notif('n1'));
      await repo.markNotificationRead('n1');
      // Same notification pulled again, still unread on the server.
      await repo.applyRemoteNotification(notif('n1'));
      final list = await repo.watchNotifications().first;
      expect(list.single.read, isTrue);
      expect(await db.pendingReadNotificationIds(), ['n1']);
    });

    test('mark all read flags everything', () async {
      await repo.applyRemoteNotification(notif('n1'));
      await repo.applyRemoteNotification(notif('n2'));
      await repo.markAllNotificationsRead();
      final list = await repo.watchNotifications().first;
      expect(list.every((n) => n.read), isTrue);
      expect((await db.pendingReadNotificationIds())..sort(), ['n1', 'n2']);
    });
  });

  group('profile + remote bill guards', () {
    test('setMyCurrency persists to my profile and queues an upsert', () async {
      await repo.setMyCurrency('PKR');
      final me = await repo.getUser('me');
      expect(me!.currencyCode, 'PKR');
      expect(await outboxTypes(), ['user.upsert']);
      // Same value again -> no-op.
      await repo.setMyCurrency('PKR');
      expect(await outboxTypes(), ['user.upsert']);
    });

    test('a pending local bill survives a stale remote version', () async {
      final id = await repo.createBill(
        title: 'Local title',
        subtotal: 100,
        tipPercent: 0,
        creator: meUser,
        splitType: 'equal',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 100),
        ],
        currency: 'USD',
      );
      await repo.applyRemoteBill(bill(
        id: id,
        createdBy: 'me',
        createdByName: 'Me Myself',
        total: 100,
        title: 'Stale remote title',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 100),
        ],
      ));
      expect((await repo.billById(id))!.title, 'Local title');
    });

    test('a tombstoned remote bill purges the local copy', () async {
      await repo.applyRemoteBill(bill(
        id: 'gone',
        createdBy: 'fa',
        createdByName: 'Friend A',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 10),
        ],
      ));
      expect(await repo.billById('gone'), isNotNull);
      final dead = bill(
        id: 'gone',
        createdBy: 'fa',
        createdByName: 'Friend A',
        splits: const [],
      );
      await repo.applyRemoteBill(Bill(
        id: dead.id,
        title: dead.title,
        subtotal: 0,
        tipPercent: 0,
        total: 0,
        splitType: 'equal',
        createdBy: 'fa',
        createdByName: 'Friend A',
        participantIds: const [],
        splits: const [],
        deleted: true,
      ));
      expect(await repo.billById('gone'), isNull);
    });
  });

  group('group debt simplification (Option A recording)', () {
    // A group bill where I'm a participant; seeded straight into the
    // local DB as already-synced, the way a pull would leave it.
    Future<void> seedGroupBill({
      required String id,
      required String createdBy,
      required String createdByName,
      required List<BillSplit> splits,
    }) async {
      final b = Bill(
        id: id,
        title: 'Group bill $id',
        subtotal: 0,
        tipPercent: 0,
        total: 0,
        splitType: 'equal',
        createdBy: createdBy,
        createdByName: createdByName,
        groupId: 'g1',
        participantIds: {
          createdBy,
          ...splits.map((s) => s.uid),
        }.toList(),
        splits: splits,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        currency: 'PKR',
      );
      await db.upsertBill(b.id, b.toMap(), syncState: 'synced');
    }

    Future<List<Map<String, dynamic>>> setPaidOps() async => [
          for (final op in await db.peekOutbox())
            if (op['type'] == 'bill.setPaid')
              op['payload'] as Map<String, dynamic>,
        ];

    test(
        'a routed transfer settles shares along the chain, '
        'partially where the amounts differ', () async {
      // fb owes me 60 (my bill); I owe fa 100 (fa's bill).
      // Chain: fb → me → fa. Plan: fb pays fa 60 (routed), I pay fa 40.
      await seedGroupBill(
        id: 'gb1',
        createdBy: 'me',
        createdByName: 'Me Myself',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 60),
          BillSplit(uid: 'fb', displayName: 'Friend B', amount: 60),
        ],
      );
      await seedGroupBill(
        id: 'gb2',
        createdBy: 'fa',
        createdByName: 'Friend A',
        splits: const [
          BillSplit(uid: 'fa', displayName: 'Friend A', amount: 100),
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 100),
        ],
      );

      final bills = await repo.watchMyBills().first;
      final plan = simplifyGroupDebts(bills);
      final pkr = plan.byCurrency.single;
      expect(pkr.transfers, hasLength(2));
      final routed =
          pkr.transfers.firstWhere((t) => t.fromUid == 'fb' && t.toUid == 'fa');
      expect(routed.amount, 60);

      final touched = await repo.applySettlementAllocations(routed.allocations);
      expect(touched, 2);

      // fb's share on my bill is fully paid…
      final gb1 = await repo.billById('gb1');
      final fbSplit = gb1!.splits.firstWhere((s) => s.uid == 'fb');
      expect(fbSplit.paid, isTrue);
      expect(fbSplit.paidAt, isNotNull);
      // …and 60 of my 100 share on fa's bill is settled, 40 remains.
      final gb2 = await repo.billById('gb2');
      final mySplit = gb2!.splits.firstWhere((s) => s.uid == 'me');
      expect(mySplit.paid, isFalse);
      expect(mySplit.paidAmount, 60);
      expect(mySplit.remainingAmount, 40);

      // Both updates ride the existing bill.setPaid op, carrying the
      // settled amounts.
      final ops = await setPaidOps();
      expect(ops, hasLength(2));
      expect(
          ops,
          contains(allOf(containsPair('billId', 'gb1'),
              containsPair('paid', true), containsPair('paidAmount', 60.0))));
      expect(
          ops,
          contains(allOf(containsPair('billId', 'gb2'),
              containsPair('paid', false), containsPair('paidAmount', 60.0))));

      // Balances reflect the partial settlement: I still owe fa 40,
      // fb no longer owes me anything.
      final balances = repo.computeBalances(await repo.watchMyBills().first);
      expect(balances, hasLength(1));
      expect(balances.single.uid, 'fa');
      expect(balances.single.net, -40);

      // Allocations clamp at the share total: settling more than a
      // share's remainder tops it up to fully paid, never beyond.
      final topUp = await repo.applySettlementAllocations(const [
        SplitAllocation(billId: 'gb2', splitUid: 'me', amount: 999),
      ]);
      expect(topUp, 1);
      final toppedUp = await repo.billById('gb2');
      final toppedSplit = toppedUp!.splits.firstWhere((s) => s.uid == 'me');
      expect(toppedSplit.paid, isTrue);
      expect(toppedSplit.settledAmount, 100);

      // Undo that top-up so the plan-based flow below is exercised
      // from the partially settled state again.
      await repo.setSplitPaid(billId: 'gb2', uid: 'me', paid: false);
      await repo.applySettlementAllocations(routed.allocations);

      // Recording my own remaining transfer settles everything.
      final mine =
          pkr.transfers.firstWhere((t) => t.fromUid == 'me' && t.toUid == 'fa');
      await repo.applySettlementAllocations(mine.allocations);
      final settled = await repo.billById('gb2');
      expect(settled!.splits.firstWhere((s) => s.uid == 'me').paid, isTrue);
      expect(repo.computeBalances(await repo.watchMyBills().first), isEmpty);
    });

    test('a netting settles mutual shares on both sides', () async {
      await seedGroupBill(
        id: 'nb1',
        createdBy: 'me',
        createdByName: 'Me Myself',
        splits: const [
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 50),
          BillSplit(uid: 'fb', displayName: 'Friend B', amount: 50),
        ],
      );
      await seedGroupBill(
        id: 'nb2',
        createdBy: 'fb',
        createdByName: 'Friend B',
        splits: const [
          BillSplit(uid: 'fb', displayName: 'Friend B', amount: 50),
          BillSplit(uid: 'me', displayName: 'Me Myself', amount: 50),
        ],
      );
      final plan = simplifyGroupDebts(await repo.watchMyBills().first);
      final netting = plan.byCurrency.single.nettings.single;
      expect(netting.amount, 50);
      final touched =
          await repo.applySettlementAllocations(netting.allocations);
      expect(touched, 2);
      // The two debt shares are paid (each bill's creator-own share
      // is not a debt and stays untouched, as everywhere in the app).
      final nb1 = await repo.billById('nb1');
      expect(nb1!.splits.firstWhere((s) => s.uid == 'fb').paid, isTrue);
      final nb2 = await repo.billById('nb2');
      expect(nb2!.splits.firstWhere((s) => s.uid == 'me').paid, isTrue);
      expect(repo.computeBalances(await repo.watchMyBills().first), isEmpty);
    });
  });
}
