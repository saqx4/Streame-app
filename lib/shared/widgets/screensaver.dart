// Screensaver — shows when idle for a configurable time on TV
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

class Screensaver extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final VoidCallback? onWake;

  const Screensaver({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 5),
    this.onWake,
  });

  @override
  State<Screensaver> createState() => _ScreensaverState();
}

class _ScreensaverState extends State<Screensaver> {
  bool _isIdle = false;
  Timer? _idleTimer;

  void _resetTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.timeout, () {
      if (mounted) setState(() => _isIdle = true);
    });
    if (_isIdle) {
      setState(() => _isIdle = false);
      widget.onWake?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tap to dismiss screensaver',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetTimer,
        onPanDown: (_) => _resetTimer(),
        child: Stack(
          children: [
            widget.child,
            if (_isIdle)
              Container(
                color: AppTheme.backgroundDark,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, size: 64, color: AppTheme.arcticWhite30),
                      const SizedBox(height: 16),
                      const Text('Streame', style: TextStyle(
                        color: AppTheme.arcticWhite30, fontSize: 24, fontWeight: FontWeight.w300,
                      )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
