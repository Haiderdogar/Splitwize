import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/services/sync_service.dart';

import 'test_harness.dart';

class RecordingRemote extends FirestoreService {
  final writes = <String>[];
  final bills = <Map<String, dynamic>>[];
  final uploads = <String>[];
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();
  bool failWrites = false;
  int pulls = 0;
  Future<void> Function()? beforePull;
  List<AppUser> connections = [];
  int connectionPulls = 0;
  bool failConnections = false;
  Completer<void>? connectionGate;
  List<AppUser> profiles = [];
  BillGroup? invitationGroup;
  bool invitationForbidden = false;
  @override
  Future<BillGroup?> getGroup(String groupId) async {
    if (invitationForbidden) {
      throw FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied');
    }
    return invitationGroup;
  }

  @override
  Future<List<AppUser>> fetchUsers(List<String> uids) async =>
      profiles.where((user) => uids.contains(user.uid)).toList();

  @override
  Future<void> setGroupCurrency(String groupId, String code) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    if (failWrites) throw StateError('Network unavailable');
    writes.add(groupId);
  }

  @override
  Future<void> pushBill(Map<String, dynamic> map) async {
    if (failWrites) throw StateError('Network unavailable');
    bills.add(Map.of(map));
  }

  @override
  Future<String> uploadReceipt(String billId, File file) async {
    uploads.add(billId);
    return 'https://example.com/$billId.jpg';
  }

  @override
  Future<List<Bill>> fetchBillsDelta(String uid, {DateTime? since}) async {
    pulls++;
    await beforePull?.call();
    return [];
  }

  @override
  Future<List<BillGroup>> fetchGroupsDelta(String uid,
          {DateTime? since}) async =>
      [];

  @override
  Future<List<AppNotification>> fetchNotificationsDelta(String uid,
          {DateTime? since}) async =>
      [];

  @override
  Future<List<ConnectionRequest>> fetchRequests(String uid,
          {DateTime? since}) async =>
      [];

  @override
  Future<List<AppUser>> fetchConnectionMirrors(String uid) async {
    connectionPulls++;
    await connectionGate?.future;
    if (failConnections) throw StateError('Could not load friends');
    return connections;
  }
}

