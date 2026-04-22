import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/settings_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — spacing, radius, durations, elevations
// ═══════════════════════════════════════════════════════════════════════════

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

class AppRadius {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
  static const double pill = 100.0;
}

class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration crawl = Duration(milliseconds: 800);
}

class AppElevations {
  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 3.0;
  static const double level3 = 8.0;
  static const double level4 = 16.0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  THEME PRESET — full color palette per theme
// ═══════════════════════════════════════════════════════════════════════════

class AppThemePreset {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  // Core colors
  final Color bgDark;
  final Color bgCard;
  final Color primaryColor;
  final Color accentColor;
  final Color gradientTint;

  // Surface hierarchy (Netflix-inspired layering)
  final Color surfaceDim;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;

  // Text hierarchy
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // Functional
  final Color border;
  final Color borderStrong;
  final Color overlay;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.bgDark,
    required this.bgCard,
    required this.primaryColor,
    required this.accentColor,
    required this.gradientTint,
    required this.surfaceDim,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.overlay,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  BoxDecoration get backgroundDecoration => BoxDecoration(
    color: bgDark,
    gradient: RadialGradient(
      center: Alignment.topCenter,
      radius: 1.5,
      colors: [gradientTint, bgDark],
      stops: const [0.0, 0.7],
    ),
  );

  BoxDecoration get backgroundDecorationFlat => BoxDecoration(color: bgDark);
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP THEME — global design system
// ═══════════════════════════════════════════════════════════════════════════

class AppTheme {
  // ── Theme Presets ────────────────────────────────────────────────────────

