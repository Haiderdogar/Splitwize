import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/utils/money.dart';
import 'package:splitwize/widgets/bill_list_tile.dart';

import 'responsive_overflow_test.dart' as fixture;

const _ledgerBill = Bill(
  id: 'ledger',
  title: 'Shared dinner',
  subtotal: 100,
  tipPercent: 0,
  total: 100,
  splitType: 'custom',
  createdBy: 'f1',
  createdByName: 'Alex',
  participantIds: ['me', 'f1'],
  splits: [
    BillSplit(uid: 'me', displayName: 'Ali Haider', amount: 40),
    BillSplit(uid: 'f1', displayName: 'Alex', amount: 60),
  ],
  merchantPayments: {'me': 100},
  paymentDebts: [
    BillDebt(
      id: 'debt',
      debtorUid: 'f1',
      debtorName: 'Alex',
      creditorUid: 'me',
      creditorName: 'Ali Haider',
      amount: 60,
      settledAmount: 30,
    ),
  ],
);

Future<void> _pumpCard(
  WidgetTester tester,
  Bill bill, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(ProviderScope(
    overrides: fixture.testOverrides(),
    child: MaterialApp(
      theme: splitwizeLightTheme,
      darkTheme: splitwizeDarkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BillListTile(bill: bill, uid: 'me'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(fixture.loadRoboto);

  testWidgets('progress measures debt settlement and identifies the real payer',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pumpCard(tester, _ledgerBill);

    expect(find.text('Paid by Ali Haider (you)'), findsOneWidget);
    expect(find.text('Your share: ${formatMoney(40)}'), findsOneWidget);
    expect(find.text('${formatMoney(30)} remaining'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
      reason: 'Half the debt is settled; merchant payment is separate.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settled expenses have an explicit completion state',
      (tester) async {
    addTearDown(tester.view.reset);
    final settled = _ledgerBill.copyWith(paymentDebts: [
      _ledgerBill.paymentDebts.single.copyWith(settledAmount: 60),
    ]);
    await _pumpCard(tester, settled);

    expect(find.text('Settled'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'long expense fits 320px at 2x text in ${dark ? 'dark' : 'light'}',
        (tester) async {
      addTearDown(tester.view.reset);
      await _pumpCard(
        tester,
        fixture.testBill,
        size: const Size(320, 568),
        textScale: 2,
        dark: dark,
      );
      expect(find.text('Total bill'), findsOneWidget);
      expect(find.text('Unsettled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
