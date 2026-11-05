import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/theme.dart';

void main() {
  group('Splitwize dimensional design system', () {
    test('uses the new indigo and luminous surfaces in both themes', () {
      expect(splitwizeLightTheme.colorScheme.primary, splitwizeIndigo);
      expect(splitwizeLightTheme.colorScheme.surface, const Color(0xFFF6F7FF));
      expect(splitwizeDarkTheme.colorScheme.surface, const Color(0xFF101225));
      expect(splitwizeLightTheme.colorScheme.tertiary, splitwizeCoral);
    });

    test('cards are raised and rounded to add gentle visual depth', () {
      final card = splitwizeLightTheme.cardTheme;
      expect(card.color, splitwizeLightTheme.colorScheme.surfaceContainerLowest);
      expect(card.elevation, 2);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
      expect(shape.side.style, BorderStyle.solid);
    });

    test('app bar titles and headings use strong display weight', () {
      expect(splitwizeLightTheme.textTheme.titleLarge?.fontWeight,
          FontWeight.w800);
      expect(splitwizeLightTheme.appBarTheme.titleTextStyle?.fontWeight,
          FontWeight.w800);
      expect(splitwizeLightTheme.appBarTheme.elevation, 0);
    });

    test('form fields are filled with rounded 18px outlined borders', () {
      final decoration = splitwizeLightTheme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(18));
      expect(
        border.borderSide,
        BorderSide(color: splitwizeLightTheme.colorScheme.outlineVariant),
      );
    });

    test('buttons and FABs have tactile rounded shapes', () {
      final buttonShape = splitwizeLightTheme.filledButtonTheme.style?.shape
          ?.resolve({});
      expect(buttonShape, RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ));
      final fab = splitwizeLightTheme.floatingActionButtonTheme;
      expect(fab.backgroundColor, splitwizeLightTheme.colorScheme.primary);
      expect(fab.shape, RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
      ));
      expect(fab.elevation, 7);
    });
  });
}
