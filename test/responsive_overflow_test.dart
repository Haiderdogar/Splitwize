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
import 'package:splitwize/screens/sign_in_screen.dart';
import 'package:splitwize/services/sync_service.dart';

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

List<Override> testOverrides() => [
      currentUidProvider.overrideWith((ref) => 'me'),
      myBillsProvider.overrideWith((ref) => Stream.value([testBill])),
      balancesProvider.overrideWith((ref) => testBalances),
      myGroupsProvider.overrideWith((ref) => Stream.value([testGroup])),
      groupInvitesProvider.overrideWith((ref) => Stream.value([testGroup])),
      connectionsProvider
          .overrideWith((ref) => Stream.value([longNameFriend, friend2])),
      incomingRequestsProvider
          .overrideWith((ref) => Stream.value(testIncoming)),
      outgoingRequestsProvider
          .overrideWith((ref) => Stream.value(testOutgoing)),
      notificationsProvider
          .overrideWith((ref) => Stream.value(testNotifications)),
      currentAppUserProvider.overrideWith((ref) => Stream.value(me)),
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(),
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
    'Notifications': const NotificationsScreen(),
    'BillDetail': const BillDetailScreen(billId: 'b1'),
    'GroupDetail': const GroupDetailScreen(groupId: 'g1'),
    'CreateBill': const CreateBillScreen(),
    'CreateGroup': const CreateGroupScreen(),
    'HomeShell': const HomeShell(),
  };

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
