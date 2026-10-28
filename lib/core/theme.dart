import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette — mirrors CSS :root variables in COUGHFEE_Mobile_UI.html
class AppColors {
  AppColors._();

  // Light mode
  static const Color bgLight = Color(0xFFF4F5FA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color inkLight = Color(0xFF12182B);
  static const Color muteLight = Color(0xFF6A7188);
  static const Color lineLight = Color(0xFFE3E6F0);
  static const Color brandLight = Color(0xFF2441FF);
  static const Color onBrandLight = Color(0xFFFFFFFF);

  // Dark mode
  static const Color bgDark = Color(0xFF0E1220);
  static const Color cardDark = Color(0xFF171C2F);
  static const Color inkDark = Color(0xFFEEF0F8);
  static const Color muteDark = Color(0xFF98A0BA);
  static const Color lineDark = Color(0xFF262C44);
  static const Color brandDark = Color(0xFF6B82FF);
  static const Color onBrandDark = Color(0xFF0E1220);

  // Semantic – same in both modes
  static const Color crema = Color(0xFFFFC94A);
  static const Color ok = Color(0xFF0E9F6E);
  static const Color bad = Color(0xFFD6336C);

  // Category accent colours (from TONE map in HTML)
  static const Color toneHotCoffee = Color(0xFFC98B5A);
  static const Color toneIcedCoffee = Color(0xFF7FA7FF);
  static const Color toneNonCoffee = Color(0xFF7CC9A1);
  static const Color tonePastries = Color(0xFFF2B880);
  static const Color toneMerch = Color(0xFFB8A6F0);
}

/// Light [ColorScheme] derived from AppColors.
ColorScheme _lightScheme() => const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brandLight,
      onPrimary: AppColors.onBrandLight,
      secondary: AppColors.crema,
      onSecondary: AppColors.inkLight,
      error: AppColors.bad,
      onError: Colors.white,
      surface: AppColors.bgLight,
      onSurface: AppColors.inkLight,
    );

/// Dark [ColorScheme] derived from AppColors.
ColorScheme _darkScheme() => const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.brandDark,
      onPrimary: AppColors.onBrandDark,
      secondary: AppColors.crema,
      onSecondary: AppColors.inkDark,
      error: AppColors.bad,
      onError: Colors.white,
      surface: AppColors.bgDark,
      onSurface: AppColors.inkDark,
    );

ThemeData _buildTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.brightness == Brightness.light
          ? AppColors.cardLight
          : AppColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.brightness == Brightness.light
          ? AppColors.cardLight
          : AppColors.cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.bad),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.bad, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: scheme.brightness == Brightness.light
          ? AppColors.cardLight
          : AppColors.cardDark,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.brightness == Brightness.light
          ? AppColors.muteLight
          : AppColors.muteDark,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

/// Light theme for the app.
final ThemeData appLightTheme = _buildTheme(_lightScheme());

/// Dark theme for the app.
final ThemeData appDarkTheme = _buildTheme(_darkScheme());
