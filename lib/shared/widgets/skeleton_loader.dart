// Skeleton loader — shimmer loading placeholders
// Pauses animation when off-screen to save GPU/CPU resources.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isInViewport = true;
  Timer? _visibilityTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    // Start periodic visibility check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkVisibility();
      _visibilityTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _checkVisibility(),
      );
    });
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _checkVisibility() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

    final viewportSize = MediaQuery.sizeOf(context);
    final position = renderBox.localToGlobal(Offset.zero);
    final inViewport = position.dx + renderBox.size.width > 0 &&
        position.dx < viewportSize.width &&
        position.dy + renderBox.size.height > 0 &&
        position.dy < viewportSize.height;

    if (inViewport != _isInViewport) {
      _isInViewport = inViewport;
      if (inViewport && !_controller.isAnimating) {
        _controller.repeat();
      } else if (!inViewport && _controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value * 2).clamp(0.0, 1.0);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + value * 2, 0),
              end: Alignment(-1 + value * 2 + 1, 0),
              colors: [
                AppTheme.backgroundCard,
                AppTheme.backgroundElevated,
                AppTheme.backgroundCard,
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonCard({super.key, this.width = 140, this.height = 210});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonLoader(width: width, height: height * 0.75, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 8),
            SkeletonLoader(width: width * 0.7, height: 14),
            const SizedBox(height: 4),
            SkeletonLoader(width: width * 0.4, height: 12),
          ],
        ),
      ),
    );
  }
}

class SkeletonRail extends StatelessWidget {
  final int itemCount;

  const SkeletonRail({super.key, this.itemCount = 7});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SkeletonLoader(width: 120, height: 20),
        ),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SkeletonCard(),
          ),
        ),
      ],
    );
  }
}
