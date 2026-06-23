import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════
// THEME IDENTIFIER
// ═══════════════════════════════════════════════
enum AppThemeType {
  midnight,     // Default dark - warm charcoal
  amoled,       // Pure black for AMOLED screens
  slate,        // Cool blue-gray
  midnightBlue, // Deep navy
  forest,       // Dark green tint
  lavender,     // Purple-tinted dark
  rosewood,     // Warm rose-tinted
  light,        // Clean light theme
}

extension AppThemeTypeExtension on AppThemeType {
  String get displayName {
    switch (this) {
      case AppThemeType.midnight:
        return 'Midnight';
      case AppThemeType.amoled:
        return 'AMOLED';
      case AppThemeType.slate:
        return 'Slate';
      case AppThemeType.midnightBlue:
        return 'Midnight Blue';
      case AppThemeType.forest:
        return 'Forest';
      case AppThemeType.lavender:
        return 'Lavender';
      case AppThemeType.rosewood:
        return 'Rosewood';
      case AppThemeType.light:
        return 'Light';
    }
  }

  String get description {
    switch (this) {
      case AppThemeType.midnight:
        return 'Warm charcoal dark';
      case AppThemeType.amoled:
        return 'Pure black for OLED';
      case AppThemeType.slate:
        return 'Cool blue-gray';
      case AppThemeType.midnightBlue:
        return 'Deep navy blue';
      case AppThemeType.forest:
        return 'Dark forest green';
      case AppThemeType.lavender:
        return 'Soft purple dark';
      case AppThemeType.rosewood:
        return 'Warm rose dark';
      case AppThemeType.light:
        return 'Clean and bright';
    }
  }

  Color get previewColor {
    switch (this) {
      case AppThemeType.midnight:
        return const Color(0xFF1C1C1E);
      case AppThemeType.amoled:
        return const Color(0xFF000000);
      case AppThemeType.slate:
        return const Color(0xFF1A1D23);
      case AppThemeType.midnightBlue:
        return const Color(0xFF0F1724);
      case AppThemeType.forest:
        return const Color(0xFF0F1A14);
      case AppThemeType.lavender:
        return const Color(0xFF1C1824);
      case AppThemeType.rosewood:
        return const Color(0xFF1E1618);
      case AppThemeType.light:
        return const Color(0xFFF5F5F7);
    }
  }

  Color get accentPreviewColor {
    switch (this) {
      case AppThemeType.midnight:
        return const Color(0xFF6C63FF);
      case AppThemeType.amoled:
        return const Color(0xFFBB86FC);
      case AppThemeType.slate:
        return const Color(0xFF4FC3F7);
      case AppThemeType.midnightBlue:
        return const Color(0xFF42A5F5);
      case AppThemeType.forest:
        return const Color(0xFF66BB6A);
      case AppThemeType.lavender:
        return const Color(0xFFCE93D8);
      case AppThemeType.rosewood:
        return const Color(0xFFEF9A9A);
      case AppThemeType.light:
        return const Color(0xFF4A90D9);
    }
  }
}

// ═══════════════════════════════════════════════
// THEME DATA MODEL
// ═══════════════════════════════════════════════
class StreameThemeData {
  final AppThemeType type;
  
  // Backgrounds
  final Color backgroundDark;
  final Color backgroundCard;
  final Color backgroundElevated;
  final Color backgroundSheet;
  final Color backgroundOverlay;
  
  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  
  // Borders
  final Color borderLight;
  final Color borderMedium;
  
  // Focus
  final Color focusRing;
  final Color focusGlow;
  
  // Accents
  final Color accentPrimary;
  final Color accentYellow;
  final Color accentGreen;
  final Color accentRed;
  final Color accentCyan;
  
  final Brightness brightness;

  const StreameThemeData({
    required this.type,
    required this.backgroundDark,
    required this.backgroundCard,
    required this.backgroundElevated,
    required this.backgroundSheet,
    required this.backgroundOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.borderLight,
    required this.borderMedium,
    required this.focusRing,
    required this.focusGlow,
    required this.accentPrimary,
    required this.accentYellow,
    required this.accentGreen,
    required this.accentRed,
    required this.accentCyan,
    this.brightness = Brightness.dark,
  });

