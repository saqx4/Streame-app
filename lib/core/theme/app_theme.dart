import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ============================================
  // ARCTIC FUSE 2 COLORS (exact copy from Kotlin)
  // ============================================
  static const Color arcticWhite = Color(0xFFEDEDED);
  static const Color arcticWhite90 = Color(0xE7EDEDED);
  static const Color arcticWhite70 = Color(0xB3EDEDED);
  static const Color arcticWhite50 = Color(0x80EDEDED);
  static const Color arcticWhite30 = Color(0x4DEDEDED);
  static const Color arcticWhite12 = Color(0x1FEDEDED);

  static const Color backgroundDark = Color(0xFF08090A);
  static const Color backgroundCard = Color(0xFF0D0D0D);
  static const Color backgroundElevated = Color(0xFF1A1A1A);
  static const Color backgroundOverlay = Color(0xE608090A);
  static const Color backgroundGlass = Color(0x9908090A);

  static const Color textPrimary = arcticWhite;
  static const Color textSecondary = arcticWhite70;
  static const Color textTertiary = arcticWhite50;
  static const Color textDisabled = arcticWhite30;

  static const Color borderLight = arcticWhite12;
  static const Color borderMedium = arcticWhite30;
  static const Color borderGradient = arcticWhite50;

  // ============================================
  // FOCUS & GLOW (Arctic Fuse 2 - white focus)
  // ============================================
  static const Color focusRing = Color(0xFFEDEDED);
  static const Color focusGlow = Color(0x33000000);
  static const Color focusShadow = Color(0x40000000);

  // Accents
  static const Color accentYellow = Color(0xFFFFCD3C);
  static const Color accentGreen = Color(0xFF00D588);
  static const Color accentRed = Color(0xFFE53935);
  static const Color successColor = accentGreen;
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color warningColor = Color(0xFFF39C12);

  // Channel aliases (for compatibility)
  static const Color primaryColor = textPrimary;
  static const Color secondaryColor = textSecondary;
  static const Color surfaceColor = backgroundDark;
  static const Color cardColor = backgroundCard;

  // Legacy aliases
  static const Color imdbYellow = accentYellow;
  static const Color rankNumberColor = textSecondary;

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: textPrimary,
      secondary: textPrimary,
      surface: surfaceColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: backgroundDark,
    cardTheme: const CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 28),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: textTertiary, fontSize: 12),
    ),
    iconTheme: const IconThemeData(color: textSecondary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: focusRing, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: textPrimary,
        foregroundColor: backgroundDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: borderMedium),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textPrimary,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: textPrimary,
      inactiveTrackColor: borderMedium,
      thumbColor: textPrimary,
      overlayColor: Color(0x1FEDEDED),
    ),
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textPrimary,
      iconColor: textSecondary,
    ),
  );

  // TV-specific spacing
  static const double tvGridSpacing = 24.0;
  static const double tvCardWidth = 210.0;
  static const double tvCardHeight = 315.0;
  static const double tvRailHeight = 180.0;
  
  // Mobile spacing
  static const double mobileGridSpacing = 12.0;
  static const double mobileCardWidth = 140.0;
  static const double mobileCardHeight = 210.0;
}