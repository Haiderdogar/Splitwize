import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/widgets/aurora_ui.dart';

void main() {
  testWidgets('Aurora hero fits narrow phones with large accessibility text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.6),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: AuroraHero(
              eyebrow: 'SHARED EXPENSES',
              title: 'Split moments, not friendships.',
              subtitle: 'Long descriptive text must wrap without overflowing the mobile screen.',
              icon: Icons.receipt_long_rounded,
              metric: '123',
              metricLabel: 'bills together',
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.text('Split moments, not friendships.'), findsOneWidget);
  });

  testWidgets('Aurora quick action invokes its callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Row(children: [
            AuroraActionTile(
              icon: Icons.add_rounded,
              label: 'Split bill',
              color: AuroraPalette.indigo,
              onTap: () => taps++,
            ),
            AuroraActionTile(
              icon: Icons.groups_rounded,
              label: 'Groups',
              color: AuroraPalette.cyan,
              onTap: () {},
            ),
          ]),
        ),
      ),
    ));
    await tester.tap(find.text('Split bill'));
    await tester.pump();
    expect(taps, 1);
  });
}