  bool get isDark => brightness == Brightness.dark;
}

// ═══════════════════════════════════════════════
// THEME DEFINITIONS
// ═══════════════════════════════════════════════
class StreameThemes {
  StreameThemes._();

  // ─── MIDNIGHT (Default) ─── Warm charcoal
  static const midnight = StreameThemeData(
    type: AppThemeType.midnight,
    backgroundDark: Color(0xFF1C1C1E),
    backgroundCard: Color(0xFF2C2C2E),
    backgroundElevated: Color(0xFF3A3A3C),
    backgroundSheet: Color(0xFF2C2C2E),
    backgroundOverlay: Color(0xE61C1C1E),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFB0B0B3),
    textTertiary: Color(0xFF8E8E93),
    textDisabled: Color(0xFF636366),
    borderLight: Color(0x1FFFFFFF),
    borderMedium: Color(0x33FFFFFF),
    focusRing: Color(0xFFF5F5F7),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFF6C63FF),
    accentYellow: Color(0xFFFFD60A),
    accentGreen: Color(0xFF30D158),
    accentRed: Color(0xFFFF453A),
    accentCyan: Color(0xFF64D2FF),
  );

  // ─── AMOLED ─── Pure black for OLED screens
  static const amoled = StreameThemeData(
    type: AppThemeType.amoled,
    backgroundDark: Color(0xFF000000),
    backgroundCard: Color(0xFF0A0A0A),
    backgroundElevated: Color(0xFF141414),
    backgroundSheet: Color(0xFF0A0A0A),
    backgroundOverlay: Color(0xE6000000),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFB0B0B3),
    textTertiary: Color(0xFF8E8E93),
    textDisabled: Color(0xFF636366),
    borderLight: Color(0x1AFFFFFF),
    borderMedium: Color(0x33FFFFFF),
    focusRing: Color(0xFFF5F5F7),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFFBB86FC),
    accentYellow: Color(0xFFFFD60A),
    accentGreen: Color(0xFF30D158),
    accentRed: Color(0xFFFF453A),
    accentCyan: Color(0xFF64D2FF),
  );

  // ─── SLATE ─── Cool blue-gray
  static const slate = StreameThemeData(
    type: AppThemeType.slate,
    backgroundDark: Color(0xFF1A1D23),
    backgroundCard: Color(0xFF252830),
    backgroundElevated: Color(0xFF32363F),
    backgroundSheet: Color(0xFF252830),
    backgroundOverlay: Color(0xE61A1D23),
    textPrimary: Color(0xFFF0F1F5),
    textSecondary: Color(0xFFA8ADB8),
    textTertiary: Color(0xFF7C8290),
    textDisabled: Color(0xFF5C6170),
    borderLight: Color(0x1AFFFFFF),
    borderMedium: Color(0x30FFFFFF),
    focusRing: Color(0xFFF0F1F5),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFF4FC3F7),
    accentYellow: Color(0xFFFFD54F),
    accentGreen: Color(0xFF81C784),
    accentRed: Color(0xFFE57373),
    accentCyan: Color(0xFF4DD0E1),
  );

  // ─── MIDNIGHT BLUE ─── Deep navy
  static const midnightBlue = StreameThemeData(
    type: AppThemeType.midnightBlue,
    backgroundDark: Color(0xFF0F1724),
    backgroundCard: Color(0xFF1A2536),
    backgroundElevated: Color(0xFF243044),
    backgroundSheet: Color(0xFF1A2536),
    backgroundOverlay: Color(0xE60F1724),
    textPrimary: Color(0xFFF0F4FA),
    textSecondary: Color(0xFFA0B0C8),
    textTertiary: Color(0xFF6E80A0),
    textDisabled: Color(0xFF4A5C78),
    borderLight: Color(0x1AFFFFFF),
    borderMedium: Color(0x30FFFFFF),
    focusRing: Color(0xFFF0F4FA),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFF42A5F5),
    accentYellow: Color(0xFFFFCA28),
    accentGreen: Color(0xFF66BB6A),
    accentRed: Color(0xFFEF5350),
    accentCyan: Color(0xFF26C6DA),
  );

  // ─── FOREST ─── Dark green tint
  static const forest = StreameThemeData(
    type: AppThemeType.forest,
    backgroundDark: Color(0xFF0F1A14),
    backgroundCard: Color(0xFF1A2B20),
    backgroundElevated: Color(0xFF24382C),
    backgroundSheet: Color(0xFF1A2B20),
    backgroundOverlay: Color(0xE60F1A14),
    textPrimary: Color(0xFFF0F7F2),
    textSecondary: Color(0xFFA0C8B0),
    textTertiary: Color(0xFF6EA88A),
    textDisabled: Color(0xFF4A7860),
    borderLight: Color(0x1AFFFFFF),
    borderMedium: Color(0x30FFFFFF),
    focusRing: Color(0xFFF0F7F2),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFF66BB6A),
    accentYellow: Color(0xFFFFCA28),
    accentGreen: Color(0xFF81C784),
    accentRed: Color(0xFFEF5350),
    accentCyan: Color(0xFF4DD0E1),
  );

  // ─── LAVENDER ─── Soft purple dark
  static const lavender = StreameThemeData(
    type: AppThemeType.lavender,
    backgroundDark: Color(0xFF1C1824),
    backgroundCard: Color(0xFF2C2636),
    backgroundElevated: Color(0xFF3A3444),
    backgroundSheet: Color(0xFF2C2636),
    backgroundOverlay: Color(0xE61C1824),
    textPrimary: Color(0xFFF5F0FA),
    textSecondary: Color(0xFFB0A8C0),
    textTertiary: Color(0xFF8A80A0),
    textDisabled: Color(0xFF605878),
    borderLight: Color(0x1AFFFFFF),
    borderMedium: Color(0x30FFFFFF),
    focusRing: Color(0xFFF5F0FA),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFFCE93D8),
    accentYellow: Color(0xFFFFCA28),
    accentGreen: Color(0xFF81C784),
    accentRed: Color(0xFFEF5350),
    accentCyan: Color(0xFF80DEEA),
  );

  // ─── ROSEWOOD ─── Warm rose-tinted
  static const rosewood = StreameThemeData(
    type: AppThemeType.rosewood,
    backgroundDark: Color(0xFF1E1618),
    backgroundCard: Color(0xFF302428),
    backgroundElevated: Color(0xFF3E3036),
    backgroundSheet: Color(0xFF302428),
    backgroundOverlay: Color(0xE61E1618),
    textPrimary: Color(0xFFF8F0F2),
    textSecondary: Color(0xFFC0A8B0),
    textTertiary: Color(0xFF9A8088),
    textDisabled: Color(0xFF705860),
    borderLight: Color(0x1AFFFFFF),
    borderMedium: Color(0x30FFFFFF),
    focusRing: Color(0xFFF8F0F2),
    focusGlow: Color(0x1A000000),
    accentPrimary: Color(0xFFEF9A9A),
    accentYellow: Color(0xFFFFCA28),
    accentGreen: Color(0xFF81C784),
    accentRed: Color(0xFFEF5350),
    accentCyan: Color(0xFF80DEEA),
  );

  // ─── LIGHT ─── Clean bright
  static const light = StreameThemeData(
    type: AppThemeType.light,
    backgroundDark: Color(0xFFF5F5F7),
    backgroundCard: Color(0xFFFFFFFF),
    backgroundElevated: Color(0xFFF0F0F2),
    backgroundSheet: Color(0xFFFFFFFF),
    backgroundOverlay: Color(0xE6F5F5F7),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF6E6E73),
    textTertiary: Color(0xFFAEAEB2),
    textDisabled: Color(0xFFC7C7CC),
    borderLight: Color(0x1A000000),
    borderMedium: Color(0x30000000),
    focusRing: Color(0xFF1D1D1F),
    focusGlow: Color(0x0D000000),
    accentPrimary: Color(0xFF4A90D9),
    accentYellow: Color(0xFFFF9500),
    accentGreen: Color(0xFF34C759),
    accentRed: Color(0xFFFF3B30),
    accentCyan: Color(0xFF5AC8FA),
    brightness: Brightness.light,
  );

  static StreameThemeData getTheme(AppThemeType type) {
    switch (type) {
      case AppThemeType.midnight:
        return midnight;
      case AppThemeType.amoled:
        return amoled;
      case AppThemeType.slate:
        return slate;
      case AppThemeType.midnightBlue:
        return midnightBlue;
      case AppThemeType.forest:
        return forest;
      case AppThemeType.lavender:
        return lavender;
      case AppThemeType.rosewood:
        return rosewood;
      case AppThemeType.light:
        return light;
    }
  }

  static ThemeData toFlutterTheme(StreameThemeData theme) {
    return ThemeData(
      useMaterial3: true,
      brightness: theme.brightness,
      colorScheme: ColorScheme(
        brightness: theme.brightness,
        primary: theme.accentPrimary,
        onPrimary: theme.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        secondary: theme.accentPrimary,
        onSecondary: theme.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        surface: theme.backgroundCard,
        onSurface: theme.textPrimary,
        error: theme.accentRed,
        onError: const Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: theme.backgroundDark,
      cardTheme: CardThemeData(
        color: theme.backgroundCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: theme.backgroundDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: theme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
        headlineMedium: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 28),
        titleLarge: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        titleMedium: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: TextStyle(color: theme.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: theme.textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: theme.textTertiary, fontSize: 12),
      ),
      iconTheme: IconThemeData(color: theme.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: theme.backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.accentPrimary, width: 1.5),
        ),
        labelStyle: TextStyle(color: theme.textSecondary),
        hintStyle: TextStyle(color: theme.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentPrimary,
          foregroundColor: theme.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.textPrimary,
          side: BorderSide(color: theme.borderMedium),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: theme.textPrimary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: theme.accentPrimary,
        inactiveTrackColor: theme.borderMedium,
        thumbColor: theme.textPrimary,
        overlayColor: theme.accentPrimary.withValues(alpha: 0.1),
      ),
      dividerTheme: DividerThemeData(color: theme.borderLight, thickness: 1),
      listTileTheme: ListTileThemeData(textColor: theme.textPrimary, iconColor: theme.textSecondary),
    );
  }
}

