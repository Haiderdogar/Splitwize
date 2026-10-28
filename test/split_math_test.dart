import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/utils/split_math.dart';

void main() {
  group('unallocatedRemainder', () {
    test('percentage: 100 minus the entered percents', () {
      expect(
        unallocatedRemainder(
          splitType: 'percentage',
          selected: {'a', 'b'},
          percents: {'a': '50', 'b': '30'},
          amounts: const {},
          total: 1000,
        ),
        20,
      );
    });

    test('percentage: over-allocation goes negative', () {
      expect(
        unallocatedRemainder(
          splitType: 'percentage',
          selected: {'a', 'b'},
          percents: {'a': '60', 'b': '50'},
          amounts: const {},
          total: 1000,
        ),
        -10,
      );
    });

    test('custom: total minus the entered amounts', () {
      expect(
        unallocatedRemainder(
          splitType: 'custom',
          selected: {'a', 'b'},
          percents: const {},
          amounts: {'a': '400', 'b': '300'},
          total: 1000,
        ),
        300,
      );
    });

    test('equal splits never have a remainder', () {
      expect(
        unallocatedRemainder(
          splitType: 'equal',
          selected: {'a', 'b'},
          percents: const {},
          amounts: const {},
          total: 1000,
        ),
        isNull,
      );
    });

    test('unparseable entries count as zero', () {
      expect(
        unallocatedRemainder(
          splitType: 'percentage',
          selected: {'a'},
          percents: {'a': 'abc'},
          amounts: const {},
          total: 1000,
        ),
        100,
      );
    });
  });
}
