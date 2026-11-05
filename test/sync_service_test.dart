import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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
  Future<List<AppUser>> fetchConnectionMirrors(String uid) async => [];
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
