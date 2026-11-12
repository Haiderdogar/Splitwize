// Responsive-fit tests: pump every main screen at a range of phone
// sizes (portrait, small landscape, tablet) and text scales with
// deliberately long names/titles/amounts, and assert that no
// RenderFlex overflow (or any other exception) occurs.
//
// Data providers are overridden with in-memory samples, so no
// Firebase / SQLite is touched.
//
// The real Roboto family is loaded from the Flutter SDK, because the
// default test font is far wider than production fonts and would
// report overflows that never happen on a device.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;

import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/screens/balances_tab.dart';
import 'package:splitwize/screens/bill_detail_screen.dart';
import 'package:splitwize/screens/bills_tab.dart';
import 'package:splitwize/screens/create_bill_screen.dart';
import 'package:splitwize/screens/create_group_screen.dart';
import 'package:splitwize/screens/friends_tab.dart';
import 'package:splitwize/screens/group_detail_screen.dart';
import 'package:splitwize/screens/groups_tab.dart';
import 'package:splitwize/screens/home_shell.dart';
import 'package:splitwize/screens/notifications_screen.dart';
import 'package:splitwize/screens/onboarding_screen.dart';
import 'package:splitwize/screens/profile_tab.dart';
import 'package:splitwize/screens/settings_screen.dart';
import 'package:splitwize/screens/request_screens.dart';
import 'package:splitwize/screens/sign_in_screen.dart';
import 'package:splitwize/services/sync_service.dart';
import 'package:splitwize/widgets/app_drawer.dart';
import 'fake_sync_service.dart';

// ---------------------------------------------------------------------------
// Stress data: long strings + big amounts on purpose.
// ---------------------------------------------------------------------------

const me = AppUser(
  uid: 'me',
  displayName: 'Ali Haider',
  email: 'ali.haider@examplemail.com',
  currency: 'PKR',
);

const longNameFriend = AppUser(
  uid: 'f1',
  displayName: 'Alexandria Featherstonehaugh-Williams',
  email: 'alexandria.featherstonehaugh@verylongdomain.example.com',
);

const friend2 = AppUser(
  uid: 'f2',
  displayName: 'Hamza Malik',
  email: 'hamza@example.com',
);

const invitedUser = AppUser(
  uid: 'f9',
  displayName: 'Zainab Qureshi',
  email: 'zainab@example.com',
);

final testBill = Bill(
  id: 'b1',
  title: 'Team dinner at the extremely long named restaurant downtown',
  subtotal: 100000,
  tipPercent: 18,
  total: 118000,
  splitType: 'percentage',
  createdBy: 'me',
  createdByName: 'Ali Haider',
  groupId: 'g1',
  groupName: 'The Weekend Trip Planning Committee 2026',
  participantIds: const ['me', 'f1', 'f2'],
  splits: [
    BillSplit(
      uid: 'me',
      displayName: 'Ali Haider',
      amount: 47200,
      percent: 40,
      paid: true,
      paidAt: DateTime(2026, 10, 19),
    ),
    const BillSplit(
      uid: 'f1',
      displayName: 'Alexandria Featherstonehaugh-Williams',
      amount: 35400,
      percent: 30,
    ),
    const BillSplit(
      uid: 'f2',
      displayName: 'Hamza Malik',
      amount: 35400,
      percent: 30,
    ),
  ],
  createdAt: DateTime(2026, 10, 19, 20, 30),
  currency: 'PKR',
);

const testGroup = BillGroup(
  id: 'g1',
  name: 'The Weekend Trip Planning Committee 2026',
  createdBy: 'me',
  members: ['me', 'f1', 'f2'],
  invited: ['f9'],
  currency: 'PKR',
);

const incomingGroup = BillGroup(
    id: 'incoming-group',
    name: 'Weekend invitation',
    createdBy: 'f1',
    members: ['f1'],
    invited: ['me'],
    invitations: {'me': GroupInvitation(from: longNameFriend, to: me)});

const testBalances = [
  FriendBalance(
    uid: 'f1',
    displayName: 'Alexandria Featherstonehaugh-Williams',
    currency: 'PKR',
    net: -1234567.89,
    owesMe: 0,
    iOweThem: 1234567.89,
    openBills: 12,
  ),
  FriendBalance(
    uid: 'f2',
    displayName: 'Hamza Malik',
    currency: 'USD',
    net: 9876.54,
    owesMe: 9876.54,
    iOweThem: 0,
    openBills: 3,
  ),
];

