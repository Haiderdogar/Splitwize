import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';

import 'test_harness.dart' show initTestEnv;

const inviter = AppUser(
    uid: 'notification-producer-me',
    displayName: 'Ali Haider',
    email: 'ali@example.com');
const invitee =
    AppUser(uid: 'sara', displayName: 'Sara Khan', email: 'sara@example.com');
const otherInvitee = AppUser(
    uid: 'hamza', displayName: 'Hamza Malik', email: 'hamza@example.com');

// Seed only the search result; exercise the actual sendInvite implementation.
class FoundFriend extends AddFriend {
  @override
  AddFriendState build() => const AddFriendState(found: invitee);
}

void main() {
  setUpAll(initTestEnv);
  late LocalDatabase db;
  late AppRepository repo;
  late ProviderContainer container;

  setUp(() async {
    await LocalDatabase.deleteForUid(inviter.uid);
    db = await LocalDatabase.open(inviter.uid);
    repo = AppRepository(
        db: db,
        remote: FirestoreService(),
        secure: SecureStorageService(),
        myUid: inviter.uid);
    for (final user in [inviter, invitee, otherInvitee]) {
      await db.upsertUser(user.uid, user.toProfileMap());
    }
    container = ProviderContainer(overrides: [
      currentUidProvider.overrideWith((ref) => inviter.uid),
      appRepositoryProvider.overrideWith((ref) async => repo),
      connectionsProvider
          .overrideWith((ref) => Stream.value([invitee, otherInvitee])),
      addFriendProvider.overrideWith(FoundFriend.new),
    ]);
    container.listen(createGroupFormProvider, (_, __) {});
    container.listen(addFriendProvider, (_, __) {});
    container.listen(connectionsProvider, (_, __) {});
    await container.read(appRepositoryProvider.future);
    await container.read(connectionsProvider.future);
  });

  tearDown(() async {
    container.dispose();
    repo.dispose();
    await LocalDatabase.deleteForUid(inviter.uid);
  });

  test('connection form queues sender identity alongside its readable message',
      () async {
    expect(
        await container.read(addFriendProvider.notifier).sendInvite(), isNull);
    final outbox = await db.peekOutbox();
    expect(outbox.map((op) => op['type']), ['conn.send', 'notify']);
    final notification = outbox.last['payload'] as Map;
    expect(notification['toUid'], invitee.uid);
    expect(notification['type'], 'friend_request');
    expect(notification['body'],
        'Ali Haider invited you to connect on Splitwize.');
    expect(notification['fromUid'], inviter.uid);
    expect(notification['fromName'], inviter.displayName);
    expect(notification['fromEmail'], inviter.email);
  });

  test('group form queues the same inviter and group for every recipient',
      () async {
    final form = container.read(createGroupFormProvider.notifier);
    form.setName('  Weekend away  ');
    form.toggle(invitee.uid, true);
    form.toggle(otherInvitee.uid, true);
    expect(await form.submit(), isNull);
    final outbox = await db.peekOutbox();
    expect(
        outbox.map((op) => op['type']), ['group.create', 'notify', 'notify']);
    final created = (outbox.first['payload'] as Map)['group'] as Map;
    final notifications = outbox
        .where((op) => op['type'] == 'notify')
        .map((op) => op['payload'] as Map)
        .toList();
    expect(notifications.map((n) => n['toUid']).toSet(),
        {invitee.uid, otherInvitee.uid});
    for (final notification in notifications) {
      expect(notification['type'], 'group_invite');
      expect(notification['groupId'], created['id']);
      expect(notification['groupName'], 'Weekend away');
      expect(notification['fromUid'], inviter.uid);
      expect(notification['fromName'], inviter.displayName);
      expect(notification['fromEmail'], inviter.email);
      expect(notification['body'],
          'Ali Haider invited you to join "Weekend away".');
    }
  });
}
