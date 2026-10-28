import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/widgets/money_text.dart';
import 'package:splitwize/widgets/split_bar.dart';

void main() {
  group('MoneyText', () {
    testWidgets('renders symbol plus lakh-grouped digits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MoneyText(125000, currencyCode: 'PKR')),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.text.toPlainText(), '₨ 1,25,000.00');
      expect(tester.takeException(), isNull);
    });
  });

  group('SplitBar', () {
    testWidgets('renders proportional segments without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SplitBar(
              segments: [
                SplitSegment(value: 3, color: Colors.teal),
                SplitSegment(value: 1, color: Colors.orange),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(SplitBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty segments render nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SplitBar(segments: [])),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
