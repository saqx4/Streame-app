import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A glassmorphic container with backdrop blur, semi-transparent fill,
/// and optional animated border glow on hover/focus.
///
/// Usage:
/// ```dart
/// GlassCard(
///   blur: GlassColors.blur,
///   child: Text('Hello'),
/// )
/// ```
class GlassCard extends StatefulWidget {
  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final Color? tintColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool animateGlow;
  final Color? glowColor;
  final double glowOpacity;
  final BoxShadow? shadow;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.blur = GlassColors.blur,
    this.opacity = 0.45,
    this.borderOpacity = 0.3,
    this.tintColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.animateGlow = false,
    this.glowColor,
    this.glowOpacity = 0.15,
    this.shadow,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.tintColor ?? AppTheme.surfaceContainerHigh;
    final borderCol = widget.borderColor ?? AppTheme.borderStrong;
    final glowCol = widget.glowColor ?? AppTheme.current.primaryColor;

    Widget inner = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: AnimationPresets.smoothInOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: widget.opacity),
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: (_isHovered && widget.animateGlow)
                  ? glowCol.withValues(alpha: 0.6)
                  : borderCol.withValues(alpha: widget.borderOpacity),
              width: (_isHovered && widget.animateGlow) ? 1.0 : 0.5,
            ),
            boxShadow: [
              if (widget.shadow != null) widget.shadow!,
              if (_isHovered && widget.animateGlow)
                AppShadows.glow(widget.glowOpacity),
            ],
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.animateGlow) {
      inner = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: inner,
      );
    }

    if (widget.margin != null) {
      return Padding(padding: widget.margin!, child: inner);
    }
    return inner;
  }
}

/// A simpler glassmorphic container without backdrop blur (for cases where
/// blur is too expensive, e.g. inside list items).
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final double opacity;
  final double borderOpacity;
  final Color? tintColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.opacity = 0.45,
    this.borderOpacity = 0.3,
    this.tintColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? AppTheme.surfaceContainerHigh;
    Widget inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppTheme.borderStrong.withValues(alpha: borderOpacity),
          width: 0.5,
        ),
      ),
      child: child,
    );
    if (margin != null) {
      return Padding(padding: margin!, child: inner);
    }
    return inner;
  }
}
