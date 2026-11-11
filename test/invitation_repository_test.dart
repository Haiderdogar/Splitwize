import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/invitation_providers.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'test_harness.dart' show initTestEnv;

const me = AppUser(
    uid: 'invitation-test', displayName: 'Ali', email: 'ali@example.com');
const friend =
    AppUser(uid: 'friend', displayName: 'Sara', email: 'sara@example.com');
const owner =
    AppUser(uid: 'owner', displayName: 'Hamza', email: 'hamza@example.com');

class InviteRemote extends FirestoreService {
  BillGroup? group;
  bool fail = false;
  @override
  Future<BillGroup?> getGroup(String groupId) async => group;
  @override
  Future<void> acceptGroupInvite(String groupId, String uid) async {
    if (fail) throw StateError('No connection');
    if (group == null || !group!.invited.contains(uid)) {
      throw StateError('Expired');
    }
    group = group!.copyWith(
        members: [...group!.members, uid],
        invited: group!.invited.where((id) => id != uid).toList(),
        invitations: {...group!.invitations}..remove(uid));
  }
}

void main() {
  setUpAll(initTestEnv);
  late LocalDatabase db;
  late InviteRemote remote;
  late AppRepository repo;
  setUp(() async {
    await LocalDatabase.deleteForUid(me.uid);
    db = await LocalDatabase.open(me.uid);
    remote = InviteRemote();
    repo = AppRepository(
        db: db, remote: remote, secure: SecureStorageService(), myUid: me.uid);
    for (final user in [me, friend, owner]) {
      await db.upsertUser(user.uid, user.toProfileMap());
    }
  });
  tearDown(() async {
    repo.dispose();
    await LocalDatabase.deleteForUid(me.uid);
  });

  test(
      'friend request snapshots keep both names and emails through serialization',
      () async {
    await repo.sendConnectionRequest(from: me, to: friend);
    final request = (await repo.watchOutgoingRequests().first).single;
    final parsed = ConnectionRequest.fromMap(request.id, request.toMap());
    expect(parsed.fromEmail, me.email);
    expect(parsed.toEmail, friend.email);
    expect(parsed, request);
    final payload = (await db.peekOutbox()).single['payload'] as Map;
    expect(payload['fromEmail'], me.email);
    expect(payload['toEmail'], friend.email);
  });

  test('group creation snapshots the inviter, recipient and invitation date',
      () async {
    final id = await repo.createGroup(
        name: 'Weekend', creator: me, invitees: [friend], currency: 'USD');
    final group = (await repo.groupById(id))!;
    final parsed = BillGroup.fromMap(group.id, group.toMap());
    expect(parsed, group);
    expect(parsed.hashCode, group.hashCode);
    expect(parsed.invitations[friend.uid]!.from.email, me.email);
    expect(parsed.invitations[friend.uid]!.to.email, friend.email);
    expect(parsed.invitations[friend.uid]!.sentAt, isNotNull);
  });

  test('a non-owner invitation records the actual sender and can be cancelled',
      () async {
    const group = BillGroup(
        id: 'members-group',
        name: 'Team',
        createdBy: 'owner',
        members: ['owner', 'invitation-test'],
        invited: []);
    await repo.applyRemoteGroup(group);
    await repo.inviteToGroup(group.id, [friend.uid]);
    final updated = (await repo.groupById(group.id))!;
    expect(updated.invitations[friend.uid]!.from, me);
    expect(updated.invitations[friend.uid]!.to, friend);
    final container = ProviderContainer(overrides: [
      currentUidProvider.overrideWith((ref) => me.uid),
      myGroupsProvider.overrideWith((ref) => Stream.value([updated])),
    ]);
    final sub = container.listen(outgoingGroupInvitesProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(outgoingGroupInvitesProvider).value!.single.recipientUid,
        friend.uid);
    sub.close();
    container.dispose();
    await repo.cancelGroupInvite(group.id, friend.uid);
    final cancelled = (await repo.groupById(group.id))!;
    expect(cancelled.invited, isEmpty);
    expect(cancelled.invitations, isEmpty);
    expect((await db.peekOutbox()).last['type'], 'group.cancelInvite');
  });

  test(
      'failed confirmation never creates local membership; successful confirmation does',
      () async {
    remote.group =
        BillGroup(id: 'incoming', name: 'Trip', createdBy: owner.uid, members: [
      owner.uid
    ], invited: [
      me.uid
    ], invitations: {
      me.uid: const GroupInvitation(from: owner, to: me),
    });
    await repo.applyRemoteGroup(remote.group!);
    remote.fail = true;
    await expectLater(
        repo.acceptGroupInviteConfirmed('incoming'), throwsStateError);
    expect(
        (await repo.groupById('incoming'))!.members, isNot(contains(me.uid)));
    remote.fail = false;
    await repo.acceptGroupInviteConfirmed('incoming');
    expect((await repo.groupById('incoming'))!.members, contains(me.uid));
    expect((await repo.groupById('incoming'))!.invitations, isEmpty);
    expect(await db.peekOutbox(), isEmpty);
  });

  test('expired group invitation cannot be accepted locally', () async {
    await repo.applyRemoteGroup(const BillGroup(
        id: 'expired',
        name: 'Old trip',
        createdBy: 'owner',
        members: ['owner'],
        invited: []));
    await expectLater(repo.acceptGroupInvite('expired'), throwsStateError);
    expect((await repo.groupById('expired'))!.members, isNot(contains(me.uid)));
    expect(await db.peekOutbox(), isEmpty);
  });
}
