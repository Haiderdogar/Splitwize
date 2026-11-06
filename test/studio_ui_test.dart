import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/widgets/studio_ui.dart';

void main() {
  testWidgets('minimal design stays readable on small phones at 1.6x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: splitwizeLightTheme,
      home: const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.6),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              PageIntroduction(
                eyebrow: 'YOUR SPACE',
                title: 'Your money, together.',
                description: 'Keep every shared expense clear.',
              ),
              SoftPanel(child: Row(children: [
                PersonMark(initials: 'AH'),
                SizedBox(width: 10),
                Expanded(child: Text('A shared bill for friends')),
              ])),
            ]),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Your money, together.'), findsOneWidget);
    expect(find.text('A shared bill for friends'), findsOneWidget);
  });

  testWidgets('navigation labels are readable in both themes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: splitwizeDarkTheme,
      home: const Scaffold(
        body: Center(child: SplitwizeMark(size: 50)),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(SplitwizeMark), findsOneWidget);
  });
}