final testNotifications = [
  AppNotification(
    id: 'n1',
    toUid: 'me',
    title: 'New bill: Team dinner at the extremely long named restaurant',
    body:
        'Alexandria Featherstonehaugh-Williams split a bill — your share is Rs 35,400.00 of Rs 118,000.00.',
    type: 'bill_created',
    billId: 'b1',
    read: false,
    createdAt: DateTime(2026, 10, 20, 9, 15),
  ),
  AppNotification(
    id: 'n2',
    toUid: 'me',
    title: 'Payment received',
    body: 'Hamza Malik marked their share as paid.',
    type: 'bill_paid',
    billId: 'b1',
    read: true,
    createdAt: DateTime(2026, 10, 19, 21, 2),
  ),
];

const testIncoming = [
  ConnectionRequest(
    id: 'r1',
    fromUid: 'f1',
    fromName: 'Alexandria Featherstonehaugh-Williams',
    toUid: 'me',
    toName: 'Ali Haider',
    status: 'pending',
  ),
];

const testOutgoing = [
  ConnectionRequest(
    id: 'r2',
    fromUid: 'me',
    fromName: 'Ali Haider',
    toUid: 'f9',
    toName: 'Zainab Qureshi',
    status: 'pending',
  ),
];

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

List<Override> testOverrides({
  Stream<List<AppNotification>>? inbox,
  Stream<List<BillGroup>>? groups,
  Stream<List<BillGroup>>? groupInvites,
  Stream<List<ConnectionRequest>>? incomingRequests,
  Stream<List<ConnectionRequest>>? outgoingRequests,
}) =>
    [
      syncServiceProvider.overrideWith((ref) async => FakeSyncService()),
      currentUidProvider.overrideWith((ref) => 'me'),
      myBillsProvider.overrideWith((ref) => Stream.value([testBill])),
      balancesProvider.overrideWith((ref) => testBalances),
      myGroupsProvider
          .overrideWith((ref) => groups ?? Stream.value([testGroup])),
      groupInvitesProvider
          .overrideWith((ref) => groupInvites ?? Stream.value([incomingGroup])),
      appUserProvider.overrideWith((ref, uid) => Stream.value({
            me.uid: me,
            longNameFriend.uid: longNameFriend,
            friend2.uid: friend2,
            invitedUser.uid: invitedUser,
          }[uid])),
      connectionsProvider
          .overrideWith((ref) => Stream.value([longNameFriend, friend2])),
      incomingRequestsProvider.overrideWith(
          (ref) => incomingRequests ?? Stream.value(testIncoming)),
      outgoingRequestsProvider.overrideWith(
          (ref) => outgoingRequests ?? Stream.value(testOutgoing)),
      notificationsProvider
          .overrideWith((ref) => inbox ?? Stream.value(testNotifications)),
      currentAppUserProvider.overrideWith((ref) => Stream.value(me)),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      billProvider.overrideWith((ref, id) => Stream.value(testBill)),
      groupProvider.overrideWith((ref, id) => Stream.value(testGroup)),
      groupMembersProvider
          .overrideWith((ref, id) async => [me, longNameFriend, friend2]),
      groupBillsProvider.overrideWith((ref, id) => Stream.value([testBill])),
      invitedUsersProvider.overrideWith((ref, id) async => [invitedUser]),
      createBillMembersProvider
          .overrideWith((ref) async => [me, longNameFriend, friend2]),
      syncStatusProvider.overrideWith(
          (ref) => Stream.value(const SyncState(online: true, pending: 2))),
    ];

