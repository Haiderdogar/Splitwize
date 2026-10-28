import 'package:flutter/material.dart';

/// Splitwize's design system: Material 3 Expressive built on the teal
/// brand, with the same light/dark surfaces the splash and Figma use
/// (#F8FAFA / #0F1414). Everything visual lives here so screens stay
/// free of one-off colours, radii and text styles — changing the look
/// of the whole app means editing this file, not every screen.
///
/// Nothing here touches behaviour: no providers, no navigation, no
/// data. Screens keep the same widgets and handlers; they just render
/// through this theme.

/// Teal seed the whole palette is derived from.
const _seed = Color(0xFF00696D);

ThemeData get splitwizeLightTheme => _build(
      ColorScheme.fromSeed(seedColor: _seed).copyWith(
        // Brand surfaces (also the splash + Figma backgrounds).
        surface: const Color(0xFFF8FAFA),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF1F5F4),
        surfaceContainer: const Color(0xFFE9EFEF),
        surfaceContainerHigh: const Color(0xFFDEE6E5),
        surfaceContainerHighest: const Color(0xFFD2DDDC),
        outline: const Color(0xFF6F7979),
        outlineVariant: const Color(0xFFBEC9C8),
      ),
    );

ThemeData get splitwizeDarkTheme => _build(
      ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark)
          .copyWith(
        surface: const Color(0xFF0F1414),
        surfaceContainerLowest: const Color(0xFF0A0F0F),
        surfaceContainerLow: const Color(0xFF1C2322),
        surfaceContainer: const Color(0xFF242B2A),
        surfaceContainerHigh: const Color(0xFF2F3736),
        surfaceContainerHighest: const Color(0xFF3A4443),
        outline: const Color(0xFF899392),
        outlineVariant: const Color(0xFF3F4948),
      ),
    );

ThemeData _build(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  // Expressive type: bigger, bolder headings with tight tracking, and
  // semibold labels — the hierarchy that makes a screen read as
  // designed rather than default.
  final text = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  );

  const pill = StadiumBorder();
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    // Tonal cards with a large expressive radius and no shadow: the
    // modern M3 look. Screens keep their own padding, so no layout
    // moves — only shape and fill change.
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: pill,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    // Filled, borderless fields with a 16px radius: forms read as one
    // coherent system instead of a row of default outlines.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      side: BorderSide.none,
      shape: pill,
      labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
