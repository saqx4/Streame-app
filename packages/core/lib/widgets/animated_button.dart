import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Premium animated button with glassmorphic styling and press/hover feedback.
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final AnimatedButtonType type;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool enabled;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onTap,
    this.type = AnimatedButtonType.primary,
    this.radius = AppRadius.md,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.color,
    this.enabled = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

enum AnimatedButtonType { primary, secondary, icon }

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: AnimationPresets.pressScale).animate(
      CurvedAnimation(parent: _controller, curve: AnimationPresets.smoothEnter),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final primary = widget.color ?? AppTheme.current.primaryColor;

    Widget buttonChild;
    switch (widget.type) {
      case AnimatedButtonType.primary:
        buttonChild = _buildPrimary(primary);
      case AnimatedButtonType.secondary:
        buttonChild = _BuildSecondary(primary);
      case AnimatedButtonType.icon:
        buttonChild = _buildIcon(primary);
    }

    return GestureDetector(
      onTapDown: widget.enabled ? _onTapDown : null,
      onTapUp: widget.enabled ? _onTapUp : null,
      onTapCancel: widget.enabled ? _onTapCancel : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: buttonChild,
        ),
      ),
    );
  }

  Widget _buildPrimary(Color primary) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AnimationPresets.smoothInOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _isHovered ? primary.withValues(alpha: 0.9) : primary,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: [
          if (_isHovered) AppShadows.glow(0.2),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        child: widget.child,
      ),
    );
  }

  Widget _BuildSecondary(Color primary) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AnimationPresets.smoothInOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _isHovered
            ? AppTheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : AppTheme.surfaceContainerHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: _isHovered ? primary.withValues(alpha: 0.6) : AppTheme.borderStrong.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          if (_isHovered) AppShadows.glow(0.1),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        child: widget.child,
      ),
    );
  }

  Widget _buildIcon(Color primary) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AnimationPresets.smoothInOut,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isHovered
            ? AppTheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : AppTheme.surfaceContainerHigh.withValues(alpha: 0.35),
        border: Border.all(
          color: _isHovered ? primary.withValues(alpha: 0.5) : AppTheme.borderStrong.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          if (_isHovered) AppShadows.glow(0.1),
        ],
      ),
      child: IconTheme(
        data: IconThemeData(color: _isHovered ? primary : AppTheme.textSecondary, size: 20),
        child: widget.child is Icon ? widget.child : widget.child,
      ),
    );
  }
}
