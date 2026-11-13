import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/screens/create_bill_screen.dart';
import 'package:splitwize/screens/group_detail_screen.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/utils/money.dart';

const _me = AppUser(
  uid: 'me',
  displayName: 'Ali Haider',
  email: 'ali@example.com',
  currency: 'PKR',
);
const _friend = AppUser(
  uid: 'hamza',
  displayName: 'Hamza Malik',
  email: 'hamza@example.com',
);
const _invited = AppUser(
  uid: 'zainab',
  displayName: 'Zainab Qureshi',
  email: 'zainab@example.com',
);
const _group = BillGroup(
  id: 'weekend',
  name: 'Weekend in the mountains',
  createdBy: 'me',
  members: ['me', 'hamza'],
  invited: ['zainab'],
  currency: 'PKR',
);

// The creator did not pay this bill. The header must use the payment
// ledger's creditor/debtor, including the already settled portion.
final _dinner = Bill(
  id: 'dinner',
  title: 'Friday dinner',
  subtotal: 100,
  tipPercent: 0,
  total: 100,
  splitType: 'equal',
  createdBy: 'me',
  createdByName: _me.displayName,
  groupId: _group.id,
  participantIds: const ['me', 'hamza'],
  splits: const [
    BillSplit(uid: 'me', displayName: 'Ali Haider', amount: 50),
    BillSplit(uid: 'hamza', displayName: 'Hamza Malik', amount: 50),
  ],
  merchantPayments: const {'hamza': 100},
  paymentDebts: const [
    BillDebt(
      id: 'dinner-debt',
      debtorUid: 'me',
      debtorName: 'Ali Haider',
      creditorUid: 'hamza',
      creditorName: 'Hamza Malik',
      amount: 50,
      settledAmount: 20,
    ),
  ],
  createdAt: DateTime(2026, 11, 13),
  currency: 'PKR',
);

final _tickets = Bill(
  id: 'tickets',
  title: 'Museum tickets',
  subtotal: 20,
  tipPercent: 0,
  total: 20,
  splitType: 'equal',
  createdBy: 'hamza',
  createdByName: _friend.displayName,
  groupId: _group.id,
  participantIds: const ['me', 'hamza'],
  splits: const [
    BillSplit(uid: 'me', displayName: 'Ali Haider', amount: 10),
    BillSplit(uid: 'hamza', displayName: 'Hamza Malik', amount: 10),
  ],
  merchantPayments: const {'me': 20},
  paymentDebts: const [
    BillDebt(
      id: 'tickets-debt',
      debtorUid: 'hamza',
      debtorName: 'Hamza Malik',
      creditorUid: 'me',
      creditorName: 'Ali Haider',
      amount: 10,
    ),
  ],
  createdAt: DateTime(2026, 11, 12),
  currency: 'USD',
);

final _coffee = Bill(
  id: 'coffee',
  title: 'Morning coffee',
  subtotal: 10,
  tipPercent: 0,
  total: 10,
  splitType: 'equal',
  createdBy: 'me',
  createdByName: _me.displayName,
  groupId: _group.id,
  participantIds: const ['me', 'hamza'],
  splits: const [
    BillSplit(uid: 'me', displayName: 'Ali Haider', amount: 5, paid: true),
    BillSplit(uid: 'hamza', displayName: 'Hamza Malik', amount: 5, paid: true),
  ],
  merchantPayments: const {'me': 10},
  paymentDebts: const [
    BillDebt(
      id: 'coffee-debt',
      debtorUid: 'hamza',
      debtorName: 'Hamza Malik',
      creditorUid: 'me',
      creditorName: 'Ali Haider',
      amount: 5,
      settledAmount: 5,
    ),
  ],
  createdAt: DateTime(2026, 11, 11),
  currency: 'USD',
);

