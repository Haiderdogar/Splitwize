import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/screens/balances_tab.dart';
import 'package:splitwize/screens/bill_detail_screen.dart';
import 'package:splitwize/screens/person_bills_screen.dart';
import 'package:splitwize/screens/notifications_screen.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/utils/person_bills.dart';
import 'package:splitwize/widgets/state_widgets.dart';

Bill sampleBill(
  String id, {
  List<String> people = const ['me', 'friend'],
  String creator = 'me',
  String currency = 'USD',
  bool paid = false,
  bool deleted = false,
  int day = 1,
  Map<String, double> payments = const {},
  List<BillDebt> debts = const [],
}) =>
    Bill(
      id: id,
      title: id,
      subtotal: 100,
      tipPercent: 0,
      total: 100,
      splitType: 'equal',
      createdBy: creator,
      createdByName: creator,
      participantIds: people,
      splits: [
        for (final uid in people)
          BillSplit(uid: uid, displayName: uid, amount: 50, paid: paid)
      ],
      merchantPayments: payments,
      paymentDebts: debts,
      currency: currency,
      deleted: deleted,
      createdAt: DateTime(2026, 11, day),
    );

const balance = FriendBalance(
  uid: 'friend',
  displayName: 'Hamza Malik',
  currency: 'USD',
  net: -50,
  owesMe: 0,
  iOweThem: 50,
  openBills: 1,
);

final fixtures = [
  sampleBill('Dinner', creator: 'friend', day: 3),
  sampleBill('Settled lunch', paid: true, currency: 'PKR', day: 2),
  sampleBill('Other friend', people: ['me', 'other']),
  sampleBill('Deleted bill', deleted: true),
];

class _ReminderRepository extends Fake implements AppRepository {
  final calls = <({String personUid, String? billId})>[];
  final billCalls = <String>[];
  Future<int> Function()? result;
  final readNotifications = <String>[];

  @override
  Future<void> markNotificationRead(String id) async =>
      readNotifications.add(id);

  @override
  Future<int> sendPaymentReminder({required String personUid, String? billId}) {
    calls.add((personUid: personUid, billId: billId));
    return result?.call() ?? Future.value(1);
  }

