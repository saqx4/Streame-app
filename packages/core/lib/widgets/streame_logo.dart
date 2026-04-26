import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A clean, modern Streame logo widget.
///
/// Compact mode (sidebar): rounded-rect with gradient play triangle.
/// Full mode (splash): circle with subtle glow + gradient play triangle.
class StreameLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final bool compact;
  final Color? overridePrimary;
  final Color? overrideAccent;

  const StreameLogo({
    super.key,
    this.size = 80,
    this.showGlow = true,
    this.compact = false,
    this.overridePrimary,
    this.overrideAccent,
  });

  @override
  Widget build(BuildContext context) {
    final primary = overridePrimary ?? AppTheme.primaryColor;
    final accent = overrideAccent ?? AppTheme.accentColor;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StreameLogoPainter(
          primary: primary,
          accent: accent,
          showGlow: showGlow,
          compact: compact,
        ),
      ),
    );
  }
}

class _StreameLogoPainter extends CustomPainter {
  final Color primary;
  final Color accent;
  final bool showGlow;
  final bool compact;

  _StreameLogoPainter({
    required this.primary,
    required this.accent,
    required this.showGlow,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width;

    if (compact) {
      _paintCompact(canvas, size, cx, cy, s);
    } else {
      _paintFull(canvas, size, cx, cy, s);
    }
  }

  void _paintCompact(Canvas canvas, Size size, double cx, double cy, double s) {
    // ── Rounded-rect background with gradient ──
    final bgRect = Rect.fromCenter(center: Offset(cx, cy), width: s, height: s);
    final rrect = RRect.fromRectAndRadius(bgRect, Radius.circular(s * 0.22));

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.15),
          accent.withValues(alpha: 0.08),
        ],
      ).createShader(bgRect);
    canvas.drawRRect(rrect, bgPaint);

    // ── Thin border ──
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary.withValues(alpha: 0.5), accent.withValues(alpha: 0.2)],
      ).createShader(bgRect);
    canvas.drawRRect(rrect, borderPaint);

    // ── Play triangle ──
    final triH = s * 0.38;
    final triPath = Path()
      ..moveTo(cx - triH * 0.22, cy - triH * 0.5)
      ..lineTo(cx + triH * 0.38, cy)
      ..lineTo(cx - triH * 0.22, cy + triH * 0.5)
      ..close();

    final triPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, primary],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: triH));

    canvas.drawPath(triPath, triPaint);
  }

  void _paintFull(Canvas canvas, Size size, double cx, double cy, double s) {
    final radius = s / 2;

    // ── Background circle ──
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [AppTheme.bgCard, AppTheme.bgDark],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    // ── Glow ──
    if (showGlow) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.6,
          colors: [
            primary.withValues(alpha: 0.2),
            primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.75));
      canvas.drawCircle(Offset(cx, cy), radius * 0.75, glowPaint);
    }

    // ── Single clean ring ──
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, primary],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.72));
    canvas.drawCircle(Offset(cx, cy), radius * 0.72, ringPaint);

    // ── Play triangle ──
    final triH = s * 0.35;
    final triPath = Path()
      ..moveTo(cx - triH * 0.22, cy - triH * 0.5)
      ..lineTo(cx + triH * 0.38, cy)
      ..lineTo(cx - triH * 0.22, cy + triH * 0.5)
      ..close();

    final triPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, primary],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: triH));

    // Arrow glow
    if (showGlow) {
      canvas.drawPath(
        triPath,
        Paint()
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = primary.withValues(alpha: 0.4),
      );
    }

    canvas.drawPath(triPath, triPaint);
  }

  @override
  bool shouldRepaint(covariant _StreameLogoPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        accent != oldDelegate.accent ||
        showGlow != oldDelegate.showGlow ||
        compact != oldDelegate.compact;
  }
}
