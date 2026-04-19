import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import '../../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLASSY WIDGET PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// A clean frosted container – the visual base for every button / chip.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool hovered;

  const Glass({
    super.key,
    required this.child,
    this.radius = 12,
    this.padding,
    this.tint,
    this.hovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final fillOpacity = hovered ? 0.65 : 0.45;
    final borderOpacity = hovered ? 0.22 : 0.10;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
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
        ),
      ),
    );
  }
}

/// Glassy icon button with hover + press feedback
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
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: Glass(
          radius: widget.size / 2,
          hovered: _isHovered,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.iconColor ??
                  (widget.active ? AppTheme.primaryColor : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassy pill button
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Glass(
          radius: 20,
          hovered: _isHovered,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.accent != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay gradient vignettes
class OverlayGradient extends StatelessWidget {
  final bool isTop;

  const OverlayGradient({super.key, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment(0, 0.3) : Alignment(0, -0.3),
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Center play/pause button
class GlassPlayPause extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  const GlassPlayPause({
    super.key,
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Glass(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Icon(
            isBuffering
                ? Icons.hourglass_empty
                : isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Custom seek bar
class CustomSeekBar extends StatefulWidget {
  final Player player;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration?> durationNotifier;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  final Function(Duration) onSeek;

  const CustomSeekBar({
    super.key,
    required this.player,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.onSeek,
  });

  @override
  State<CustomSeekBar> createState() => _CustomSeekBarState();
}

class _CustomSeekBarState extends State<CustomSeekBar> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Container(
          height: 20,
          alignment: Alignment.center,
          child: ValueListenableBuilder<Duration?>(
            valueListenable: widget.durationNotifier,
            builder: (context, duration, _) {
              return ValueListenableBuilder<Duration>(
                valueListenable: widget.positionNotifier,
                builder: (context, position, _) {
                  final total = duration ?? Duration.zero;
                  final progress = total.inMilliseconds > 0
                      ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0;
                  final displayProgress = _isDragging ? _dragValue : progress;

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Background track
                      Container(
                        height: _isHovered || _isDragging ? 5 : 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      // Progress track
                      FractionallySizedBox(
                        widthFactor: displayProgress,
                        child: Container(
                          height: _isHovered || _isDragging ? 5 : 3,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Handle
                      if (_isHovered || _isDragging)
                        Positioned(
                          left: (displayProgress * 300) - 6,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isDragging = true;
      _dragValue = details.localPosition.dx / 300;
    });
    widget.onSeekStart();
  }

  void _onTapUp(TapUpDetails details) {
    final duration = widget.player.state.duration;
    if (duration != null) {
      final newPosition = Duration(
        milliseconds: (duration.inMilliseconds * _dragValue).round(),
      );
      widget.onSeek(newPosition);
    }
    setState(() {
      _isDragging = false;
    });
    widget.onSeekEnd();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragValue = details.localPosition.dx / 300;
    });
    widget.onSeekStart();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragValue = (details.localPosition.dx / 300).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final duration = widget.player.state.duration;
    if (duration != null) {
      final newPosition = Duration(
        milliseconds: (duration.inMilliseconds * _dragValue).round(),
      );
      widget.onSeek(newPosition);
    }
    setState(() {
      _isDragging = false;
    });
    widget.onSeekEnd();
  }
}

/// Volume slider
class VolumeSlider extends StatefulWidget {
  final double volume;
  final Function(double) onVolumeChanged;

  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Glass(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.volume == 0 ? Icons.volume_off : Icons.volume_up,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Slider(
                value: widget.volume,
                onChanged: widget.onVolumeChanged,
                activeColor: AppTheme.primaryColor,
                inactiveColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
