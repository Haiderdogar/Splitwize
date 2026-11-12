import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/screens/group_detail_screen.dart';
import 'package:splitwize/screens/group_invitation_screen.dart';
import 'package:splitwize/screens/home_shell.dart';
import 'package:splitwize/screens/notifications_screen.dart';
import 'package:splitwize/screens/request_screens.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/utils/notification_destination.dart';
import 'package:splitwize/widgets/friend_request_card.dart';
import 'package:splitwize/widgets/group_invitation_card.dart';
import 'fake_sync_service.dart';

const me =
    AppUser(uid: 'me', displayName: 'Ali Haider', email: 'ali@example.com');
const sender =
    AppUser(uid: 'fa', displayName: 'Hamza Malik', email: 'hamza@example.com');
const recipient =
    AppUser(uid: 'fb', displayName: 'Sara Khan', email: 'sara@example.com');
const incoming =
    BillGroup(id: 'g-in', name: 'Weekend', createdBy: 'fa', members: [
  'fa'
], invited: [
  'me'
], invitations: {
  'me': GroupInvitation(from: sender, to: me),
});
const outgoing =
    BillGroup(id: 'g-out', name: 'Road trip', createdBy: 'me', members: [
  'me'
], invited: [
  'fb'
], invitations: {
  'fb': GroupInvitation(from: me, to: recipient),
});

class InvitationRepository extends Fake implements AppRepository {
  BillGroup group = incoming;
  final changes = StreamController<BillGroup?>.broadcast();
  int accepts = 0;
  bool failAccept = false;
  Future<void>? acceptGate;
  final cancelled = <String>[];
  final read = <String>[];
  Future<void>? readGate;
  Stream<BillGroup?> watch() async* {
    yield group;
    yield* changes.stream;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    read.add(id);
    await readGate;
  }

  @override
  Future<void> cancelGroupInvite(String groupId, String recipientUid) async {
    cancelled.add('$groupId|$recipientUid');
  }

  @override
  Future<void> acceptGroupInviteConfirmed(String groupId) async {
    accepts++;
    await acceptGate;
    if (failAccept) throw StateError('Server rejected invitation');
    group = group.copyWith(
        members: [...group.members, 'me'], invited: [], invitations: {});
    changes.add(group);
  }
}

Future<void> pumpFlow(
    WidgetTester tester, Widget screen, InvitationRepository repo,
    {List<AppNotification> inbox = const [],
    void Function()? onBillsRead}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUidProvider.overrideWith((ref) => 'me'),
    currentAppUserProvider.overrideWith((ref) => Stream.value(me)),
    authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
    appRepositoryProvider.overrideWith((ref) async => repo),
    syncServiceProvider.overrideWith((ref) async => FakeSyncService()),
    appUserProvider.overrideWith((ref, uid) => Stream.value({
          'me': me,
          'fa': sender,
          'fb': recipient,
        }[uid])),
    groupProvider.overrideWith((ref, id) => repo.watch()),
    groupInvitesProvider.overrideWith((ref) => Stream.value([incoming])),
    myGroupsProvider.overrideWith((ref) => Stream.value([outgoing])),
    myBillsProvider.overrideWith((ref) => Stream.value(<Bill>[])),
    balancesProvider.overrideWith((ref) => <FriendBalance>[]),
    connectionsProvider.overrideWith((ref) => Stream.value([sender])),
    incomingRequestsProvider.overrideWith((ref) => Stream.value([
          ConnectionRequest(
              id: 'friend-in',
              fromUid: 'fa',
              fromName: sender.displayName,
              fromEmail: sender.email,
              toUid: 'me',
              toName: me.displayName,
              toEmail: me.email,
              status: 'pending',
              createdAt: DateTime(2026, 11, 11)),
        ])),
    outgoingRequestsProvider.overrideWith((ref) => Stream.value([
          ConnectionRequest(
              id: 'friend-out',
              fromUid: 'me',
              fromName: me.displayName,
              fromEmail: me.email,
              toUid: 'fb',
              toName: recipient.displayName,
              toEmail: recipient.email,
              status: 'pending',
              createdAt: DateTime(2026, 11, 11)),
        ])),
    groupBillsProvider.overrideWith((ref, id) {
      onBillsRead?.call();
      return Stream.value(<Bill>[]);
    }),
    groupMembersProvider.overrideWith((ref, id) async => [me, sender]),
    invitedUsersProvider.overrideWith((ref, id) async => []),
    notificationsProvider.overrideWith((ref) => Stream.value(inbox)),
  ], child: MaterialApp(theme: splitwizeLightTheme, home: screen)));
  await tester.pumpAndSettle();
}