  @override
  Future<int> sendBillReminders(String billId) {
    billCalls.add(billId);
    return result?.call() ?? Future.value(1);
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Stream<List<Bill>>? bills,
  ThemeData? theme,
  double textScale = 1,
  AppRepository? repository,
  List<FriendBalance>? balances,
  List<AppNotification> inbox = const [],
  Stream<Bill?>? detail,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => 'me'),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
      unreadCountProvider.overrideWith((ref) => 0),
      notificationsProvider.overrideWith((ref) => Stream.value(inbox)),
      myBillsProvider.overrideWith((ref) => bills ?? Stream.value(fixtures)),
      balancesProvider.overrideWith((ref) => balances ?? [balance]),
      if (repository != null)
        appRepositoryProvider.overrideWith((ref) async => repository),
      billProvider.overrideWith((ref, id) =>
          detail ?? Stream.value(fixtures.firstWhere((bill) => bill.id == id))),
    ],
    child: MaterialApp(
      theme: theme ?? splitwizeLightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: screen,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  test('shared history includes all currencies and settlements, newest first',
      () {
    final bills = [
      ...fixtures,
      sampleBill('Third-party recorder', creator: 'other', day: 4),
      sampleBill('Friend recorder without share',
          creator: 'friend', people: ['me'], day: 5),
      sampleBill('Someone else only', creator: 'other', people: ['friend']),
    ];
    expect(billsWithPerson(bills, 'me', 'friend').map((bill) => bill.id), [
      'Friend recorder without share',
      'Third-party recorder',
      'Dinner',
      'Settled lunch',
    ]);
    expect(bills.first.id, 'Dinner', reason: 'Do not sort the source in place');
    expect(billsWithPerson(bills, '', 'friend'), isEmpty);
    expect(billsWithPerson(bills, 'me', 'me'), isEmpty);
  });

  test(
      'payment ledger and legacy shares identify people without participant IDs',
      () {
    final ledger =
        sampleBill('Ledger', creator: 'other', people: [], payments: {
      'friend': 100
    }, debts: const [
      BillDebt(
        id: 'debt',
        debtorUid: 'me',
        debtorName: 'Me',
        creditorUid: 'friend',
        creditorName: 'Hamza',
        amount: 50,
      )
    ]);
    final legacy = Bill.fromMap('Legacy', {
      'createdBy': 'friend',
      'splits': [
        {'uid': 'me', 'displayName': 'Me', 'amount': 50}
      ],
    });
    expect(billsWithPerson([ledger, legacy], 'me', 'friend'), [ledger, legacy]);
  });

  testWidgets('person count opens shared history, then bill details and back',
      (tester) async {
    await pumpScreen(tester, const BalancesTab());
    expect(find.text('2 shared bills'), findsOneWidget);
    expect(find.text('1 open in USD'), findsOneWidget);
    await tester.tap(find.text('Hamza Malik'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonBillsScreen), findsOneWidget);
    expect(find.text('2 bills with Hamza Malik'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Settled lunch'), findsNothing);
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Unsettled (1)'))
            .selected,
        isTrue);
    expect(find.text('Other friend'), findsNothing);
    expect(find.text('Deleted bill'), findsNothing);

    expect(find.text('Settled (1)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Settled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Settled lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unsettled (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.byType(BillDetailScreen), findsOneWidget);
    expect(find.text('Bill details'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Shared bills'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Unsettled (1)'))
            .selected,
        isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Balances'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repayment button retains its action inside the tappable card',
      (tester) async {
    await pumpScreen(tester, const BalancesTab());
    await tester.tap(find.text('Record repayment'));
    await tester.pumpAndSettle();
    expect(find.text('Record repayment?'), findsOneWidget);
    expect(find.byType(PersonBillsScreen), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Balances'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Balances no longer shows a reminder for money owed to you',
      (tester) async {
    await pumpScreen(tester, const BalancesTab(), balances: const [
      FriendBalance(
          uid: 'friend',
          displayName: 'Hamza Malik',
          currency: 'USD',
          net: 50,
          owesMe: 50,
          iOweThem: 0,
          openBills: 1),
    ]);
    expect(find.text('Hamza Malik'), findsOneWidget);
    expect(find.text('Remind'), findsNothing);
    expect(find.text('Remind all'), findsNothing);
  });

  testWidgets('combined reminders in the app bar block duplicate presses',
      (tester) async {
    final repo = _ReminderRepository();
    final pending = Completer<int>();
    repo.result = () => pending.future;
    await pumpScreen(tester,
        const PersonBillsScreen(personUid: 'friend', personName: 'Hamza Malik'),
        bills: Stream.value([
          sampleBill('Collect dinner'),
          sampleBill('Their dinner', creator: 'friend'),
          sampleBill('Paid lunch', paid: true),
        ]),
        repository: repo);
    expect(find.text('Remind'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(AppBar),
            matching: find.widgetWithText(TextButton, 'Remind all')),
        findsOneWidget);
    await tester.tap(find.text('Remind all'));
    await tester.pump();
    expect(repo.calls, [(personUid: 'friend', billId: null)]);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Remind all'))
            .onPressed,
        isNull);
    expect(find.byType(BillDetailScreen), findsNothing);
    pending.complete(1);
    await tester.pumpAndSettle();
    expect(
        find.text('Reminder queued for Hamza Malik (1 bill).'), findsOneWidget);
    repo.result = null;
    await tester.tap(find.text('Remind all'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, (personUid: 'friend', billId: null));
    expect(repo.calls.length, 2);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Settled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Remind all'), findsNothing);
    expect(find.text('Remind'), findsNothing);
  });

  testWidgets('Remind is in the bill details app bar and sends once while busy',
      (tester) async {
    final repo = _ReminderRepository();
    final pending = Completer<int>();
    repo.result = () => pending.future;
    await pumpScreen(tester, const BillDetailScreen(billId: 'Collect dinner'),
        detail: Stream.value(sampleBill('Collect dinner')), repository: repo);
    final action = find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithText(TextButton, 'Remind'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(repo.billCalls, ['Collect dinner']);
    expect(repo.calls, isEmpty);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Sending...'))
            .onPressed,
        isNull);
    pending.complete(2);
    await tester.pumpAndSettle();
    expect(find.text('Reminders queued for 2 unpaid people.'), findsOneWidget);
    expect(action, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bill details hides Remind once all people are paid',
      (tester) async {
    final stream = StreamController<Bill?>();
    addTearDown(stream.close);
    await pumpScreen(tester, const BillDetailScreen(billId: 'Collect dinner'),
        detail: stream.stream);
    expect(find.text('Remind'), findsNothing);
    stream.add(sampleBill('Collect dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Remind'), findsOneWidget);
    stream.add(sampleBill('Collect dinner', paid: true));
    await tester.pumpAndSettle();
    expect(find.text('Remind'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed bill reminder shows an error and allows retry',
      (tester) async {
    final repo = _ReminderRepository()
      ..result = () => Future.error(StateError('disk unavailable'));
    await pumpScreen(tester, const BillDetailScreen(billId: 'Collect dinner'),
        detail: Stream.value(sampleBill('Collect dinner')), repository: repo);
    await tester.tap(find.text('Remind'));
    await tester.pumpAndSettle();
    expect(find.text('Could not queue reminders. Please try again.'),
        findsOneWidget);
    repo.result = null;
    await tester.tap(find.text('Remind'));
    await tester.pumpAndSettle();
    expect(repo.billCalls.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed reminders show an error and allow retry', (tester) async {
    final repo = _ReminderRepository()
      ..result = () => Future.error(StateError('disk unavailable'));
    await pumpScreen(tester,
        const PersonBillsScreen(personUid: 'friend', personName: 'Hamza Malik'),
        bills: Stream.value([sampleBill('Collect dinner')]), repository: repo);
    await tester.tap(find.text('Remind all'));
    await tester.pumpAndSettle();
    expect(find.text('Could not queue reminder. Please try again.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Remind all'))
            .onPressed,
        isNotNull);
    repo.result = null;
    await tester.tap(find.text('Remind all'));
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('individual reminder in inbox opens its bill and marks it read',
      (tester) async {
    final repo = _ReminderRepository();
    await pumpScreen(tester, const NotificationsScreen(),
        repository: repo,
        inbox: const [
          AppNotification(
              id: 'single',
              toUid: 'me',
              title: 'Dinner reminder',
              body: 'Dinner: USD 25.00 still owed.',
              type: 'reminder',
              billId: 'Dinner',
              read: false)
        ]);
    await tester.tap(find.text('Dinner reminder'));
    await tester.pumpAndSettle();
    expect(repo.readNotifications, ['single']);
    expect(find.byType(BillDetailScreen), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('combined reminder keeps the complete breakdown in the inbox',
      (tester) async {
    final repo = _ReminderRepository();
    const body = 'Total owed: USD 25.00; PKR 100.00.\n'
        '1. Dinner: USD 25.00\n2. Taxi: PKR 100.00';
    await pumpScreen(tester, const NotificationsScreen(),
        repository: repo,
        inbox: const [
          AppNotification(
              id: 'all',
              toUid: 'me',
              title: 'Combined reminder',
              body: body,
              type: 'reminder',
              read: false)
        ]);
    await tester.tap(find.text('Combined reminder'));
    await tester.pumpAndSettle();
    expect(repo.readNotifications, ['all']);
    expect(find.text(body), findsOneWidget);
    expect(find.byType(BillDetailScreen), findsNothing);
  });

  testWidgets('open history stays current as bills change and disappear',
      (tester) async {
    final stream = StreamController<List<Bill>>();
    addTearDown(stream.close);
    await pumpScreen(tester,
        const PersonBillsScreen(personUid: 'friend', personName: 'Hamza Malik'),
        bills: stream.stream);
    expect(find.byType(ShimmerList), findsOneWidget);
    stream.add(fixtures);
    await tester.pumpAndSettle();
    expect(find.text('2 bills with Hamza Malik'), findsOneWidget);
    expect(find.text('Unsettled (1)'), findsOneWidget);
    expect(find.text('Settled (1)'), findsOneWidget);
    stream.add([fixtures.first]);
    await tester.pumpAndSettle();
    expect(find.text('1 bill with Hamza Malik'), findsOneWidget);
    expect(find.text('Settled lunch'), findsNothing);
    expect(find.text('Unsettled (1)'), findsOneWidget);
    expect(find.text('Settled (0)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Settled (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No settled bills'), findsOneWidget);
    stream.add([
      fixtures.first.copyWith(splits: [
        for (final split in fixtures.first.splits) split.copyWith(paid: true),
      ])
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('No settled bills'), findsNothing);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Settled (1)'))
            .selected,
        isTrue);
    expect(find.text('Unsettled (0)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unsettled (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No unsettled bills'), findsOneWidget);
    expect(find.text('Dinner'), findsNothing);
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No shared bills'), findsOneWidget);
    expect(find.text('Unsettled (0)'), findsOneWidget);
    expect(find.text('Settled (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history reports load errors with a retry action',
      (tester) async {
    await pumpScreen(tester,
        const PersonBillsScreen(personUid: 'friend', personName: 'Hamza Malik'),
        bills: Stream.error(StateError('offline')));
    expect(find.text('Could not load your shared bills.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 768.0]) {
      testWidgets('history fits width $width, dark $dark, enlarged text',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.reset);
        await pumpScreen(
            tester,
            const PersonBillsScreen(
                personUid: 'friend',
                personName: 'Alexandria Featherstonehaugh-Williams'),
            theme: dark ? splitwizeDarkTheme : splitwizeLightTheme,
            textScale: 2);
        expect(find.text('Shared bills'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
