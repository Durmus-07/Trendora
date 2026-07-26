import 'package:flutter/material.dart';

abstract final class TrendoraColors {
  static const Color background = Color(0xFF07101F);
  static const Color backgroundSoft = Color(0xFF0B1629);
  static const Color surface = Color(0xFF101D33);
  static const Color surfaceStrong = Color(0xFF172640);
  static const Color border = Color(0xFF263B5D);
  static const Color primary = Color(0xFF7C5CFC);
  static const Color secondary = Color(0xFF35C9FF);
  static const Color accent = Color(0xFFFFC857);
  static const Color success = Color(0xFF44D7A8);
  static const Color textPrimary = Color(0xFFF8FAFF);
  static const Color textSecondary = Color(0xFFAAB8CF);
}

abstract final class TrendoraTheme {
  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: TrendoraColors.primary,
      brightness: Brightness.dark,
      surface: TrendoraColors.surface,
    ).copyWith(
      primary: TrendoraColors.primary,
      secondary: TrendoraColors.secondary,
      tertiary: TrendoraColors.accent,
      surface: TrendoraColors.surface,
      outline: TrendoraColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: TrendoraColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: TrendoraColors.background,
        foregroundColor: TrendoraColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: TrendoraColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: TrendoraColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: TrendoraColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: TrendoraColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TrendoraColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TrendoraColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TrendoraColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TrendoraColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: TrendoraColors.secondary,
            width: 1.4,
          ),
        ),
      ),
      dividerColor: TrendoraColors.border,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TrendoraColors.surfaceStrong,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
