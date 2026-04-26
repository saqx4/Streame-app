import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MOVIE ATMOSPHERE SYSTEM
//  Extracts palette → animates backdrop → spawns genre particles → glows poster
// ═══════════════════════════════════════════════════════════════════════════════

/// Extracted palette colors for a movie, used across the atmosphere system.
class AtmosphereColors {
  final Color dominant;
  final Color vibrant;
  final Color muted;
  final Color accent;

  const AtmosphereColors({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.accent,
  });

  static const fallback = AtmosphereColors(
    dominant: Color(0xFF7C4DFF),
    vibrant: Color(0xFF00E5FF),
    muted: Color(0xFF2A2A3E),
    accent: Color(0xFF7C4DFF),
  );
}

/// Extracts the dominant palette from a movie poster/backdrop URL.
Future<AtmosphereColors> extractAtmosphereColors(String imageUrl) async {
  try {
    final generator = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(imageUrl),
      size: const Size(100, 150), // small for speed
      maximumColorCount: 8,
    );

    final dominant = generator.dominantColor?.color ?? const Color(0xFF7C4DFF);
    final vibrant = generator.vibrantColor?.color ?? generator.lightVibrantColor?.color ?? dominant;
    final muted = generator.mutedColor?.color ?? generator.darkMutedColor?.color ?? const Color(0xFF2A2A3E);
    final accent = generator.lightVibrantColor?.color ?? generator.vibrantColor?.color ?? vibrant;

    return AtmosphereColors(
      dominant: dominant,
      vibrant: vibrant,
      muted: muted,
      accent: accent,
    );
  } catch (_) {
    return AtmosphereColors.fallback;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  KEN BURNS BACKDROP — slow cinematic pan & zoom
// ═══════════════════════════════════════════════════════════════════════════════

class KenBurnsBackdrop extends StatefulWidget {
  final String imageUrl;
  final AtmosphereColors? colors;
  final double blurSigma;

  const KenBurnsBackdrop({
    super.key,
    required this.imageUrl,
    this.colors,
    this.blurSigma = 28,
  });

  @override
  State<KenBurnsBackdrop> createState() => _KenBurnsBackdropState();
}

class _KenBurnsBackdropState extends State<KenBurnsBackdrop> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Alignment> _alignAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _alignAnimation = AlignmentTween(
      begin: const Alignment(-0.2, -0.1),
      end: const Alignment(0.2, 0.1),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated backdrop
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              alignment: _alignAnimation.value,
              child: child,
            );
          },
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            memCacheWidth: 800,
            errorWidget: (c, u, e) => Container(color: const Color(0xFF05050A)),
          ),
        ),

        // Deep gradient overlay - Indigo/Black cinematic blend
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (colors?.dominant ?? const Color(0xFF05050A)).withValues(alpha: 0.5),
                const Color(0xFF05050A).withValues(alpha: 0.8),
                const Color(0xFF05050A),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GENRE PARTICLES — DISABLED FOR PERFORMANCE
// ═══════════════════════════════════════════════════════════════════════════════

class GenreParticles extends StatelessWidget {
  final List<String> genres;
  final AtmosphereColors? colors;

  const GenreParticles({super.key, required this.genres, this.colors});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Clean look, zero CPU impact
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  POSTER FRAME — Sleek static glow
// ═══════════════════════════════════════════════════════════════════════════════

class PosterGlow extends StatelessWidget {
  final Widget child;
  final AtmosphereColors? colors;
  final List<String> genres;
  final double width;
  final double height;
  final double borderRadius;

  const PosterGlow({
    super.key,
    required this.child,
    this.colors,
    this.genres = const [],
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = colors?.vibrant ?? const Color(0xFF6366F1);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

// Border painter removed as we use simple BoxDecoration for better performance


// ═══════════════════════════════════════════════════════════════════════════════
//  ATMOSPHERE MIXIN — add to any details screen state
// ═══════════════════════════════════════════════════════════════════════════════

/// Helper to build the full atmosphere backdrop (Ken Burns + particles + tint).
/// Call [loadAtmosphere] in initState after _movie is set.
mixin AtmosphereMixin<T extends StatefulWidget> on State<T> {
  AtmosphereColors? atmosphereColors;

  Future<void> loadAtmosphere(String imageUrl) async {
    final colors = await extractAtmosphereColors(imageUrl);
    if (mounted) {
      setState(() => atmosphereColors = colors);
    }
  }

  /// Build the full atmosphere backdrop layer for a Stack.
  Widget buildAtmosphereBackdrop({
    required String imageUrl,
    required List<String> genres,
    double blurSigma = 28,
  }) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          KenBurnsBackdrop(
            imageUrl: imageUrl,
            colors: atmosphereColors,
            blurSigma: blurSigma,
          ),
          IgnorePointer(
            child: GenreParticles(
              genres: genres,
              colors: atmosphereColors,
            ),
          ),
        ],
      ),
    );
  }

  /// Wrap a poster widget with the breathing glow + genre border.
  Widget wrapPosterGlow({
    required Widget child,
    required double width,
    required double height,
    double borderRadius = 12,
    List<String> genres = const [],
  }) {
    return PosterGlow(
      colors: atmosphereColors,
      genres: genres,
      width: width,
      height: height,
      borderRadius: borderRadius,
      child: child,
    );
  }
}
