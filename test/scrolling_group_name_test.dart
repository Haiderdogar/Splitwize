import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/widgets/scrolling_group_name.dart';

import 'responsive_overflow_test.dart' as fixture;

const _longName = 'The Weekend Trip Planning Committee';

Future<void> _pumpName(
  WidgetTester tester, {
  String name = _longName,
  double width = 120,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: 64,
          child: ScrollingGroupName(
            key: const ValueKey('group-name'),
            name: name,
            style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

ScrollPosition _position(WidgetTester tester) => tester
    .widget<SingleChildScrollView>(find.descendant(
      of: find.byType(ScrollingGroupName),
      matching: find.byType(SingleChildScrollView),
    ))
    .controller!
    .position;

void main() {
  setUpAll(fixture.loadRoboto);

  testWidgets('a fitting group name stays still', (tester) async {
    await _pumpName(tester, name: 'Hostel', width: 240);
    expect(_position(tester).maxScrollExtent, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_position(tester).pixels, 0);
    expect(find.text('Hostel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a lengthy name scrolls to reveal the end and returns',
      (tester) async {
    await _pumpName(tester);
    expect(_position(tester).maxScrollExtent, greaterThan(0));
    expect(_position(tester).pixels, 0);
    expect(find.text(_longName), findsOneWidget);
    final text = tester.widget<Text>(find.text(_longName));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    final scrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scrollView.clipBehavior, isNot(Clip.none));

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_position(tester).pixels, greaterThan(0));

    await tester.pump(const Duration(seconds: 40));
    final end = _position(tester).maxScrollExtent;
    expect(_position(tester).pixels, closeTo(end, .1));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_position(tester).pixels, lessThan(end));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion keeps a lengthy name still', (tester) async {
    await _pumpName(tester, disableAnimations: true);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_position(tester).pixels, 0);
    expect(find.text(_longName), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('name and width updates reset scrolling and disposal cancels it',
      (tester) async {
    await _pumpName(tester);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_position(tester).pixels, greaterThan(0));

    await _pumpName(tester, name: 'Hostel', width: 240);
    await tester.pump(const Duration(seconds: 3));
    expect(_position(tester).maxScrollExtent, 0);
    expect(_position(tester).pixels, 0);

    await _pumpName(tester, width: 500);
    expect(_position(tester).maxScrollExtent, 0);
    await _pumpName(tester, width: 100);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_position(tester).pixels, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