void main() {
  late InvitationRepository repo;
  setUp(() {
    repo = InvitationRepository();
  });
  tearDown(() async {
    await repo.changes.close();
  });

  testWidgets(
      'friend incoming and outgoing cards show full name, email and date',
      (tester) async {
    await pumpFlow(tester, const FriendRequestsScreen(), repo);
    expect(find.text('Friend invitations'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.byType(GroupInvitationCard), findsNothing);
    expect(find.text(sender.displayName), findsOneWidget);
    expect(find.text(sender.email), findsOneWidget);
    expect(find.textContaining('Sent Nov 11, 2026'), findsOneWidget);
    await tester.ensureVisible(find.text('Outgoing (1)'));
    await tester.tap(find.text('Outgoing (1)'));
    await tester.pumpAndSettle();
    expect(find.text(recipient.displayName), findsOneWidget);
    expect(find.text(recipient.email), findsOneWidget);
    expect(find.text('Waiting for response'), findsOneWidget);
  });

  testWidgets('group directions show inviter, recipient, group and counts',
      (tester) async {
    await pumpFlow(tester, const GroupRequestsScreen(), repo);
    expect(find.text('Group invitations'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.byType(FriendRequestCard), findsNothing);
    expect(find.text('Incoming (1)'), findsOneWidget);
    expect(find.text('Outgoing (1)'), findsOneWidget);
    expect(find.text('Group: Weekend'), findsOneWidget);
    expect(find.text(sender.email), findsOneWidget);
    expect(find.text('Decline'), findsNothing);
    expect(find.text('Group currency'), findsNothing);
    await tester.ensureVisible(find.text('Outgoing (1)'));
    await tester.tap(find.text('Outgoing (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Group: Road trip'), findsOneWidget);
    expect(find.text(recipient.email), findsOneWidget);
    expect(find.text(me.email), findsOneWidget);
    await tester.tap(find.text('Cancel invitation'));
    await tester.pumpAndSettle();
    expect(repo.cancelled, ['g-out|fb']);
  });

  for (final screen in const [
    GroupRequestsScreen(initialIndex: 1),
    FriendRequestsScreen(initialIndex: 1),
  ]) {
    testWidgets('${screen.runtimeType} can open directly to outgoing',
        (tester) async {
      await pumpFlow(tester, screen, repo);
      expect(find.text(recipient.email), findsOneWidget);
      final tab = tester.widget<TabBar>(find.byType(TabBar));
      expect(tab.tabs, hasLength(2));
      expect(DefaultTabController.of(tester.element(find.byType(TabBar))).index,
          1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Embedded inbox keeps the shell when opening a friend invitation',
      (tester) async {
    await pumpFlow(tester, const HomeShell(), repo, inbox: const [
      AppNotification(
          id: 'friend-notice',
          toUid: 'me',
          title: 'Hamza sent a friend invitation',
          body: 'Review your incoming friend invitation.',
          type: 'friend_request',
          read: false),
    ]);
    final nav = find.byType(NavigationBar);
    await tester
        .tap(find.descendant(of: nav, matching: find.text('Notifications')));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
    expect(
        tester
            .widget<NotificationsScreen>(find.byType(NotificationsScreen))
            .embedded,
        isTrue);
    await tester.tap(find.text('Hamza sent a friend invitation'));
    await tester.pumpAndSettle();
    expect(repo.read, ['friend-notice']);
    expect(find.byType(FriendRequestsScreen), findsOneWidget);
    expect(find.byType(GroupRequestsScreen), findsNothing);
    expect(find.byType(HomeShell, skipOffstage: false), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Hamza sent a friend invitation'), findsOneWidget);
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Repeated embedded inbox taps open just one invitation route',
      (tester) async {
    final readComplete = Completer<void>();
    repo.readGate = readComplete.future;
    await pumpFlow(tester, const HomeShell(), repo, inbox: const [
      AppNotification(
          id: 'friend-repeat',
          toUid: 'me',
          title: 'Review Hamza invitation',
          body: 'Review your incoming friend invitation.',
          type: 'friend_request',
          read: false),
    ]);
    final nav = find.byType(NavigationBar);
    await tester
        .tap(find.descendant(of: nav, matching: find.text('Notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Hamza invitation'));
    await tester.pump();
    await tester.tap(find.text('Review Hamza invitation'));
    await tester.pump();
    expect(repo.read, ['friend-repeat', 'friend-repeat']);

    readComplete.complete();
    await tester.pumpAndSettle();
    expect(
        find.byType(FriendRequestsScreen, skipOffstage: false), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(
        find.byType(FriendRequestsScreen, skipOffstage: false), findsNothing);
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A delayed notification does not open after changing tabs',
      (tester) async {
    final readComplete = Completer<void>();
    repo.readGate = readComplete.future;
    await pumpFlow(tester, const HomeShell(), repo, inbox: const [
      AppNotification(
          id: 'friend-delayed',
          toUid: 'me',
          title: 'Review delayed invitation',
          body: 'Review your incoming friend invitation.',
          type: 'friend_request',
          read: false),
    ]);
    final nav = find.byType(NavigationBar);
    await tester
        .tap(find.descendant(of: nav, matching: find.text('Notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review delayed invitation'));
    await tester.pump();
    await tester.tap(find.descendant(of: nav, matching: find.text('Friends')));
    await tester.pumpAndSettle();
    readComplete.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(
        find.byType(FriendRequestsScreen, skipOffstage: false), findsNothing);
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Standalone inbox keeps Back and replaces only its own route',
      (tester) async {
    await pumpFlow(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NotificationsScreen())),
              child: const Text('Open standalone inbox'),
            ),
          ),
        ),
        repo,
        inbox: const [
          AppNotification(
              id: 'group-notice',
              toUid: 'me',
              title: 'Review group invitations',
              body: 'Review your incoming group invitations.',
              type: 'group_invite',
              read: false),
        ]);
    await tester.tap(find.text('Open standalone inbox'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.text('Review group invitations'));
    await tester.pumpAndSettle();
    expect(repo.read, ['group-notice']);
    expect(find.byType(GroupRequestsScreen), findsOneWidget);
    expect(find.byType(NotificationsScreen, skipOffstage: false), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open standalone inbox'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'notification opens an incoming preview and unlocks only after confirmed acceptance',
      (tester) async {
    var billsRead = 0;
    final accepted = Completer<void>();
    repo.acceptGate = accepted.future;
    await pumpFlow(tester, const NotificationsScreen(), repo,
        onBillsRead: () => billsRead++,
        inbox: const [
          AppNotification(
              id: 'invite',
              toUid: 'me',
              title: 'Weekend invitation',
              body: 'Hamza invited you to Weekend.',
              type: 'group_invite',
              groupId: 'g-in',
              read: false)
        ]);
    await tester.tap(find.text('Weekend invitation'));
    await tester.pumpAndSettle();
    expect(repo.read, ['invite']);
    expect(find.byType(GroupInvitationScreen), findsOneWidget);
    expect(find.text('Incoming group invitation'), findsOneWidget);
    expect(find.text(sender.email), findsOneWidget);
    expect(find.text('Group currency'), findsNothing);
    expect(billsRead, 0);
    await tester.tap(find.text('Accept group invitation'));
    await tester.pump();
    expect(repo.accepts, 1);
    expect(find.text('Accepting...'), findsOneWidget);
    expect(find.text('Group currency'), findsNothing);
    expect(billsRead, 0);
    accepted.complete();
    await tester.pumpAndSettle();
    expect(find.text('Group currency'), findsOneWidget);
    expect(billsRead, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'direct group details stays gated and failed acceptance does not unlock',
      (tester) async {
    repo.failAccept = true;
    var billsRead = 0;
    await pumpFlow(tester, const GroupDetailScreen(groupId: 'g-in'), repo,
        onBillsRead: () => billsRead++);
    expect(find.text('Group currency'), findsNothing);
    expect(billsRead, 0);
    await tester.tap(find.text('Accept group invitation'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Could not accept invitation. Check your connection and try again.'),
        findsOneWidget);
    expect(find.text('Group currency'), findsNothing);
    expect(billsRead, 0);
    expect(repo.group.members, isNot(contains('me')));
  });

  testWidgets(
      'expired invitation provides no group details or acceptance action',
      (tester) async {
    repo.group = incoming.copyWith(invited: [], invitations: {});
    await pumpFlow(tester, const GroupInvitationScreen(groupId: 'g-in'), repo);
    expect(
        find.text('This invitation is no longer available.'), findsOneWidget);
    expect(find.text('Accept group invitation'), findsNothing);
    expect(find.text('Group currency'), findsNothing);
  });

  test('push and inbox use the same safe group invitation route', () {
    expect(notificationDestination(type: 'group_invite', groupId: 'g-in'),
        isA<GroupInvitationScreen>());
    expect(
        notificationDestination(
            type: 'group_invite', groupId: 'g-in', fromInbox: true),
        isA<GroupInvitationScreen>());
    expect(
        (notificationDestination(type: 'friend_request')
                as FriendRequestsScreen)
            .initialIndex,
        0);
    expect(notificationDestination(type: 'group_invite'),
        isA<GroupRequestsScreen>());
    expect(notificationDestination(type: 'group_invite', groupId: ''),
        isA<GroupRequestsScreen>());
  });
}
