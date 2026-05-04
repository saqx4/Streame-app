import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StreameFocusConfig {
  final double scaleFocused;
  final double scalePressed;
  final Duration animationDuration;
  final Curve easing;
  final double outlineWidth;
  final Color outlineColor;
  final double glowWidth;
  final double glowAlpha;

  const StreameFocusConfig({
    this.scaleFocused = 1.05,
    this.scalePressed = 0.95,
    this.animationDuration = const Duration(milliseconds: 105),
    this.easing = Curves.easeOutCubic,
    this.outlineWidth = 3.0,
    this.outlineColor = const Color(0xFF00D4FF),
    this.glowWidth = 6.0,
    this.glowAlpha = 0.4,
  });
}

class StreameFocus extends InheritedWidget {
  final StreameFocusConfig config;
  final bool isTv;

  const StreameFocus({
    super.key,
    required this.config,
    required this.isTv,
    required super.child,
  });

  static StreameFocus of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<StreameFocus>();
    return provider ?? const StreameFocus(
      config: StreameFocusConfig(),
      isTv: false,
      child: SizedBox.shrink(),
    );
  }

  @override
  bool updateShouldNotify(StreameFocus oldWidget) {
    return config != oldWidget.config || isTv != oldWidget.isTv;
  }
}

class TvFocusScaffold extends StatelessWidget {
  final Widget child;
  final bool isTv;

  const TvFocusScaffold({
    super.key,
    required this.child,
    this.isTv = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreameFocus(
      isTv: isTv,
      config: const StreameFocusConfig(),
      child: child,
    );
  }
}