// ═══════════════════════════════════════════════
// COMPATIBILITY LAYER — Uses active theme
// ═══════════════════════════════════════════════
// Static accessors that read from AppTheme.current
class AppTheme {
  AppTheme._();

  static StreameThemeData _current = StreameThemes.midnight;
  
  static StreameThemeData get current => _current;
  
  static void setCurrent(StreameThemeData theme) {
    _current = theme;
  }

  // Convenience accessors for backward compatibility
  static Color get backgroundDark => _current.backgroundDark;
  static Color get backgroundCard => _current.backgroundCard;
  static Color get backgroundElevated => _current.backgroundElevated;
  static Color get backgroundSheet => _current.backgroundSheet;
  static Color get backgroundOverlay => _current.backgroundOverlay;
  
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textTertiary => _current.textTertiary;
  static Color get textDisabled => _current.textDisabled;
  
  static Color get borderLight => _current.borderLight;
  static Color get borderMedium => _current.borderMedium;
  
  static Color get focusRing => _current.focusRing;
  static Color get focusGlow => _current.focusGlow;
  
  static Color get accentPrimary => _current.accentPrimary;
  static Color get accentYellow => _current.accentYellow;
  static Color get accentGreen => _current.accentGreen;
  static Color get accentRed => _current.accentRed;
  static Color get accentCyan => _current.accentCyan;
  
  static Color get primaryColor => _current.textPrimary;
  static Color get secondaryColor => _current.textSecondary;
  static Color get surfaceColor => _current.backgroundDark;
  static Color get cardColor => _current.backgroundCard;
  static Color get imdbYellow => _current.accentYellow;

  // Legacy aliases used by player & other screens
  static Color get arcticWhite12 => _current.textPrimary.withValues(alpha: 0.12);
  static Color get arcticWhite30 => _current.textPrimary.withValues(alpha: 0.30);
  static Color get errorColor => _current.accentRed;

  static ThemeData get darkTheme => StreameThemes.toFlutterTheme(_current);

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
