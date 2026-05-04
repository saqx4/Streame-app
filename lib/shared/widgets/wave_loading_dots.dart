import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

/// Animated wave loading dots - bouncing dots with staggered animation
/// Matches the Kotlin app's WaveLoadingDots composable
class WaveLoadingDots extends StatefulWidget {
  final int dotCount;
  final double dotSize;
  final double dotSpacing;
  final Color color;
  final Color? secondaryColor;

  const WaveLoadingDots({
    super.key,
    this.dotCount = 3,
    this.dotSize = 8.0,
    this.dotSpacing = 8.0,
    this.color = AppTheme.accentGreen,
    this.secondaryColor,
  });

  @override
  State<WaveLoadingDots> createState() => _WaveLoadingDotsState();
}

class _WaveLoadingDotsState extends State<WaveLoadingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.dotCount,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );
    _animations = _controllers
        .map((controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: controller,
                curve: Curves.easeInOut,
              ),
            ))
        .toList();

    // Start animations with stagger
    for (var i = 0; i < widget.dotCount; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.dotCount,
        (index) => AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            final scale = 0.6 + (_animations[index].value * 0.4);
            final opacity = 0.4 + (_animations[index].value * 0.6);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                margin: EdgeInsets.symmetric(horizontal: widget.dotSpacing / 2),
                decoration: BoxDecoration(
                  color: (index % 2 == 0
                          ? widget.color
                          : widget.secondaryColor ?? widget.color)
                      .withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
