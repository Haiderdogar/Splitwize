import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/utils/money.dart';

void main() {
  group('formatMoney grouping', () {
    test('PKR groups lakh-style', () {
      expect(formatMoney(125000, 'PKR'), '₨1,25,000.00');
      expect(formatMoney(1000000, 'PKR'), '₨10,00,000.00');
    });

    test('INR groups lakh-style', () {
      expect(formatMoney(125000, 'INR'), contains('1,25,000'));
    });

    test('USD keeps Western grouping', () {
      expect(formatMoney(125000, 'USD'), '\$125,000.00');
    });

    test('formatMoneyNumber returns digits only, same grouping', () {
      expect(formatMoneyNumber(125000, 'PKR'), '1,25,000.00');
      expect(formatMoneyNumber(1234.5, 'USD'), '1,234.50');
    });
  });
}
