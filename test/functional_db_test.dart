// Functional tests for the local database and the outbox:
// the offline-first plumbing every feature depends on.
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';

import 'test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  const uid = 'me';
  late LocalDatabase db;

  setUp(() async {
    await LocalDatabase.deleteForUid(uid);
    db = await LocalDatabase.open(uid);
  });

  tearDown(() async {
    await LocalDatabase.deleteForUid(uid);
  });

  group('bills table', () {
    test('upsert + billsFor returns only my bills, newest first', () async {
      final now = DateTime.now();
      await db.upsertBill('b1', {
        'title': 'Mine',
        'participantIds': ['me', 'fa'],
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.upsertBill('b2', {
        'title': 'Not mine',
        'participantIds': ['fa', 'fb'],
        'updatedAt': now.millisecondsSinceEpoch + 1000,
      });
      await db.upsertBill('b3', {
        'title': 'Mine newer',
        'participantIds': ['me'],
        'updatedAt': now.millisecondsSinceEpoch + 2000,
      });
      final rows = await db.billsFor('me');
      expect(rows.map((r) => r['__id']), ['b3', 'b1']);
    });

    test('sync state round-trips (pending -> synced)', () async {
      await db.upsertBill(
          'b1',
          {
            'participantIds': ['me']
          },
          syncState: 'pending');
      expect(await db.billSyncState('b1'), 'pending');
      await db.markBillSynced('b1');
      expect(await db.billSyncState('b1'), 'synced');
      expect((await db.pendingBills()).length, 0);
    });

    test('billsForGroup filters by groupId', () async {
      await db.upsertBill('b1', {
        'groupId': 'g1',
        'participantIds': ['me']
      });
      await db.upsertBill('b2', {
        'groupId': 'g2',
        'participantIds': ['me']
      });
      await db.upsertBill('b3', {
        'participantIds': ['me']
      });
      final rows = await db.billsForGroup('g1');
      expect(rows.map((r) => r['__id']), ['b1']);
    });
  });

  group('outbox', () {
    test('FIFO order is preserved, retries bump, removal works', () async {
      await db.enqueue('bill.create', {'n': 1});
      await db.enqueue('bill.setPaid', {'n': 2});
      await db.enqueue('notify', {'n': 3});
      var ops = await db.peekOutbox();
      expect(
          ops.map((o) => o['type']), ['bill.create', 'bill.setPaid', 'notify']);
      expect(await db.outboxCount(), 3);

      await db.bumpOutboxRetries(ops.first['id'] as int);
      ops = await db.peekOutbox();
      expect(ops.first['retries'], 1);

      await db.removeOutbox(ops.first['id'] as int);
      ops = await db.peekOutbox();
      expect(ops.map((o) => o['type']), ['bill.setPaid', 'notify']);
      expect(await db.outboxCount(), 2);
    });
  });

  group('request id remap', () {
    test('re-keys a local request row to its remote id', () async {
      final req = ConnectionRequest(
        id: 'local-123',
        fromUid: 'me',
        fromName: 'Me Myself',
        toUid: 'fa',
        toName: 'Friend A',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.upsertRequest('local-123', req.toMap(), 'out');
      await db.remapRequestId('local-123', 'remote-9');

      final out = await db.requestRows('out');
      expect(out.length, 1);
      expect(out.first['__id'], 'remote-9');
      expect(out.first['toUid'], 'fa');
    });

    test('remap of a missing row is a no-op', () async {
      await db.remapRequestId('local-gone', 'remote-1');
      expect(await db.requestRows('out'), isEmpty);
    });
  });

  group('notification read flags', () {
    Map<String, dynamic> notif(String id, bool read) => {
          'toUid': 'me',
          'title': 'T$id',
          'body': 'Body',
          'type': 'bill_created',
          'read': read,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };

    test('mark read locally -> pending_read -> synced', () async {
      await db.upsertNotification('n1', notif('n1', false));
      await db.upsertNotification('n2', notif('n2', false));
      expect(await db.unreadCount(), 2);

      await db.markNotificationReadLocal('n1');
      expect(await db.unreadCount(), 1);
      expect(await db.pendingReadNotificationIds(), ['n1']);

      await db.markNotificationSynced('n1');
      expect(await db.pendingReadNotificationIds(), isEmpty);
    });

    test('mark all read locally flags every unread row', () async {
      await db.upsertNotification('n1', notif('n1', false));
      await db.upsertNotification('n2', notif('n2', true));
      await db.upsertNotification('n3', notif('n3', false));
      await db.markAllNotificationsReadLocal();
      expect(await db.unreadCount(), 0);
      expect((await db.pendingReadNotificationIds())..sort(), ['n1', 'n3']);
    });
  });

  group('meta + connections + users', () {
    test('meta round-trips and overwrites', () async {
      expect(await db.getMeta('cursor_bills'), isNull);
      await db.setMeta('cursor_bills', '123');
      await db.setMeta('cursor_bills', '456');
      expect(await db.getMeta('cursor_bills'), '456');
    });

    test('replaceConnections swaps the whole mirror set', () async {
      await db.replaceConnections([
        {'uid': 'fa', 'displayName': 'Friend A', 'email': ''},
        {'uid': 'fb', 'displayName': 'Friend B', 'email': ''},
      ]);
      expect((await db.connectionRows()).length, 2);
      await db.replaceConnections([
        {'uid': 'fb', 'displayName': 'Friend B', 'email': ''},
      ]);
      final rows = await db.connectionRows();
      expect(rows.length, 1);
      expect(rows.first['uid'], 'fb');
      await db.deleteConnection('fb');
      expect(await db.connectionRows(), isEmpty);
    });

    test('user rows round-trip a profile', () async {
      await db.upsertUser('me', meUser.toProfileMap());
      final row = await db.userRow('me');
      final user = AppUser.fromMap('me', row!);
      expect(user.displayName, 'Me Myself');
      expect(user.email, 'me@example.com');
    });
  });
}
