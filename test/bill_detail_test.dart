import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/screens/bill_detail_screen.dart';
import 'package:splitwize/theme.dart';

import 'responsive_overflow_test.dart' as fixture;

const _plainBill = Bill(
  id: 'plain',
  title: 'Coffee',
  subtotal: 100,
  tipPercent: 0,
  total: 100,
  splitType: 'equal',
  createdBy: 'me',
  createdByName: 'Ali Haider',
  participantIds: ['me', 'f1'],
  splits: [
    BillSplit(uid: 'me', displayName: 'Ali Haider', amount: 50, paid: true),
    BillSplit(uid: 'f1', displayName: 'Alex', amount: 50),
  ],
);

// I paid the whole bill; Alex has not paid anything back, Hamza paid half.
const _ledgerBill = Bill(
  id: 'ledger',
  title: 'Shared dinner',
  subtotal: 100,
  tipPercent: 0,
  total: 100,
  splitType: 'custom',
  createdBy: 'me',
  createdByName: 'Ali Haider',
  participantIds: ['me', 'f1', 'f2'],
  splits: [
    BillSplit(uid: 'me', displayName: 'Ali Haider', amount: 40),
    BillSplit(uid: 'f1', displayName: 'Alex', amount: 30),
    BillSplit(uid: 'f2', displayName: 'Hamza Malik', amount: 30),
  ],
  merchantPayments: {'me': 100},
  paymentDebts: [
    BillDebt(
      id: 'd1',
      debtorUid: 'f1',
      debtorName: 'Alex',
      creditorUid: 'me',
      creditorName: 'Ali Haider',
      amount: 30,
    ),
    BillDebt(
      id: 'd2',
      debtorUid: 'f2',
      debtorName: 'Hamza Malik',
      creditorUid: 'me',
      creditorName: 'Ali Haider',
      amount: 30,
      settledAmount: 15,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Bill bill) async {
  // Tall enough that every lazily built row is on screen.
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: fixture.testOverrides(bill: bill),
    child: MaterialApp(
      theme: splitwizeLightTheme,
      home: BillDetailScreen(billId: bill.id),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  // Real glyph widths, like the other layout tests; the default test font is
  // far wider than Roboto and would overflow rows that fit on a device.
  setUpAll(fixture.loadRoboto);

  testWidgets('without a tip the summary shows the total once', (tester) async {
    await _pump(tester, _plainBill);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Subtotal'), findsNothing);
    expect(find.textContaining('Tip ('), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a tip the subtotal and tip breakdown is kept',
      (tester) async {
    await _pump(tester, fixture.testBill);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Tip (18%)'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment rows skip filler and repeated account details',
      (tester) async {
    await _pump(tester, _ledgerBill);
    expect(find.text('Alex owes ${fixture.me.displayName} (you)'),
        findsOneWidget);
    // The signed-in email is not repeated under every row.
    expect(find.text(fixture.me.email), findsNothing);
    // Ledger shares need no "Share of expense" label on each row.
    expect(find.text('Share of expense'), findsNothing);
    // Only the half-paid debt reports a remainder.
    expect(find.textContaining('remaining'), findsOneWidget);
    expect(find.text('Mark settled'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
