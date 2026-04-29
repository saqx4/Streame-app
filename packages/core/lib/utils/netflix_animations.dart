import 'package:flutter/material.dart';

class NetflixAnimate {
  /// Netflix-style scaling and glow animation for hover/focus
  static Widget scale(
    BuildContext context, {
    required Widget child,
    required bool isActive,
    double scale = 1.08,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) {
    return AnimatedScale(
      scale: isActive ? scale : 1.0,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  /// Staggered list animation — each item fades/slides in with index-based delay
  static Widget staggered(
    int index, {
    required Widget child,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    final totalDelay = delay * index;
    return FutureBuilder<bool>(
      future: Future.delayed(totalDelay, () => true),
      initialData: false,
      builder: (context, snapshot) {
        final show = snapshot.data ?? false;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          opacity: show ? 1.0 : 0.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            offset: show ? Offset.zero : const Offset(0, 0.15),
            child: child,
          ),
        );
      },
    );
  }
}
