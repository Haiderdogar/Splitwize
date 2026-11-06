import 'package:flutter/material.dart';

/// Quiet, confident financial UI. Color is reserved for actionable states
/// and balance direction, not used as decoration.
abstract final class SplitwizePalette {
  static const forest = Color(0xFF153F37);
  static const forestDark = Color(0xFF0C302B);
  static const ink = Color(0xFF25312E);
  static const canvas = Color(0xFFFAF9F5);
  static const lime = Color(0xFFD8EC9B);
  static const coral = Color(0xFFE9A17F);
  static const line = Color(0xFFE2E7DE);
  static const muted = Color(0xFF66746D);
  static const positive = Color(0xFF247B52);
  static const negative = Color(0xFFA34B36);
}

// Compatibility for any old local components that still use these constants.
const splitwizeIndigo = SplitwizePalette.forest;
const splitwizeCyan = SplitwizePalette.lime;
const splitwizeCoral = SplitwizePalette.coral;
const splitwizeViolet = SplitwizePalette.forestDark;
const splitwizeMint = SplitwizePalette.positive;

ThemeData get splitwizeLightTheme => _build(
  ColorScheme.fromSeed(seedColor: SplitwizePalette.forest).copyWith(
    primary: SplitwizePalette.forest,
    onPrimary: Colors.white,
    primaryContainer: SplitwizePalette.lime,
    onPrimaryContainer: SplitwizePalette.forestDark,
    secondary: SplitwizePalette.positive,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE9F3EA),
    onSecondaryContainer: SplitwizePalette.forestDark,
    tertiary: SplitwizePalette.coral,
    surface: SplitwizePalette.canvas,
    onSurface: SplitwizePalette.ink,
    onSurfaceVariant: SplitwizePalette.muted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF4F6F1),
    surfaceContainer: const Color(0xFFEEF2EB),
    surfaceContainerHigh: const Color(0xFFE6EDE3),
    outline: SplitwizePalette.muted,
    outlineVariant: SplitwizePalette.line,
  ),
);

ThemeData get splitwizeDarkTheme => _build(
  ColorScheme.fromSeed(
    seedColor: SplitwizePalette.lime,
    brightness: Brightness.dark,
  ).copyWith(
    primary: SplitwizePalette.lime,
    onPrimary: SplitwizePalette.forestDark,
    primaryContainer: const Color(0xFF2F5847),
    onPrimaryContainer: const Color(0xFFE1F1D7),
    secondary: const Color(0xFF8FDEAD),
    onSecondary: SplitwizePalette.forestDark,
    secondaryContainer: const Color(0xFF234B39),
    onSecondaryContainer: const Color(0xFFD5F2DE),
    tertiary: const Color(0xFFF1B59A),
    surface: const Color(0xFF111B19),
    onSurface: const Color(0xFFEAF2EA),
    onSurfaceVariant: const Color(0xFFBBC7BD),
    surfaceContainerLowest: const Color(0xFF192623),
    surfaceContainerLow: const Color(0xFF1D2B27),
    surfaceContainer: const Color(0xFF24342D),
    surfaceContainerHigh: const Color(0xFF2B3C35),
    outline: const Color(0xFF9FACA3),
    outlineVariant: const Color(0xFF3F5448),
  ),
);

ThemeData _build(ColorScheme scheme) {
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.13),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800, letterSpacing: -.8),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800, letterSpacing: -.6),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800, letterSpacing: -.3),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700),
  );
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      highlightElevation: 1,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      horizontalTitleGap: 12,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      elevation: 0,
      height: 73,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11, fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800 : FontWeight.w600,
        color: states.contains(WidgetState.selected)
            ? scheme.primary : scheme.onSurfaceVariant,
      )),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHigh,
    ),
  );
}

extension SplitwizeDebtColors on ColorScheme {
  Color get owed => brightness == Brightness.dark
      ? const Color(0xFF86E5AE) : SplitwizePalette.positive;
  Color get owe => brightness == Brightness.dark
      ? const Color(0xFFFFB6A0) : SplitwizePalette.negative;
}
