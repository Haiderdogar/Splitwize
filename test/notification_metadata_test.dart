import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/services/sync_service.dart';

import 'test_harness.dart';

class NotificationRemote extends FirestoreService {
  final sent = <Map<String, dynamic>>[];

  @override
  Future<void> sendNotification({
    required String toUid,
    required String title,
    required String body,
    required String type,
    String? billId,
    String? groupId,
    String? fromUid,
    String? fromName,
    String? fromEmail,
    String? groupName,
  }) async {
    sent.add({
      'toUid': toUid,
      'title': title,
      'body': body,
      'type': type,
      'billId': billId,
      'groupId': groupId,
      'fromUid': fromUid,
      'fromName': fromName,
      'fromEmail': fromEmail,
      'groupName': groupName,
    });
  }

  @override
  Future<List<Bill>> fetchBillsDelta(String uid, {DateTime? since}) async => [];

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
  const invite = AppNotification(
    id: 'invite',
    toUid: 'notification-metadata',
    title: 'Group invitation',
    body: 'Hamza invited you to join "Weekend".',
    type: 'group_invite',
    groupId: 'weekend',
    fromUid: 'hamza',
    fromName: 'Hamza',
    fromEmail: 'hamza@example.com',
    groupName: 'Weekend',
    read: false,
  );

  setUpAll(initTestEnv);
  late LocalDatabase db;
  late AppRepository repo;
  late NotificationRemote remote;
  late SyncService sync;

  setUp(() async {
    await LocalDatabase.deleteForUid('notification-metadata');
    db = await LocalDatabase.open('notification-metadata');
    remote = NotificationRemote();
    repo = AppRepository(
      db: db,
      remote: remote,
      secure: SecureStorageService(),
      myUid: 'notification-metadata',
    );
    sync = SyncService(repository: repo, remote: remote);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });

  tearDown(() async {
    sync.dispose();
    repo.dispose();
    await LocalDatabase.deleteForUid('notification-metadata');
  });

  test('inviter and group snapshots survive serialization and read updates',
      () async {
    final parsed = AppNotification.fromMap(invite.id, invite.toMap());
    expect(parsed, invite);
    expect(parsed.hashCode, invite.hashCode);
    await repo.applyRemoteNotification(parsed);
    await repo.markNotificationRead(invite.id);
    // A later unread server copy must keep both the offline read and details.
    await repo.applyRemoteNotification(parsed);
    final cached = (await repo.watchNotifications().first).single;
    expect(cached, invite.copyWith(read: true));
    expect(cached.fromUid, 'hamza');
    expect(cached.fromName, 'Hamza');
    expect(cached.fromEmail, 'hamza@example.com');
    expect(cached.groupName, 'Weekend');
  });

  test('older notifications remain readable without invitation metadata', () {
    final parsed = AppNotification.fromMap('old', {
      'toUid': 'notification-metadata',
      'title': 'New friend request',
      'body': 'Sara wants to connect with you.',
      'type': 'friend_request',
      'read': false,
    });
    expect(parsed.fromUid, isNull);
    expect(parsed.fromName, isNull);
    expect(parsed.fromEmail, isNull);
    expect(parsed.groupName, isNull);
    expect(parsed.body, 'Sara wants to connect with you.');
    expect(parsed.copyWith(read: true).read, isTrue);
  });

  test('changes to invitation metadata participate in notification equality',
      () {
    for (final key in ['fromUid', 'fromName', 'fromEmail', 'groupName']) {
      final changed = AppNotification.fromMap(
          invite.id, {...invite.toMap(), key: 'Updated'});
      expect(changed, isNot(invite), reason: key);
    }
  });

  test('offline invitation metadata reaches the remote notification writer',
      () async {
    await repo.sendNotification(
      toUid: invite.toUid,
      title: invite.title,
      body: invite.body,
      type: invite.type,
      groupId: invite.groupId,
      fromUid: invite.fromUid,
      fromName: invite.fromName,
      fromEmail: invite.fromEmail,
      groupName: invite.groupName,
    );
    final payload = (await db.peekOutbox()).single['payload'] as Map;
    expect(payload['fromUid'], 'hamza');
    expect(payload['fromName'], 'Hamza');
    expect(payload['fromEmail'], 'hamza@example.com');
    expect(payload['groupName'], 'Weekend');
    await sync.syncNow();
    expect(sync.current.error, isNull);
    expect(await db.outboxCount(), 0);
    expect(remote.sent.single, payload);
  });

  test('queued legacy notifications sync without requiring new fields',
      () async {
    await db.enqueue('notify', {
      'toUid': 'friend',
      'title': 'Reminder',
      'body': 'Your share is due.',
      'type': 'reminder',
    });
    await sync.syncNow();
    expect(sync.current.error, isNull);
    expect(await db.outboxCount(), 0);
    expect(remote.sent.single['fromUid'], isNull);
    expect(remote.sent.single['groupName'], isNull);
    expect(remote.sent.single['body'], 'Your share is due.');
  });
}
