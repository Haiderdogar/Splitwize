import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/screens/friends_tab.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/utils/money.dart';
import 'package:splitwize/widgets/money_text.dart';

import 'fake_sync_service.dart';

const _friendA =
    AppUser(uid: 'fa', displayName: 'Friend A', email: 'a@example.com');
const _friendB =
    AppUser(uid: 'fb', displayName: 'Friend B', email: 'b@example.com');

// Friend A is owed in PKR and owes in USD; Group Member is not a friend.
const _balances = [
  FriendBalance(
      uid: 'fa',
      displayName: 'Friend A',
      currency: 'PKR',
      net: 500,
      owesMe: 500,
      iOweThem: 0,
      openBills: 1),
  FriendBalance(
      uid: 'fa',
      displayName: 'Friend A',
      currency: 'USD',
      net: -40,
      owesMe: 0,
      iOweThem: 40,
      openBills: 1),
  FriendBalance(
      uid: 'gx',
      displayName: 'Group Member',
      currency: 'PKR',
      net: -100,
      owesMe: 0,
      iOweThem: 100,
      openBills: 1),
];

Future<void> _pump(WidgetTester tester, List<AppUser> friends,
    List<FriendBalance> balances) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => 'me'),
      syncServiceProvider.overrideWith((ref) async => FakeSyncService()),
      connectionsProvider.overrideWith((ref) => Stream.value(friends)),
      incomingRequestsProvider
          .overrideWith((ref) => Stream.value(const <ConnectionRequest>[])),
      outgoingRequestsProvider
          .overrideWith((ref) => Stream.value(const <ConnectionRequest>[])),
      balancesProvider.overrideWith((ref) => balances),
      unreadCountProvider.overrideWith((ref) => 0),
    ],
    child: MaterialApp(theme: splitwizeLightTheme, home: const FriendsTab()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('friends show what they owe or are owed, one currency at a time',
      (tester) async {
    await _pump(tester, const [_friendA, _friendB], _balances);

    // Per-currency totals above the list; PKR and USD are never combined.
    Finder total(String currency, double value) => find.descendant(
        of: find.byKey(ValueKey('balance-totals-$currency')),
        matching: find.byWidgetPredicate((widget) =>
            widget is MoneyText &&
            widget.currencyCode == currency &&
            widget.value == value));
    expect(total('PKR', 500), findsOneWidget);
    expect(total('PKR', 100), findsOneWidget);
    expect(total('USD', 0), findsOneWidget);
    expect(total('USD', 40), findsOneWidget);

    expect(find.text('Owes you ${formatMoney(500, 'PKR')}'), findsOneWidget);
    expect(find.text('You owe ${formatMoney(40, 'USD')}'), findsOneWidget);
    expect(find.text('You owe ${formatMoney(100, 'PKR')}'), findsOneWidget);
    // Friends without a balance keep showing their email.
    expect(find.text('b@example.com'), findsOneWidget);
    expect(find.text('a@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('people with a balance come first and non-friends stay visible',
      (tester) async {
    await _pump(tester, const [_friendB, _friendA], _balances);
    final a = tester.getTopLeft(find.text('Friend A')).dy;
    final member = tester.getTopLeft(find.text('Group Member')).dy;
    final b = tester.getTopLeft(find.text('Friend B')).dy;
    expect(a, lessThan(member));
    expect(member, lessThan(b));
    // Only real friends can be removed.
    expect(find.byTooltip('Friend options'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('repayment is offered per currency and asks before recording',
      (tester) async {
    await _pump(tester, const [_friendA], _balances);
    // Friend A has two currencies, so the button names the one it settles.
    expect(find.text('Record repayment (USD)'), findsOneWidget);
    expect(find.text('Record repayment (PKR)'), findsNothing);
    // Group Member has a single currency, so the plain label is enough.
    expect(find.text('Record repayment'), findsOneWidget);
    await tester.tap(find.text('Record repayment (USD)'));
    await tester.pumpAndSettle();
    expect(find.text('Record repayment?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Record repayment?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with nothing outstanding the list shows friends only',
      (tester) async {
    await _pump(tester, const [_friendA, _friendB], const []);
    expect(find.text('Owed to you'), findsNothing);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.textContaining('Record repayment'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
