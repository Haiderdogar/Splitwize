// Run: flutter test --no-pub tool/home_capture.dart.
// Review-only fixture data; this never connects to Firebase or a live account.
// Set HOME_CAPTURE_BEFORE=1 to save the current screen as home-before.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/screens/home_shell.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/utils/payment_ledger.dart';

import '../test/responsive_overflow_test.dart' as fixture;

class _Subscription extends AdFreeStatus {
  @override
  Future<bool> build() async => true;
}

Bill _expense({
  required String id,
  required String title,
  required double total,
  required String payer,
  required DateTime date,
  String? group,
  double settlement = 0,
}) {
  final splits = [
    for (final person in [fixture.me, _sara, fixture.friend2])
      BillSplit(
        uid: person.uid,
        displayName: person.displayName,
        amount: total / 3,
      ),
  ];
  final payments = {payer: total};
  final debts = buildPaymentDebts(splits: splits, merchantPayments: payments);
  return Bill(
    id: id,
    title: title,
    subtotal: total,
    tipPercent: 0,
    total: total,
    splitType: 'equal',
    createdBy: 'me',
    createdByName: fixture.me.displayName,
    groupId: group == null ? null : 'g1',
    groupName: group,
    participantIds: const ['me', 'f1', 'f2'],
    splits: splits,
    merchantPayments: payments,
    paymentDebts: [
      for (final debt in debts)
        debt.copyWith(settledAmount: debt.amount * settlement),
    ],
    createdAt: date,
    currency: 'PKR',
  );
}

const _sara = AppUser(
  uid: 'f1',
  displayName: 'Sara Ahmed',
  email: 'sara@example.com',
);

final _previewBills = [
  _expense(
    id: 'dinner',
    title: 'Dinner at Monal',
    total: 8400,
    payer: 'me',
    date: DateTime(2026, 11, 13, 20),
    group: 'Weekend crew',
    settlement: .5,
  ),
  _expense(
    id: 'groceries',
    title: 'Groceries for the week',
    total: 6000,
    payer: 'f1',
    date: DateTime(2026, 11, 13, 14),
    group: 'Our apartment',
  ),
  _expense(
    id: 'coffee',
    title: 'Coffee & catch-up',
    total: 3600,
    payer: 'f2',
    date: DateTime(2026, 11, 12, 17),
    settlement: 1,
  ),
  _expense(
    id: 'fuel',
    title: 'Road trip fuel',
    total: 12000,
    payer: 'me',
    date: DateTime(2026, 11, 11, 10),
    group: 'Weekend crew',
    settlement: 1,
  ),
];

void main() {
  setUpAll(() async {
    await fixture.loadRoboto();
    var sdkDirectory = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      sdkDirectory = sdkDirectory.parent;
    }
    final bytes = await File('${sdkDirectory.path}/bin/cache/artifacts/'
            'material_fonts/materialicons-regular.otf')
        .readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  });

  testWidgets('capture expense-focused Home', (tester) async {
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();

    Future<void> pumpHome({
      ThemeMode mode = ThemeMode.light,
      Size size = const Size(390, 844),
      double textScale = 1,
      List<Bill>? bills,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...fixture.testOverrides(),
          adFreeStatusProvider.overrideWith(_Subscription.new),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: splitwizeLightTheme,
            darkTheme: splitwizeDarkTheme,
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: ProviderScope(
              overrides: [
                myBillsProvider.overrideWith(
                    (ref) => Stream.value(bills ?? _previewBills)),
              ],
              child: const HomeShell(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
            const AssetImage('assets/icon/app_icon.png'),
            tester.element(find.byType(MaterialApp)),
          ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) => tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final screenshot = await boundary.toImage(pixelRatio: 2);
          final bytes =
              (await screenshot.toByteData(format: ui.ImageByteFormat.png))!;
          await Directory('docs').create(recursive: true);
          await File('docs/$name.png').writeAsBytes(bytes.buffer.asUint8List());
          screenshot.dispose();
        });

    await pumpHome();
    if (Platform.environment['HOME_CAPTURE_BEFORE'] == '1') {
      await capture('home-before');
      return;
    }
    await capture('home-after');
    await tester.tap(find.byTooltip('Search expenses'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Monal');
    await tester.pumpAndSettle();
    await capture('home-after-search');
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unsettled (2)'));
    await tester.pumpAndSettle();
    await capture('home-after-filtered');
    await pumpHome(mode: ThemeMode.dark);
    await capture('home-after-dark');
    await pumpHome(size: const Size(320, 700));
    await capture('home-after-small');
    await pumpHome(size: const Size(320, 568), textScale: 2);
    await capture('home-after-large-text');
    await pumpHome(size: const Size(1024, 768));
    await capture('home-after-tablet');
    await pumpHome(bills: const []);
    await capture('home-after-empty');
  });
}
