import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/screens/bills_tab.dart';
import 'package:splitwize/screens/create_bill_screen.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/widgets/bill_list_tile.dart';
import 'package:splitwize/widgets/money_text.dart';

import 'responsive_overflow_test.dart' as fixture;

class _AdFree extends AdFreeStatus {
  @override
  Future<bool> build() async => true;
}

Bill _bill(
  String id,
  String title, {
  DateTime? date,
  String? group,
  bool settled = false,
}) =>
    Bill(
      id: id,
      title: title,
      subtotal: 200,
      tipPercent: 0,
      total: 200,
      splitType: 'equal',
      createdBy: 'me',
      createdByName: fixture.me.displayName,
      groupName: group,
      participantIds: const ['me', 'f2'],
      splits: [
        const BillSplit(
          uid: 'me',
          displayName: 'Ali Haider',
          amount: 100,
          paid: true,
        ),
        BillSplit(
          uid: 'f2',
          displayName: 'Hamza Malik',
          amount: 100,
          paid: settled,
        ),
      ],
      createdAt: date,
      currency: 'PKR',
    );

Future<void> _pumpHome(
  WidgetTester tester,
  List<Bill> bills, {
  List<FriendBalance> balances = const [],
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => 'me'),
      currentAppUserProvider.overrideWith((ref) => Stream.value(fixture.me)),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      myBillsProvider.overrideWith((ref) => Stream.value(bills)),
      balancesProvider.overrideWith((ref) => balances),
      notificationsProvider
          .overrideWith((ref) => Stream.value(<AppNotification>[])),
      adFreeStatusProvider.overrideWith(_AdFree.new),
      myGroupsProvider.overrideWith((ref) => Stream.value(<BillGroup>[])),
      connectionsProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
      createBillMembersProvider
          .overrideWith((ref) async => [fixture.me, fixture.friend2]),
    ],
    child: MaterialApp(
      theme: splitwizeLightTheme,
      home: const BillsTab(),
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

List<String> _visibleIds(WidgetTester tester) => tester
    .widgetList<BillListTile>(find.byType(BillListTile))
    .map((tile) => tile.bill.id)
    .toList();

Future<void> _selectFilter(WidgetTester tester, String label) async {
  final filter = find.text(label);
  await tester.ensureVisible(filter);
  await tester.tap(filter);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(fixture.loadRoboto);

  testWidgets('search and status filters work together and clear independently',
      (tester) async {
    await _pumpHome(tester, [
      _bill('dinner', 'Dinner with friends',
          date: DateTime(2026, 11, 12), group: 'Weekend trip'),
      _bill('taxi', 'Airport taxi',
          date: DateTime(2026, 11, 10), group: 'Weekend trip', settled: true),
      _bill('coffee', 'Coffee catch-up', date: DateTime(2026, 11, 9)),
    ]);
    await tester.tap(find.byTooltip('Search expenses'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'WEEKEND');
    await tester.pumpAndSettle();
    expect(_visibleIds(tester), ['dinner', 'taxi']);

    await _selectFilter(tester, 'Settled (1)');
    expect(_visibleIds(tester), ['taxi']);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(_visibleIds(tester), ['taxi']);

    await _selectFilter(tester, 'All (3)');
    await tester.enterText(find.byType(TextField), 'dinner');
    await tester.pumpAndSettle();
    expect(_visibleIds(tester), ['dinner']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date sorting keeps undated expenses last in both directions',
      (tester) async {
    await _pumpHome(tester, [
      _bill('undated', 'Undated receipt'),
      _bill('older', 'Airport taxi', date: DateTime(2026, 10, 30)),
      _bill('newer', 'Dinner with friends', date: DateTime(2026, 11, 12)),
    ]);
    expect(_visibleIds(tester), ['newer', 'older', 'undated']);

    await tester.tap(find.byTooltip('Sort expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first').last);
    await tester.pumpAndSettle();
    expect(_visibleIds(tester), ['older', 'newer', 'undated']);

    await tester.tap(find.byTooltip('Sort expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Newest first').last);
    await tester.pumpAndSettle();
    expect(_visibleIds(tester), ['newer', 'older', 'undated']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty status filter offers a working reset', (tester) async {
    await _pumpHome(tester, [
      _bill('dinner', 'Dinner with friends', date: DateTime(2026, 11, 12)),
    ]);
    await _selectFilter(tester, 'Settled (0)');
    expect(find.byType(BillListTile), findsNothing);
    await tester.tap(find.text('Show all expenses'));
    await tester.pumpAndSettle();
    expect(_visibleIds(tester), ['dinner']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home totals keep every currency separate', (tester) async {
    await _pumpHome(tester, [
      _bill('dinner', 'Dinner with friends', date: DateTime(2026, 11, 12)),
    ], balances: const [
      FriendBalance(
          uid: 'f2',
          displayName: 'Hamza Malik',
          currency: 'PKR',
          net: 1000,
          owesMe: 1000,
          iOweThem: 0,
          openBills: 1),
      FriendBalance(
          uid: 'f3',
          displayName: 'Sara Khan',
          currency: 'PKR',
          net: 300,
          owesMe: 500,
          iOweThem: 200,
          openBills: 2),
      FriendBalance(
          uid: 'f2',
          displayName: 'Hamza Malik',
          currency: 'USD',
          net: -40,
          owesMe: 0,
          iOweThem: 40,
          openBills: 1),
    ]);

    Finder amount(String currency, double value) => find.descendant(
        of: find.byKey(ValueKey('balance-totals-$currency')),
        matching: find.byWidgetPredicate((widget) =>
            widget is MoneyText &&
            widget.currencyCode == currency &&
            widget.value == value));

    expect(find.byKey(const ValueKey('balance-totals-PKR')), findsOneWidget);
    expect(find.byKey(const ValueKey('balance-totals-USD')), findsOneWidget);
    // PKR sums only PKR balances, USD only USD, with no conversion between.
    expect(amount('PKR', 1500), findsOneWidget);
    expect(amount('PKR', 200), findsOneWidget);
    expect(amount('USD', 0), findsOneWidget);
    expect(amount('USD', 40), findsOneWidget);
    expect(find.text('Owed to you'), findsNWidgets(2));
    expect(find.text('You owe'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows no totals when nothing is outstanding',
      (tester) async {
    await _pumpHome(tester, [
      _bill('dinner', 'Dinner with friends',
          date: DateTime(2026, 11, 12), settled: true),
    ]);
    expect(find.text('Owed to you'), findsNothing);
    expect(find.text('You owe'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense opens the existing expense form', (tester) async {
    await _pumpHome(tester, []);
    await tester.tap(find.byTooltip('Add expense'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateBillScreen), findsOneWidget);
    expect(find.text('New expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
