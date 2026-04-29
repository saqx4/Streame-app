import 'package:flutter/material.dart';
import 'package:streame_core/utils/app_theme.dart';

/// Unified player design system — clean, modern, minimal.
/// Shared primitives for both mobile and desktop players.

// ── Icon Button ──────────────────────────────────────────────────────────────

class PlayerBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final bool active;
  final String? tooltip;

  const PlayerBtn({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 18,
    this.color,
    this.active = false,
    this.tooltip,
  });

  @override
  State<PlayerBtn> createState() => _PlayerBtnState();
}

class _PlayerBtnState extends State<PlayerBtn> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: widget.tooltip ?? '',
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
            color: widget.active
                ? AppTheme.current.primaryColor.withValues(alpha: 0.3)
                : _pressed
                    ? Colors.white.withValues(alpha: 0.2)
                    : _hovered && isDesktop
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.size * 0.5),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.active
                ? AppTheme.current.primaryColor
                : widget.color ?? Colors.white,
          ),
          ),
        ),
      ),
    );
  }
}

// ── Pill Button ──────────────────────────────────────────────────────────────

class PlayerPill extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? accent;
  final double fontSize;

  const PlayerPill({
    super.key,
    required this.text,
    this.onTap,
    this.accent,
    this.fontSize = 11,
  });

  @override
  State<PlayerPill> createState() => _PlayerPillState();
}

class _PlayerPillState extends State<PlayerPill> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final accent = widget.accent ?? AppTheme.current.primaryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.fontSize * 1.1 + 6,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: _pressed
                ? accent.withValues(alpha: 0.35)
                : _hovered && isDesktop
                    ? accent.withValues(alpha: 0.25)
                    : accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Center Play/Pause ────────────────────────────────────────────────────────

class PlayerPlayPause extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final int bufferPct; // 0–100
  final VoidCallback onPressed;
  final double size;

  const PlayerPlayPause({
    super.key,
    required this.isPlaying,
    required this.isBuffering,
    this.bufferPct = 0,
    required this.onPressed,
    this.size = 56,
  });

  @override
  State<PlayerPlayPause> createState() => _PlayerPlayPauseState();
}

class _PlayerPlayPauseState extends State<PlayerPlayPause>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    lowerBound: 0.85,
    upperBound: 1.0,
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _controller.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _controller.forward();
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _controller.forward();
      },
      child: ScaleTransition(
        scale: _controller,
        child: Container(
          width: widget.isBuffering ? widget.size * 1.5 : widget.size * 1.5,
          height: widget.isBuffering ? widget.size * 1.5 : widget.size * 1.5,
          decoration: BoxDecoration(
            color: _pressed ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: widget.isBuffering
              ? Center(
                  child: SizedBox(
                    width: widget.size * 1.2,
                    height: widget.size * 1.2,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: AppTheme.current.primaryColor,
                    ),
                  ),
                )
              : Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: widget.size * 1.2,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

// ── Bottom Gradient ──────────────────────────────────────────────────────────

class PlayerBottomGradient extends StatelessWidget {
  final double height;
  const PlayerBottomGradient({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top Gradient ─────────────────────────────────────────────────────────────

class PlayerTopGradient extends StatelessWidget {
  final double height;
  const PlayerTopGradient({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inline Toast ─────────────────────────────────────────────────────────────

class PlayerToast extends StatelessWidget {
  final String message;
  const PlayerToast({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Skip Segment Chip ────────────────────────────────────────────────────────

class PlayerSkipChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const PlayerSkipChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.current.primaryColor, AppTheme.current.primaryColor.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(width: 6),
            const Icon(Icons.skip_next_rounded, color: Colors.white, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ── Next Episode Chip ────────────────────────────────────────────────────────

class PlayerNextChip extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const PlayerNextChip({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.current.primaryColor, AppTheme.current.primaryColor.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              const Text('Next Episode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ── Side Indicator (Volume/Brightness) ───────────────────────────────────────

class SideIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
  const SideIndicator({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            width: 4,
            height: 80,
            color: Colors.white.withValues(alpha: 0.2),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 80 * value.clamp(0.0, 1.0),
                color: AppTheme.current.primaryColor,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Time Label ───────────────────────────────────────────────────────────────

class PlayerTimeLabel extends StatelessWidget {
  final String text;
  final TextAlign align;
  const PlayerTimeLabel({super.key, required this.text, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
        textAlign: align,
      ),
    );
  }
}
