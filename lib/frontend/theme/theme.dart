import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette — CafeGO Warm Coffee & Latte Theme
class AppColors {
  AppColors._();

  // Light mode (Creamy Latte / Artisanal Coffee Canvas)
  static const Color bgLight = Color(0xFFF9F6F0);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color inkLight = Color(0xFF231714);
  static const Color muteLight = Color(0xFF786960);
  static const Color lineLight = Color(0xFFE8DFD5);
  static const Color brandLight = Color(0xFF5A3825);
  static const Color onBrandLight = Color(0xFFFFFFFF);

  // Dark mode (Deep Espresso & Warm Mocha — matches reference UI)
  static const Color bgDark = Color(0xFF231F20);
  static const Color cardDark = Color(0xFF2E2728);
  static const Color inkDark = Color(0xFFF7F2EE);
  static const Color muteDark = Color(0xFFA69A93);
  static const Color lineDark = Color(0xFF3F3536);
  static const Color brandDark = Color(0xFFD4A373);
  static const Color onBrandDark = Color(0xFF231F20);

  // Semantic & Brand Accents
  static const Color crema = Color(0xFFD49755);
  static const Color warmAmber = Color(0xFFE5A862);
  static const Color warn = Color(0xFFD97706);
  static const Color ok = Color(0xFF2E7D32);
  static const Color bad = Color(0xFFD6336C);

  // Category accent colours
  static const Color toneHotCoffee = Color(0xFF8B5A3E);
  static const Color toneIcedCoffee = Color(0xFFC89568);
  static const Color toneNonCoffee = Color(0xFF6B8E68);
  static const Color tonePastries = Color(0xFFD9A066);
  static const Color toneMerch = Color(0xFF8C7360);
}

/// Light [ColorScheme] derived from AppColors.
ColorScheme _lightScheme() => const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brandLight,
      onPrimary: AppColors.onBrandLight,
      secondary: AppColors.crema,
      onSecondary: Colors.white,
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
      titleTextStyle: GoogleFonts.playfairDisplay(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.brightness == Brightness.light
          ? AppColors.cardLight
          : AppColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
          ? const Color(0xFFF1EAE2)
          : const Color(0xFF2C2425),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.bad),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.bad, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(88, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide(
          color: scheme.brightness == Brightness.light
              ? AppColors.lineLight
              : AppColors.lineDark,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: GoogleFonts.figtree(fontSize: 12),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

/// Light theme for the app.
final ThemeData appLightTheme = _buildTheme(_lightScheme());

/// Dark theme for the app.
final ThemeData appDarkTheme = _buildTheme(_darkScheme());