void main() {
  setUpAll(initTestEnv);
  late LocalDatabase db;
  late AppRepository repo;
  late RecordingRemote remote;
  late SyncService sync;
  var online = true;

  setUp(() async {
    await LocalDatabase.deleteForUid('sync-test');
    db = await LocalDatabase.open('sync-test');
    remote = RecordingRemote();
    repo = AppRepository(
        db: db,
        remote: remote,
        secure: SecureStorageService(),
        myUid: 'sync-test');
    sync = SyncService(repository: repo, remote: remote);
    online = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => [online ? 'wifi' : 'none'],
    );
  });

  tearDown(() async {
    sync.dispose();
    repo.dispose();
    await LocalDatabase.deleteForUid('sync-test');
  });

  Future<void> enqueueCurrency(String id) =>
      db.enqueue('group.currency', {'groupId': id, 'currency': 'USD'});

  test('drains more than one outbox batch in order before pulling', () async {
    for (var i = 0; i < 205; i++) {
      await enqueueCurrency('$i');
    }
    remote.beforePull = () async => expect(await db.outboxCount(), 0);
    await sync.syncNow();
    expect(remote.writes, List.generate(205, (i) => '$i'));
    expect(sync.current.pending, 0);
    expect(sync.current.error, isNull);
  });

  test('friends refresh bypasses a failed outbox and updates live connections',
      () async {
    await enqueueCurrency('blocked');
    remote.failWrites = true;
    await sync.syncNow();
    expect(remote.connectionPulls, 0);
    remote.connections = [friendA, friendB];
    final next =
        repo.watchConnections().firstWhere((users) => users.length == 2);
    await sync.refreshConnections();
    expect((await next).map((user) => user.uid).toSet(), {'fa', 'fb'});
    expect(await db.outboxCount(), 1);
    expect(remote.pulls, 0);
  });

  test('failed friends refresh preserves cached connections and can retry',
      () async {
    await repo.applyRemoteConnections([friendA]);
    remote.failConnections = true;
    await expectLater(sync.refreshConnections(), throwsStateError);
    expect((await repo.watchConnections().first).single.uid, 'fa');
    remote.failConnections = false;
    remote.connections = [friendA, friendB];
    await sync.refreshConnections();
    expect((await repo.watchConnections().first).length, 2);
  });

  test('overlapping friends refreshes share one remote read', () async {
    remote.connectionGate = Completer<void>();
    final first = sync.refreshConnections();
    final second = sync.refreshConnections();
    expect(remote.connectionPulls, 1);
    remote.connectionGate!.complete();
    await Future.wait([first, second]);
    expect(remote.connectionPulls, 1);
  });

  test('friends refresh retains rich profiles from sparse mirrors', () async {
    await db.upsertUser(friendA.uid, friendA.toProfileMap());
    remote.connections = [
      const AppUser(uid: 'fa', displayName: 'Friend A', email: '')
    ];
    await sync.refreshConnections();
    expect((await repo.watchConnections().first).single.email, friendA.email);
    expect((await repo.getCachedUser('fa'))!.email, friendA.email);
  });

  test('friends refresh fetches missing emails for existing connections',
      () async {
    remote.connections = [
      const AppUser(uid: 'fa', displayName: 'Friend A', email: '')
    ];
    remote.profiles = [friendA];
    await sync.refreshConnections();
    expect((await repo.watchConnections().first).single.email, friendA.email);
  });

  test('friends refresh preserves pending accepts and pending removals',
      () async {
    const request = ConnectionRequest(
        id: 'accept-me',
        fromUid: 'fa',
        fromName: 'Friend A',
        toUid: 'sync-test',
        toName: 'Me',
        status: 'pending');
    await repo.acceptConnectionRequest(request);
    remote.connections = [];
    await sync.refreshConnections();
    expect((await repo.watchConnections().first).single.uid, 'fa');
    await repo.removeConnection('fa');
    remote.connections = [friendA];
    await sync.refreshConnections();
    expect(await repo.watchConnections().first, isEmpty);
  });

  test('failed writes preserve FIFO order and retry on the next sync',
      () async {
    await enqueueCurrency('first');
    await enqueueCurrency('second');
    remote.failWrites = true;
    await sync.syncNow();
    expect(await db.outboxCount(), 2);
    expect((await db.peekOutbox()).first['retries'], 1);
    expect(remote.pulls, 0);
    expect(sync.current.error, isNotNull);
    remote.failWrites = false;
    await sync.syncNow();
    expect(remote.writes, ['first', 'second']);
    expect(await db.outboxCount(), 0);
    expect(sync.current.error, isNull);
  });

  test('offline sync retains pending changes', () async {
    await enqueueCurrency('first');
    online = false;
    await sync.syncNow();
    expect(sync.current.online, isFalse);
    expect(sync.current.pending, 1);
    expect(remote.writes, isEmpty);
    expect(remote.pulls, 0);
  });

  test('a cancelled group invitation is removed when access is withdrawn',
      () async {
    const invitation = BillGroup(
        id: 'cancelled',
        name: 'Trip',
        createdBy: 'owner',
        members: ['owner'],
        invited: ['sync-test']);
    await repo.applyRemoteGroup(invitation);
    remote.invitationForbidden = true;
    await sync.refreshGroupInvitation(invitation.id);
    expect(await repo.groupById(invitation.id), isNull);
    expect(await repo.watchGroupInvites().first, isEmpty);
  });

  test(
      'an invitation refresh fetches the inviter profile for older invitations',
      () async {
    remote.invitationGroup = const BillGroup(
        id: 'legacy-invite',
        name: 'Trip',
        createdBy: 'fa',
        members: ['fa'],
        invited: ['sync-test']);
    remote.profiles = [friendA];
    await sync.refreshGroupInvitation('legacy-invite');
    expect((await repo.getCachedUser('fa'))!.email, friendA.email);
  });

  test('concurrent callers wait for the active sync to complete', () async {
    await enqueueCurrency('first');
    remote.writeGate = Completer<void>();
    final first = sync.syncNow();
    await remote.writeStarted.future;
    var completed = false;
    final second = sync.syncNow().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    remote.writeGate!.complete();
    await Future.wait([first, second]);
    expect(completed, isTrue);
    expect(remote.writes, ['first']);
    expect(sync.current.syncing, isFalse);
  });

  test('disposing during a write stops sync before accessing the closed DB',
      () async {
    await enqueueCurrency('first');
    remote.writeGate = Completer<void>();
    final pending = sync.syncNow();
    await remote.writeStarted.future;
    sync.dispose();
    await LocalDatabase.close();
    remote.writeGate!.complete();
    await pending;
    expect(remote.pulls, 0);
    await sync.syncNow();
  });

  test('a removed receipt is not resurrected from the queued create', () async {
    final file =
        File('${Directory.systemTemp.path}/splitwize-sync-receipt.jpg');
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    const bill = Bill(
        id: 'receipt-test',
        title: 'Lunch',
        subtotal: 10,
        tipPercent: 0,
        total: 10,
        splitType: 'equal',
        createdBy: 'sync-test',
        createdByName: 'Me',
        participantIds: ['sync-test'],
        splits: []);
    await db.upsertBill(bill.id, bill.toMap(), syncState: 'pending');
    await db.enqueue('bill.create', {
      'bill': {
        ...bill.toMap(),
        'id': bill.id,
        'receiptLocalPath': file.path,
        'receiptImageUrl': 'https://example.com/old.jpg',
      }
    });
    await sync.syncNow();
    expect(remote.uploads, isEmpty);
    expect(remote.bills.single['receiptImageUrl'], isNull);
    expect((await repo.billById(bill.id))!.receiptImageUrl, isNull);
  });
}
