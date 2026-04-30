import 'package:flutter/material.dart';
import 'utils.dart' show formatDuration;
import 'mobile_glass_widgets.dart';

class MobileSeekbar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const MobileSeekbar({super.key, 
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<MobileSeekbar> createState() => _MobileSeekbarState();
}

class _MobileSeekbarState extends State<MobileSeekbar> {
  bool _isDragging = false;
  double _dragFrac = 0.0;
  double _trackWidth = 0.0;

  static const Color _accentColor = Color(0xFFE50914); // Netflix red

  double get _playFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    if (_isDragging) return _dragFrac;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get _bufFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    return (widget.bufferedPosition.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _dragTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_dragFrac * total).round());
  }

  double _fracFromLocal(double dx) =>
      (dx / _trackWidth).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        widget.onDragStart();
        setState(() {
          _isDragging = true;
          _dragFrac = _fracFromLocal(d.localPosition.dx);
        });
      },
      onHorizontalDragUpdate: (d) => setState(() {
        _dragFrac = _fracFromLocal(d.localPosition.dx);
      }),
      onHorizontalDragEnd: (_) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(
            Duration(milliseconds: (_dragFrac * total).round()));
        widget.onDragEnd();
        setState(() => _isDragging = false);
      },
      onTapUp: (d) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(Duration(
            milliseconds:
                (_fracFromLocal(d.localPosition.dx) * total).round()));
      },
      // 32px tall hit area — much easier to grab on touch
      child: SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.center,
          child: LayoutBuilder(builder: (context, constraints) {
            _trackWidth = constraints.maxWidth;

            final trackH = _isDragging ? 5.0 : 3.0;
            final thumbR = _isDragging ? 7.0 : 5.0;
            final playPx =
                (_playFrac * _trackWidth).clamp(0.0, _trackWidth);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: trackH,
                  width: _trackWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(trackH),
                  ),
                ),
                // Buffered
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: trackH,
                  width: (_bufFrac * _trackWidth).clamp(0.0, _trackWidth),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(trackH),
                  ),
                ),
                // Played — purple accent
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  height: trackH,
                  width: playPx,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(trackH),
                  ),
                ),
                // Thumb dot — always visible (Netflix-style)
                Positioned(
                  left: playPx - thumbR,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: thumbR * 2,
                    height: thumbR * 2,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                      boxShadow: _isDragging ? [
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.50),
                          blurRadius: 8,
                        ),
                      ] : null,
                    ),
                  ),
                ),
                // Drag time label — floats above thumb while dragging
                if (_isDragging &&
                    widget.duration.inMilliseconds > 0)
                  Positioned(
                    left: (playPx - 36).clamp(
                        0.0, _trackWidth - 72),
                    top: -34,
                    child: CleanBlurContainer(    // ← clean blur, only while dragging
                      radius: 8,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: SizedBox(
                        width: 56,
                        child: Text(
                          formatDuration(_dragTime),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIDE INDICATOR  (volume / brightness vertical pill)
// ─────────────────────────────────────────────────────────────────────────────

/// Replaces VolumeBrightnessIndicator from shared_widgets — self-contained.
class SideIndicator extends StatelessWidget {
  final IconData icon;
  final double value; // 0.0 – 1.0

  const SideIndicator({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return CleanBlurContainer(                       // ← clean blur, shown 1 at a time
      radius: 20,
      child: SizedBox(
        width: 40,
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: const Color(0xDDFFFFFF), size: 16),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: const Color(0xFFE50914),
                      minHeight: 3,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${(value * 100).round()}',
                style: const TextStyle(
                    color: Color(0xDDFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}