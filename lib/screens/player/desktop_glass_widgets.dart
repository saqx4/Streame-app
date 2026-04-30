import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLASSY WIDGET PRIMITIVES  (MPVEx-style frosted black glass)
// ─────────────────────────────────────────────────────────────────────────────

/// A clean frosted container – the visual base for every button / chip.
/// [hovered] brightens slightly for desktop hover feedback.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool hovered;

  const Glass({super.key, 
    required this.child,
    this.radius = 12,
    this.padding,
    this.tint,
    this.hovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final fillOpacity = hovered ? 0.82 : 0.68;
    final borderOpacity = hovered ? 0.22 : 0.10;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (tint ?? const Color(0xFF1C1C1E)).withValues(alpha: fillOpacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

/// Glassy icon button with hover + press feedback (Windows-friendly).
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool active;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 18,
    this.iconColor,
    this.active = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _tint {
    if (widget.active) return const Color(0xFFE50914);
    if (_pressed)      return const Color(0xFF2A2A2E);
    return const Color(0xFF1C1C1E);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Glass(
            radius: widget.size / 2,
            tint: _tint,
            hovered: _hovered,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.iconColor ??
                    (widget.active
                        ? Colors.white
                        : _hovered
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.80)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassy pill / chip button with hover + press feedback.
class GlassPillButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color? accent;

  const GlassPillButton({
    super.key,
    required this.text,
    required this.onTap,
    this.accent,
  });

  @override
  State<GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<GlassPillButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Glass(
            radius: 20,
            tint: widget.accent ?? const Color(0xFF1C1C1E),
            hovered: _hovered,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.accent != null
                    ? Colors.white
                    : _hovered
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Center play/pause big button with hover + press feedback.
class GlassPlayPause extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  const GlassPlayPause({super.key, 
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  @override
  State<GlassPlayPause> createState() => _GlassPlayPauseState();
}

class _GlassPlayPauseState extends State<GlassPlayPause> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isBuffering) {
      return const Glass(
        radius: 32,
        hovered: false,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFFE50914),
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.90 : (_hovered ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: Glass(
            radius: 32,
            hovered: _hovered,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(
                widget.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient overlay at top or bottom of the video — lighter, more subtle
class OverlayGradient extends StatelessWidget {
  final bool isTop;
  const OverlayGradient({super.key, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}