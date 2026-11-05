import 'package:flutter/material.dart';

/// Splitwize visual system: vivid indigo, electric cyan and coral accents,
/// soft luminous surfaces and rounded, tactile controls.
const splitwizeIndigo = Color(0xFF5145EF);
const splitwizeCyan = Color(0xFF1BC8E5);
const splitwizeCoral = Color(0xFFFF789B);
const splitwizeViolet = Color(0xFF915BFA);
const splitwizeMint = Color(0xFF36D8A3);

ThemeData get splitwizeLightTheme => _build(
  ColorScheme.fromSeed(seedColor: splitwizeIndigo).copyWith(
    primary: splitwizeIndigo,
    onPrimary: Colors.white,
    secondary: splitwizeCyan,
    onSecondary: const Color(0xFF062E34),
    tertiary: splitwizeCoral,
    surface: const Color(0xFFF6F7FF),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFEEF0FF),
    surfaceContainer: const Color(0xFFE5E8FF),
    surfaceContainerHigh: const Color(0xFFD9DEFF),
    surfaceContainerHighest: const Color(0xFFCCD2F5),
    outline: const Color(0xFF72789A),
    outlineVariant: const Color(0xFFC5CAE2),
  ),
);

ThemeData get splitwizeDarkTheme => _build(
  ColorScheme.fromSeed(seedColor: splitwizeIndigo, brightness: Brightness.dark).copyWith(
    primary: const Color(0xFFB0A7FF),
    onPrimary: const Color(0xFF21166D),
    secondary: const Color(0xFF65E2EC),
    onSecondary: const Color(0xFF00363C),
    tertiary: const Color(0xFFFF9292),
    surface: const Color(0xFF101225),
    surfaceContainerLowest: const Color(0xFF0B0D1B),
    surfaceContainerLow: const Color(0xFF191C35),
    surfaceContainer: const Color(0xFF222645),
    surfaceContainerHigh: const Color(0xFF2D3155),
    surfaceContainerHighest: const Color(0xFF393E65),
    outline: const Color(0xFF9CA3C8),
    outlineVariant: const Color(0xFF41466B),
  ),
);

ThemeData _build(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.7),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.35),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.15),
    labelMedium: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: scheme.brightness == Brightness.dark ? 0 : 2,
      shadowColor: scheme.primary.withValues(alpha: .07),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 7,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: text.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      refreshBackgroundColor: scheme.surfaceContainerLow,
    ),
  );
}

extension SplitwizeDebtColors on ColorScheme {
  Color get owed => brightness == Brightness.dark ? const Color(0xFF70DDB3) : const Color(0xFF087D58);
  Color get owe => brightness == Brightness.dark ? const Color(0xFFFFC078) : const Color(0xFFB45A00);
}
