import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/theme.dart';

void main() {
  group('Splitwize minimal financial design', () {
    test('light and dark surfaces preserve contrast and brand identity', () {
      expect(splitwizeLightTheme.colorScheme.primary,
          SplitwizePalette.forest);
      expect(splitwizeLightTheme.colorScheme.surface,
          SplitwizePalette.canvas);
      expect(splitwizeDarkTheme.colorScheme.surface,
          const Color(0xFF111B19));
      expect(splitwizeDarkTheme.colorScheme.onSurface,
          const Color(0xFFEAF2EA));
    });

    test('money direction retains semantic colors', () {
      final light = splitwizeLightTheme.colorScheme;
      expect(light.owed, SplitwizePalette.positive);
      expect(light.owe, SplitwizePalette.negative);
      expect(light.owed, isNot(light.owe));
    });

    test('cards are quiet surfaces without decorative elevation', () {
      final card = splitwizeLightTheme.cardTheme;
      expect(card.color, splitwizeLightTheme.colorScheme.surfaceContainerLowest);
      expect(card.elevation, 0);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
    });

    test('labels and headings are clear and bold', () {
      expect(splitwizeLightTheme.textTheme.titleLarge?.fontWeight,
          FontWeight.w800);
      expect(splitwizeLightTheme.appBarTheme.elevation, 0);
      expect(splitwizeLightTheme.appBarTheme.titleTextStyle?.fontWeight,
          FontWeight.w800);
    });

    test('forms use visible 14px outlined inputs', () {
      final decoration = splitwizeLightTheme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      final border = decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(14));
      expect(border.borderSide,
          BorderSide(color: splitwizeLightTheme.colorScheme.outlineVariant));
    });

    test('buttons use compact rounded tap targets', () {
      expect(
        splitwizeLightTheme.filledButtonTheme.style?.shape?.resolve({}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
      expect(
        splitwizeLightTheme.floatingActionButtonTheme.backgroundColor,
        splitwizeLightTheme.colorScheme.primary,
      );
    });
  });
}