  static const List<AppThemePreset> presets = [
    AppThemePreset(
      id: 'cinematic',
      name: 'Midnight Cinematic',
      description: 'Deep indigo & violet — professional and sleek',
      icon: Icons.movie_filter,
      bgDark: Color(0xFF0A0A0F),
      bgCard: Color(0xFF161622),
      primaryColor: Color(0xFF6366F1),
      accentColor: Color(0xFF8B5CF6),
      gradientTint: Color(0xFF10101C),
      surfaceDim: Color(0xFF0E0E18),
      surface: Color(0xFF161622),
      surfaceBright: Color(0xFF1E1E2E),
      surfaceContainer: Color(0xFF1A1A28),
      surfaceContainerHigh: Color(0xFF22223A),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF1A1A28),
      shimmerHighlight: Color(0xFF2A2A3E),
    ),
    AppThemePreset(
      id: 'midnight',
      name: 'Obsidian',
      description: 'Pure AMOLED black — sleek and minimal',
      icon: Icons.dark_mode,
      bgDark: Color(0xFF000000),
      bgCard: Color(0xFF0D0D0D),
      primaryColor: Color(0xFFB0B0B0),
      accentColor: Color(0xFF4A4A4A),
      gradientTint: Color(0xFF0A0A0A),
      surfaceDim: Color(0xFF080808),
      surface: Color(0xFF0D0D0D),
      surfaceBright: Color(0xFF151515),
      surfaceContainer: Color(0xFF111111),
      surfaceContainerHigh: Color(0xFF1A1A1A),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF111111),
      shimmerHighlight: Color(0xFF1E1E1E),
    ),
    AppThemePreset(
      id: 'royal_purple',
      name: 'Royal Purple',
      description: 'Deep purple with hot pink sparks',
      icon: Icons.auto_awesome,
      bgDark: Color(0xFF0D0518),
      bgCard: Color(0xFF170B28),
      primaryColor: Color(0xFFBB86FC),
      accentColor: Color(0xFFE91E63),
      gradientTint: Color(0xFF1A0B2E),
      surfaceDim: Color(0xFF120820),
      surface: Color(0xFF170B28),
      surfaceBright: Color(0xFF200E38),
      surfaceContainer: Color(0xFF1C0C30),
      surfaceContainerHigh: Color(0xFF261042),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF1C0C30),
      shimmerHighlight: Color(0xFF2E1848),
    ),
    AppThemePreset(
      id: 'crimson',
      name: 'Crimson',
      description: 'Dark and intense — blood red energy',
      icon: Icons.local_fire_department,
      bgDark: Color(0xFF0C0404),
      bgCard: Color(0xFF1A0A0A),
      primaryColor: Color(0xFFFF1744),
      accentColor: Color(0xFFFF6D00),
      gradientTint: Color(0xFF1E0808),
      surfaceDim: Color(0xFF120606),
      surface: Color(0xFF1A0A0A),
      surfaceBright: Color(0xFF241010),
      surfaceContainer: Color(0xFF1E0C0C),
      surfaceContainerHigh: Color(0xFF2E1414),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF1E0C0C),
      shimmerHighlight: Color(0xFF321818),
    ),
    AppThemePreset(
      id: 'ocean',
      name: 'Ocean',
      description: 'Deep navy tones with teal highlights',
      icon: Icons.water,
      bgDark: Color(0xFF040D14),
      bgCard: Color(0xFF0A1520),
      primaryColor: Color(0xFF00BCD4),
      accentColor: Color(0xFF26C6DA),
      gradientTint: Color(0xFF0B1929),
      surfaceDim: Color(0xFF081018),
      surface: Color(0xFF0A1520),
      surfaceBright: Color(0xFF0E1C2C),
      surfaceContainer: Color(0xFF0C1824),
      surfaceContainerHigh: Color(0xFF122232),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF0C1824),
      shimmerHighlight: Color(0xFF162438),
    ),
    AppThemePreset(
      id: 'emerald',
      name: 'Emerald',
      description: 'Dark forest vibes with neon green',
      icon: Icons.park,
      bgDark: Color(0xFF040D08),
      bgCard: Color(0xFF0A1A10),
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFF69F0AE),
      gradientTint: Color(0xFF0B1E12),
      surfaceDim: Color(0xFF08120A),
      surface: Color(0xFF0A1A10),
      surfaceBright: Color(0xFF0E2216),
      surfaceContainer: Color(0xFF0C1E12),
      surfaceContainerHigh: Color(0xFF142C1A),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF0C1E12),
      shimmerHighlight: Color(0xFF163020),
    ),
    AppThemePreset(
      id: 'sunset',
      name: 'Sunset',
      description: 'Warm amber tones with golden glow',
      icon: Icons.wb_twilight,
      bgDark: Color(0xFF0F0804),
      bgCard: Color(0xFF1A1008),
      primaryColor: Color(0xFFFFAB00),
      accentColor: Color(0xFFFF6D00),
      gradientTint: Color(0xFF1E150A),
      surfaceDim: Color(0xFF140C06),
      surface: Color(0xFF1A1008),
      surfaceBright: Color(0xFF221610),
      surfaceContainer: Color(0xFF1E120A),
      surfaceContainerHigh: Color(0xFF2C1C12),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB0FFFFFF),
      textDisabled: Color(0x60FFFFFF),
      border: Color(0x1AFFFFFF),
      borderStrong: Color(0x33FFFFFF),
      overlay: Color(0x99000000),
      shimmerBase: Color(0xFF1E120A),
      shimmerHighlight: Color(0xFF302014),
    ),
  ];

  /// Notifier that broadcasts the current theme preset.
  static final ValueNotifier<AppThemePreset> themeNotifier =
      ValueNotifier<AppThemePreset>(presets.first);

  /// Current active preset (shorthand).
  static AppThemePreset get current => themeNotifier.value;

  // ── Backward-compatible const accessors ──────────────────────────────────
  // These always return the default cinematic theme colors.
  // For theme-aware colors, use Theme.of(context).colorScheme or AppTheme.current.

  /// Default primary color (const). For dynamic theme color, use `current.primaryColor`.
  static const Color primaryColor = Color(0xFF6366F1);
  /// Default accent color (const). For dynamic theme color, use `current.accentColor`.
  static const Color accentColor = Color(0xFF8B5CF6);

  static Color get bgDark => current.bgDark;
  static Color get bgCard => current.bgCard;

  // ── Dynamic color accessors (theme-aware) ────────────────────────────────

  static Color get surfaceDim => current.surfaceDim;
  static Color get surface => current.surface;
  static Color get surfaceBright => current.surfaceBright;
  static Color get surfaceContainer => current.surfaceContainer;
  static Color get surfaceContainerHigh => current.surfaceContainerHigh;
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textDisabled => current.textDisabled;
  static Color get border => current.border;
  static Color get borderStrong => current.borderStrong;
  static Color get overlay => current.overlay;
  static Color get shimmerBase => current.shimmerBase;
  static Color get shimmerHighlight => current.shimmerHighlight;

  /// Whether light mode is currently active (cached from notifier).
  static bool get isLightMode => SettingsService.lightModeNotifier.value;

  static BoxDecoration get backgroundDecoration => current.backgroundDecoration;
  static BoxDecoration get backgroundDecorationFlat => current.backgroundDecorationFlat;

  /// Returns the correct background based on light mode state.
  static BoxDecoration get effectiveBackground =>
      isLightMode ? backgroundDecorationFlat : backgroundDecoration;

  // ── Reusable gradient helpers ────────────────────────────────────────────

  /// Bottom fade for hero banners and cards (transparent → bgDark).
  static LinearGradient bottomFade([double start = 0.4]) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      bgDark.withValues(alpha: 0.2),
      bgDark.withValues(alpha: 0.85),
      bgDark,
    ],
    stops: [0.0, start, 0.8, 1.0],
  );

  /// Left fade for text readability on desktop hero banners.
  static LinearGradient leftFade() => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [bgDark.withValues(alpha: 0.85), Colors.transparent],
    stops: const [0.0, 0.5],
  );

  // ── Theme Data ───────────────────────────────────────────────────────────

  static ThemeData get themeData {
    final p = current;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.bgDark,
      primaryColor: p.primaryColor,
      colorScheme: ColorScheme.dark(
        primary: p.primaryColor,
        secondary: p.accentColor,
        surface: p.surface,
        onSurface: p.textPrimary,
        surfaceContainerHighest: p.surfaceContainerHigh,
        surfaceDim: p.surfaceDim,
        surfaceBright: p.surfaceBright,
        surfaceContainer: p.surfaceContainer,
        outline: p.border,
        outlineVariant: p.borderStrong,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: p.textPrimary, height: 1.1),
        displayMedium: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.textPrimary, height: 1.15),
        displaySmall: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: p.textPrimary, height: 1.2),
        headlineLarge: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: p.textPrimary),
        headlineMedium: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: p.textPrimary),
        headlineSmall: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
        titleLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: p.textPrimary),
        titleMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
        titleSmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: p.textSecondary),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: p.textSecondary),
        bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: p.textDisabled),
        labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
        labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: p.textSecondary),
        labelSmall: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: p.textDisabled),
      ),
      iconTheme: IconThemeData(color: p.textSecondary, size: 24),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceContainer,
        selectedColor: p.primaryColor.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: p.textSecondary),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderStrong, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          backgroundColor: p.overlay.withValues(alpha: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryColor,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceContainer,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: p.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceContainerHigh,
        contentTextStyle: GoogleFonts.poppins(fontSize: 13, color: p.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: GoogleFonts.poppins(fontSize: 12, color: p.textPrimary),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.borderStrong.withValues(alpha: 0.5)),
        radius: const Radius.circular(4),
        thickness: WidgetStatePropertyAll(6),
        thumbVisibility: WidgetStatePropertyAll(false),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Hydrate the current theme from saved settings at app startup.
  static Future<void> initTheme() async {
    final id = await SettingsService().getThemePreset();
    final match = presets.where((p) => p.id == id);
    if (match.isNotEmpty) {
      themeNotifier.value = match.first;
    }
  }

  /// Change the theme and persist the choice.
  static Future<void> setPreset(String id) async {
    final match = presets.where((p) => p.id == id);
    if (match.isNotEmpty) {
      themeNotifier.value = match.first;
      await SettingsService().setThemePreset(id);
    }
  }
}

class FocusableControl extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autoFocus;
  final double borderRadius;
  final Color? glowColor;
  final double scaleOnFocus;

  const FocusableControl({
    super.key,
    required this.child,
    this.onTap,
    this.autoFocus = false,
    this.borderRadius = 12.0,
    this.glowColor,
    this.scaleOnFocus = 1.0, 
  });

  @override
  State<FocusableControl> createState() => _FocusableControlState();
}

class _FocusableControlState extends State<FocusableControl> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: widget.scaleOnFocus).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateState(bool active) {
    if (active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (f) {
        setState(() => _isFocused = f);
        _updateState(f || _isHovered);
      },
      onKeyEvent: (node, event) {
        if (widget.onTap != null && event is KeyDownEvent && 
           (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
             widget.onTap!(); 
             return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _updateState(true);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _updateState(_isFocused);
        },
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: (_isFocused || _isHovered) 
                    ? (widget.glowColor ?? AppTheme.primaryColor).withValues(alpha: 0.8)
                    : Colors.transparent,
                  width: 2.0,
                ),
                color: (_isFocused || _isHovered)
                  ? (widget.glowColor ?? AppTheme.primaryColor).withValues(alpha: 0.1)
                  : Colors.transparent,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