Future<void> _loadRoboto() async {
  var root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    var directory = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      directory = directory.parent;
    }
    root = directory.path;
  }
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final bytes = await File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
    ).readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _pumpGroup(
  WidgetTester tester, {
  BillGroup group = _group,
  List<Bill>? bills,
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeMode mode = ThemeMode.light,
  void Function()? onBillsRead,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final entries = bills ?? [_dinner, _tickets, _coffee];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => _me.uid),
      currentAppUserProvider.overrideWith((ref) => Stream.value(_me)),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      groupProvider.overrideWith((ref, id) => Stream.value(group)),
      groupBillsProvider.overrideWith((ref, id) {
        onBillsRead?.call();
        return Stream.value(entries);
      }),
      groupMembersProvider.overrideWith((ref, id) async => [_me, _friend]),
      invitedUsersProvider.overrideWith((ref, id) async => [_invited]),
      connectionsProvider.overrideWith((ref) => Stream.value([_friend])),
      myGroupsProvider.overrideWith((ref) => Stream.value([group])),
      createBillMembersProvider.overrideWith((ref) async => [_me, _friend]),
    ],
    child: MaterialApp(
      theme: splitwizeLightTheme.copyWith(
        textTheme: splitwizeLightTheme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      darkTheme: splitwizeDarkTheme.copyWith(
        textTheme: splitwizeDarkTheme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: GroupDetailScreen(groupId: group.id),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  // Fail immediately on layout errors rather than repeatedly pumping a
  // broken animated frame until pumpAndSettle's long default timeout.
  expect(tester.takeException(), isNull);
  await tester.pumpAndSettle();
}

Finder _filter(String label) => find.byWidgetPredicate((widget) {
      if (widget is! ChoiceChip || widget.label is! Text) return false;
      final text = (widget.label as Text).data ?? '';
      return text == label || text.startsWith('$label (');
    });

Future<void> _selectTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  // Collapse the overview first, as a user does before working in a tab.
  // The header can fill an entire small viewport with enlarged text.
  final nested =
      tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
  nested.outerController
      .jumpTo(nested.outerController.position.maxScrollExtent);
  await tester.pumpAndSettle();
  await tester.ensureVisible(tab);
  nested.outerController
      .jumpTo(nested.outerController.position.maxScrollExtent);
  await tester.pumpAndSettle();
  expect(tab.hitTestable(), findsOneWidget);
  await tester.tap(tab);
  await tester.pumpAndSettle();
  final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
  expect(controller.index, ['Expenses', 'Balances', 'Members'].indexOf(label));
}

void main() {
  setUpAll(_loadRoboto);

  testWidgets(
      'overview keeps currencies and the actual payer balances separate',
      (tester) async {
    await _pumpGroup(tester);
    String textAt(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(textAt('group-spending-PKR'), formatMoney(100, 'PKR'));
    expect(textAt('group-spending-USD'), formatMoney(30, 'USD'));
    expect(
        textAt('group-balance-PKR'), 'You owe ${formatMoney(30, 'PKR')} · PKR');
    expect(textAt('group-balance-USD'),
        'You are owed ${formatMoney(10, 'USD')} · USD');
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview also respects partially settled legacy shares',
      (tester) async {
    await _pumpGroup(tester, bills: const [
      Bill(
        id: 'legacy',
        title: 'Legacy hotel bill',
        subtotal: 100,
        tipPercent: 0,
        total: 100,
        splitType: 'equal',
        createdBy: 'hamza',
        createdByName: 'Hamza Malik',
        groupId: 'weekend',
        participantIds: ['me', 'hamza'],
        splits: [
          BillSplit(
            uid: 'me',
            displayName: 'Ali Haider',
            amount: 50,
            paidAmount: 20,
          ),
          BillSplit(uid: 'hamza', displayName: 'Hamza Malik', amount: 50),
        ],
        currency: 'PKR',
      ),
    ]);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('group-balance-PKR'))).data,
      'You owe ${formatMoney(30, 'PKR')} · PKR',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense filters separate unsettled and settled bills',
      (tester) async {
    await _pumpGroup(tester);
    await tester.ensureVisible(_filter('Unsettled'));
    await tester.tap(_filter('Unsettled'));
    await tester.pumpAndSettle();
    expect(find.text('Friday dinner'), findsOneWidget);
    expect(find.text('Museum tickets'), findsOneWidget);
    expect(find.text('Morning coffee'), findsNothing);

    await tester.tap(_filter('Settled'));
    await tester.pumpAndSettle();
    expect(find.text('Morning coffee'), findsOneWidget);
    expect(find.text('Friday dinner'), findsNothing);
    expect(find.text('Museum tickets'), findsNothing);
    expect(find.text('Add expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('members and balances are reachable from their tabs',
      (tester) async {
    await _pumpGroup(tester);
    await _selectTab(tester, 'Members');
    expect(
      tester.getTopLeft(find.text('The people in your group')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TabBar)).dy),
      reason: 'The pinned tabs must not cover the members heading.',
    );
    expect(find.textContaining(_friend.displayName), findsWidgets);
    expect(find.textContaining(_invited.displayName), findsWidgets);
    expect(find.text('Invite friends'), findsOneWidget);

    await _selectTab(tester, 'Balances');
    expect(
      tester.getTopLeft(find.text('Settle up')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TabBar)).dy),
      reason: 'The pinned tabs must not cover the balances heading.',
    );
    final settle = find.widgetWithText(FilledButton, 'Mark settled');
    expect(settle, findsNWidgets(2));
    await tester.ensureVisible(settle.first);
    await tester.tap(settle.first);
    // Allow the dialog's entrance animation to complete before inspecting it.
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Record settlement?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Record settlement?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense filter survives visits to the other tabs',
      (tester) async {
    await _pumpGroup(tester);
    await _selectTab(tester, 'Expenses');
    await tester.tap(_filter('Settled'));
    await tester.pumpAndSettle();
    expect(find.text('Morning coffee'), findsOneWidget);
    expect(find.text('Friday dinner'), findsNothing);

    await _selectTab(tester, 'Members');
    await _selectTab(tester, 'Balances');
    await _selectTab(tester, 'Expenses');
    expect(tester.widget<ChoiceChip>(_filter('Settled')).selected, isTrue);
    expect(find.text('Morning coffee'), findsOneWidget);
    expect(find.text('Friday dinner'), findsNothing);
    expect(find.text('Museum tickets'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings explains currency and opens the searchable picker',
      (tester) async {
    await _pumpGroup(tester);
    await tester.tap(find.byTooltip('Group settings'));
    await tester.pumpAndSettle();
    expect(find.text('Group settings'), findsOneWidget);
    expect(
      find.text('The group currency is used for new expenses. '
          'Existing expenses keep their original currency.'),
      findsOneWidget,
    );
    final currencyButton = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextButton),
    );
    expect(currencyButton, findsOneWidget);
    await tester.tap(currencyButton);
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    expect(search, findsOneWidget);
    await tester.enterText(search, 'JPY');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is Text && widget.data == 'JPY'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('add expense opens the form with this group selected',
      (tester) async {
    await _pumpGroup(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    final form = tester.widget<CreateBillScreen>(find.byType(CreateBillScreen));
    expect(form.initialGroupId, _group.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a routed payment stays read-only for a nonparticipant bill',
      (tester) async {
    // The suggested route me -> Hamza -> Zainab involves me, but the
    // second bill belongs to Hamza and Zainab. Group membership alone
    // must not grant permission to record changes to that second bill.
    await _pumpGroup(tester, bills: [
      _dinner,
      const Bill(
        id: 'taxi',
        title: 'Taxi to the hotel',
        subtotal: 60,
        tipPercent: 0,
        total: 60,
        splitType: 'equal',
        createdBy: 'hamza',
        createdByName: 'Hamza Malik',
        groupId: 'weekend',
        participantIds: ['hamza', 'zainab'],
        splits: [
          BillSplit(uid: 'hamza', displayName: 'Hamza Malik', amount: 30),
          BillSplit(uid: 'zainab', displayName: 'Zainab Qureshi', amount: 30),
        ],
        merchantPayments: {'zainab': 60},
        paymentDebts: [
          BillDebt(
            id: 'taxi-debt',
            debtorUid: 'hamza',
            debtorName: 'Hamza Malik',
            creditorUid: 'zainab',
            creditorName: 'Zainab Qureshi',
            amount: 30,
          ),
        ],
        currency: 'PKR',
      ),
    ]);
    await _selectTab(tester, 'Balances');
    expect(find.widgetWithText(FilledButton, 'Mark settled'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonmembers never subscribe to group bills or see settings',
      (tester) async {
    var billsRead = 0;
    await _pumpGroup(
      tester,
      group: const BillGroup(
        id: 'private',
        name: 'Private group',
        createdBy: 'hamza',
        members: ['hamza'],
        invited: [],
      ),
      onBillsRead: () => billsRead++,
    );
    expect(billsRead, 0);
    expect(find.text('Group currency'), findsNothing);
    expect(find.text('Add expense'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Join this group to view its details.'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('all tabs fit a small phone with enlarged text in $mode',
        (tester) async {
      await _pumpGroup(
        tester,
        size: const Size(320, 568),
        textScale: 1.4,
        mode: mode,
      );
      expect(tester.takeException(), isNull);
      for (final tab in ['Balances', 'Members', 'Expenses']) {
        await _selectTab(tester, tab);
        await tester.drag(
          find.byType(TabBarView),
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab in $mode');
        expect(find.text('Add expense').hitTestable(), findsOneWidget);
      }
    });
  }
}
