import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/theme.dart';

void main() {
  group('Splitwize design system', () {
    test('brand surfaces match splash and Figma', () {
      expect(splitwizeLightTheme.colorScheme.surface, const Color(0xFFF8FAFA));
      expect(splitwizeDarkTheme.colorScheme.surface, const Color(0xFF0F1414));
    });

    test('cards are tonal with a large expressive radius, no shadow', () {
      final card = splitwizeLightTheme.cardTheme;
      expect(card.color, splitwizeLightTheme.colorScheme.surfaceContainerLow);
      expect(card.elevation, 0);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
    });

    test('app bar titles and headings are bold', () {
      expect(splitwizeLightTheme.textTheme.titleLarge?.fontWeight,
          FontWeight.w700);
      expect(splitwizeLightTheme.appBarTheme.titleTextStyle?.fontWeight,
          FontWeight.w700);
      expect(splitwizeLightTheme.appBarTheme.elevation, 0);
    });

    test('form fields are filled with a 16px radius', () {
      final decoration = splitwizeLightTheme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(16));
      expect(border.borderSide, BorderSide.none);
    });

    test('primary buttons and FABs use the pill shape', () {
      const pill = StadiumBorder();
      expect(splitwizeLightTheme.filledButtonTheme.style?.shape?.resolve({}),
          pill);
      expect(splitwizeLightTheme.floatingActionButtonTheme.backgroundColor,
          splitwizeLightTheme.colorScheme.primary);
    });
  });
}
