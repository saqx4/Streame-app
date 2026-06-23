import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

enum StreameToastType { success, error, info }

class StreameToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    StreameToastType type = StreameToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    _currentEntry = OverlayEntry(
      builder: (_) => _StreameToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_currentEntry!);
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void dismiss() => _dismiss();
}

class _StreameToastWidget extends StatefulWidget {
  final String message;
  final StreameToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _StreameToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_StreameToastWidget> createState() => _StreameToastWidgetState();
}

class _StreameToastWidgetState extends State<_StreameToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();

    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    if (!_ctrl.isAnimating && _ctrl.isCompleted) {
      await _ctrl.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accentColor => switch (widget.type) {
    StreameToastType.success => AppTheme.accentGreen,
    StreameToastType.error => AppTheme.errorColor,
    StreameToastType.info => AppTheme.accentYellow,
  };

  IconData get _icon => switch (widget.type) {
    StreameToastType.success => Icons.check_circle_rounded,
    StreameToastType.error => Icons.error_rounded,
    StreameToastType.info => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _dismiss,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundCard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.backgroundDark.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: _accentColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.close_rounded,
                        color: AppTheme.textTertiary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