Future<void> pumpAt(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  double textScale = 1.0,
  Stream<List<AppNotification>>? inbox,
  Stream<List<BillGroup>>? groups,
  Stream<List<BillGroup>>? groupInvites,
  Stream<List<ConnectionRequest>>? incomingRequests,
  Stream<List<ConnectionRequest>>? outgoingRequests,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        inbox: inbox,
        groups: groups,
        groupInvites: groupInvites,
        incomingRequests: incomingRequests,
        outgoingRequests: outgoingRequests,
      ),
      child: MaterialApp(
        theme: ThemeData(
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        darkTheme: ThemeData(
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    ),
  );
  // Let streams deliver and one frame of animations run.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> loadRoboto() async {
  var root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    // Derive from the flutter_tester binary location:
    // <root>/bin/cache/artifacts/engine/<platform>/flutter_tester
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      dir = dir.parent;
    }
    root = dir.path;
  }
  final fontsDir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final bytes = await File('$fontsDir/Roboto-$weight.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await loadRoboto();
  });

  const sizes = <String, Size>{
    'small phone 320x568': Size(320, 568),
    'phone 360x640': Size(360, 640),
    'phone 390x844': Size(390, 844),
    'large phone 430x932': Size(430, 932),
    'landscape 640x360': Size(640, 360),
    'tablet 1024x768': Size(1024, 768),
  };

  final screens = <String, Widget>{
    'Onboarding': const OnboardingScreen(),
    'SignIn': const SignInScreen(),
    'BillsTab': const BillsTab(),
    'BalancesTab': const BalancesTab(),
    'GroupsTab': const GroupsTab(),
    'FriendsTab': const FriendsTab(),
    'ProfileTab': const ProfileTab(),
    'SettingsScreen': const SettingsScreen(),
    'GroupRequests': const GroupRequestsScreen(),
    'FriendRequests': const FriendRequestsScreen(),
    'Notifications': const NotificationsScreen(),
    'BillDetail': const BillDetailScreen(billId: 'b1'),
    'GroupDetail': const GroupDetailScreen(groupId: 'g1'),
    'CreateBill': const CreateBillScreen(),
    'CreateGroup': const CreateGroupScreen(),
    'HomeShell': const HomeShell(),
  };

  testWidgets(
      'Invites stay with Groups and Friends; Notifications has its own tab',
      (tester) async {
    addTearDown(() => tester.view.reset());
    await pumpAt(tester, const HomeShell(), size: const Size(390, 844));
    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Notifications')),
        findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Requests')),
        findsNothing);
    expect(
        find.descendant(of: nav, matching: find.text('Profile')), findsNothing);
    expect(find.descendant(of: nav, matching: find.text('1')), findsWidgets);
    expect(find.descendant(of: nav, matching: find.text('4')), findsNothing);

    await tester.tap(find.descendant(
        of: find.byType(AppBar), matching: find.byTooltip('Notifications')));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 4);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.descendant(of: nav, matching: find.text('Groups')));
    await tester.pumpAndSettle();
    expect(find.text('My groups'), findsOneWidget);
    final groupInvites = find.byTooltip('Group invitations');
    expect(groupInvites, findsOneWidget);
    expect(find.descendant(of: groupInvites, matching: find.text('2')),
        findsOneWidget);
    await tester.tap(groupInvites);
    await tester.pumpAndSettle();
    expect(find.byType(GroupRequestsScreen), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Incoming (1)'), findsOneWidget);
    expect(find.text('Outgoing (1)'), findsOneWidget);
    expect(find.text('wants to connect with you'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: nav, matching: find.text('Friends')));
    await tester.pumpAndSettle();
    final friendInvites = find.byTooltip('Friend invitations');
    expect(friendInvites, findsOneWidget);
    expect(find.descendant(of: friendInvites, matching: find.text('2')),
        findsOneWidget);
    await tester.tap(friendInvites);
    await tester.pumpAndSettle();
    expect(find.byType(FriendRequestsScreen), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Incoming (1)'), findsOneWidget);
    expect(find.text('Outgoing (1)'), findsOneWidget);
    expect(find.text('wants to connect with you'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester
        .tap(find.descendant(of: nav, matching: find.text('Notifications')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Recent updates'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    splitwizeScaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    final drawerNotifications = find.descendant(
        of: find.byType(Drawer), matching: find.text('Notifications'));
    expect(drawerNotifications, findsOneWidget,
        reason: 'The drawer must have one Notifications destination');
    expect(
        find.descendant(
            of: find.byType(Drawer), matching: find.text('Requests')),
        findsNothing);
    await tester.tap(drawerNotifications);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 4);
    expect(find.byType(BackButton), findsNothing);
    splitwizeScaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    splitwizeScaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(Drawer), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Default currency'), findsOneWidget);
    expect(find.text('Personal details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('Notifications badge tracks unread inbox only at $size',
        (tester) async {
      addTearDown(tester.view.reset);
      final inbox = StreamController<List<AppNotification>>();
      addTearDown(inbox.close);
      await pumpAt(tester, const HomeShell(), size: size, inbox: inbox.stream);
      inbox.add([]);
      await tester.pumpAndSettle();
      final nav = size.width >= 760
          ? find.byType(NavigationRail)
          : find.byType(NavigationBar);
      final navBadges = find.descendant(of: nav, matching: find.byType(Badge));

      void expectVisibleBadge(int unread) {
        final badges = tester
            .widgetList<Badge>(navBadges)
            .where((badge) => badge.isLabelVisible)
            .toList();
        if (unread == 0) {
          expect(badges, isEmpty,
              reason: 'Pending invitations must not create an inbox badge');
        } else {
          expect(badges, isNotEmpty);
          for (final badge in badges) {
            expect((badge.label! as Text).data, '$unread');
          }
        }
      }

      expectVisibleBadge(0);
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Notifications')));
      await tester.pumpAndSettle();
      expect(find.text('All caught up.'), findsOneWidget);

      inbox.add(testNotifications);
      await tester.pumpAndSettle();
      expectVisibleBadge(1);
      expect(find.text('Recent updates'), findsOneWidget);

      inbox.add([
        for (final notification in testNotifications)
          notification.copyWith(read: true),
      ]);
      await tester.pumpAndSettle();
      expectVisibleBadge(0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final isGroup in [true, false]) {
    for (final compact in [false, true]) {
      testWidgets(
          'Invites totals update for ${isGroup ? 'Groups' : 'Friends'} in ${compact ? 'compact' : 'regular'} layout',
          (tester) async {
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final groups = StreamController<List<BillGroup>>.broadcast();
        final groupInvites = StreamController<List<BillGroup>>.broadcast();
        final incomingFriends =
            StreamController<List<ConnectionRequest>>.broadcast();
        final outgoingFriends =
            StreamController<List<ConnectionRequest>>.broadcast();
        addTearDown(groups.close);
        addTearDown(groupInvites.close);
        addTearDown(incomingFriends.close);
        addTearDown(outgoingFriends.close);
        try {
          await pumpAt(
            tester,
            isGroup ? const GroupsTab() : const FriendsTab(),
            size: compact ? const Size(320, 568) : const Size(390, 844),
            textScale: compact ? 2 : 1,
            groups: groups.stream,
            groupInvites: groupInvites.stream,
            incomingRequests: incomingFriends.stream,
            outgoingRequests: outgoingFriends.stream,
          );

          List<ConnectionRequest> requests(int count,
                  {required bool incoming}) =>
              List.generate(
                count,
                (index) => ConnectionRequest(
                  id: '${incoming ? 'in' : 'out'}-$index',
                  fromUid: incoming ? 'friend-$index' : 'me',
                  fromName: incoming ? 'Friend $index' : me.displayName,
                  toUid: incoming ? 'me' : 'friend-$index',
                  toName: incoming ? me.displayName : 'Friend $index',
                  status: 'pending',
                ),
              );

          Future<void> update({
            required int incoming,
            required int outgoing,
            int otherIncoming = 7,
            int otherOutgoing = 8,
          }) async {
            final groupIn = isGroup ? incoming : otherIncoming;
            final groupOut = isGroup ? outgoing : otherOutgoing;
            groupInvites.add(List.generate(
              groupIn,
              (index) => BillGroup(
                id: 'incoming-group-$index',
                name: 'Incoming group $index',
                createdBy: 'f1',
                members: const ['f1'],
                invited: const ['me'],
              ),
            ));
            groups.add([
              testGroup.copyWith(
                invited: List.generate(groupOut, (index) => 'recipient-$index'),
              ),
            ]);
            incomingFriends.add(
                requests(isGroup ? otherIncoming : incoming, incoming: true));
            outgoingFriends.add(
                requests(isGroup ? otherOutgoing : outgoing, incoming: false));
            await tester.pumpAndSettle();
          }

          final tooltip = isGroup ? 'Group invitations' : 'Friend invitations';
          final button = find.byTooltip(tooltip);
          void expectTotal(int total) {
            expect(button.hitTestable(), findsOneWidget);
            final numericLabels = find.descendant(
              of: button,
              matching: find.byWidgetPredicate((widget) =>
                  widget is Text &&
                  RegExp(r'^\d+(?:\+)?$').hasMatch(widget.data ?? '')),
            );
            if (total == 0) {
              expect(numericLabels, findsNothing,
                  reason: 'No counter should remain when nothing is pending');
            } else {
              expect(numericLabels, findsOneWidget);
              expect(tester.widget<Text>(numericLabels).data, '$total',
                  reason: 'Show the exact total for this invitation category');
            }
            final data = tester
                .getSemantics(find.bySemanticsLabel(tooltip))
                .getSemanticsData();
            expect(
                data.value,
                total == 0
                    ? 'No pending invitations'
                    : '$total pending invitations');
            expect(tester.takeException(), isNull);
          }

          await update(incoming: 0, outgoing: 0);
          expectTotal(0);
          await update(incoming: 2, outgoing: 0);
          expectTotal(2);
          await update(incoming: 2, outgoing: 3);
          expectTotal(5);
          await update(
              incoming: 2, outgoing: 3, otherIncoming: 20, otherOutgoing: 30);
          expectTotal(5);
          await update(incoming: 0, outgoing: 3);
          expectTotal(3);
          await update(incoming: 0, outgoing: 101);
          expectTotal(101);
          await update(incoming: 0, outgoing: 0);
          expectTotal(0);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('Balances hides the highlighted introduction', (tester) async {
    addTearDown(() => tester.view.reset());
    await pumpAt(tester, const BalancesTab(), size: const Size(390, 844));
    expect(find.text('SETTLEMENTS'), findsNothing);
    expect(find.text('Keep it balanced.'), findsNothing);
    expect(find.text('A simple view of what you owe and what comes back.'),
        findsNothing);
    expect(find.text('Your totals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notifications opens directly to recent updates', (tester) async {
    addTearDown(() => tester.view.reset());
    await pumpAt(tester, const NotificationsScreen(),
        size: const Size(390, 844));
    expect(find.text('ACTIVITY'), findsNothing);
    expect(find.text('Notifications.'), findsNothing);
    expect(
        find.text('Bills, payments and invites in one place.'), findsNothing);
    expect(find.text('Recent updates'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bill details starts with the summary, without intro banner',
      (tester) async {
    addTearDown(() => tester.view.reset());
    await pumpAt(tester, const BillDetailScreen(billId: 'b1'),
        size: const Size(390, 844));
    expect(find.text('EXPENSE DETAILS'), findsNothing);
    expect(find.text('Review each person’s share and payment progress.'),
        findsNothing);
    // Preserve the bill summary and payment breakdown.
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Bill details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home focuses on expenses and FAB without duplicate balances',
      (tester) async {
    addTearDown(() => tester.view.reset());
    await pumpAt(tester, const BillsTab(), size: const Size(390, 844));
    expect(find.text('YOUR SPACE'), findsNothing);
    expect(find.text('Your money, together.'), findsNothing);
    expect(find.text('Keep shared expenses clear and easy to settle.'),
        findsNothing);
    expect(find.text('Quick actions'), findsNothing);
    expect(find.text('New group'), findsNothing);
    expect(find.text('AT A GLANCE'), findsNothing);
    expect(find.text('Your balances'), findsNothing);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.text('Unsettled (1)'), findsOneWidget);
    expect(find.text('Settled (0)'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(640, 360), const Size(320, 568)]) {
    testWidgets('open drawer fits $size at 2x text', (tester) async {
      addTearDown(() => tester.view.reset());
      await pumpAt(tester, const HomeShell(), size: size, textScale: 2);
      splitwizeScaffoldKey.currentState!.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final drawerScroll = find.descendant(
          of: find.byType(Drawer), matching: find.byType(Scrollable));
      for (final label in ['Settings', 'Notifications', 'Log out']) {
        final item = find.descendant(
            of: find.byType(Drawer), matching: find.text(label));
        await tester.scrollUntilVisible(item, 100, scrollable: drawerScroll);
        await tester.pump(const Duration(milliseconds: 400));
        expect(item.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final screen in screens.entries) {
    for (final size in sizes.entries) {
      testWidgets('${screen.key} fits ${size.key}', (tester) async {
        addTearDown(() => tester.view.reset());
        await pumpAt(tester, screen.value, size: size.value);
        expect(tester.takeException(), isNull,
            reason: '${screen.key} at ${size.key} threw (likely an overflow)');
      });
    }

    testWidgets('${screen.key} fits 360x640 at 1.6x text', (tester) async {
      addTearDown(() => tester.view.reset());
      await pumpAt(tester, screen.value,
          size: const Size(360, 640), textScale: 1.6);
      expect(tester.takeException(), isNull,
          reason: '${screen.key} at 1.6x text threw (likely an overflow)');
    });
  }

  // The tightest combination: smallest phone + biggest text.
  for (final name in [
    'Onboarding',
    'FriendsTab',
    'BalancesTab',
    'BillsTab',
    'GroupDetail'
  ]) {
    testWidgets('$name fits 320x568 at 2.0x text', (tester) async {
      addTearDown(() => tester.view.reset());
      await pumpAt(tester, screens[name]!,
          size: const Size(320, 568), textScale: 2.0);
      expect(tester.takeException(), isNull,
          reason: '$name at 320x568 / 2.0x text threw');
    });
  }
}
