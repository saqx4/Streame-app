import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StreameFocusable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final bool enabled;
  final double focusedScale;
  final double pressedScale;
  final double outlineWidth;
  final Color outlineColor;
  final double glowAlpha;
  final double glowWidth;
  final bool autofocus;

  const StreameFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onFocusChange,
    this.enabled = true,
    this.focusedScale = 1.05,
    this.pressedScale = 0.95,
    this.outlineWidth = 3.0,
    this.outlineColor = const Color(0xFFEDEDED),
    this.glowAlpha = 0.2,
    this.glowWidth = 6.0,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return _FocusWrapper(
      child: child,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      onFocusChange: onFocusChange,
      focusedScale: focusedScale,
      pressedScale: pressedScale,
      outlineWidth: outlineWidth,
      outlineColor: outlineColor,
      glowAlpha: glowAlpha,
      glowWidth: glowWidth,
      autofocus: autofocus,
    );
  }
}

class _FocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final double focusedScale;
  final double pressedScale;
  final double outlineWidth;
  final Color outlineColor;
  final double glowAlpha;
  final double glowWidth;
  final bool autofocus;

  const _FocusWrapper({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onFocusChange,
    this.focusedScale = 1.05,
    this.pressedScale = 0.95,
    this.outlineWidth = 3.0,
    this.outlineColor = const Color(0xFFEDEDED),
    this.glowAlpha = 0.2,
    this.glowWidth = 6.0,
    this.autofocus = false,
  });

  @override
  State<_FocusWrapper> createState() => _FocusWrapperState();
}

class _FocusWrapperState extends State<_FocusWrapper> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;
  bool _isPressed = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _hasFocus = focused);
        widget.onFocusChange?.call(focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap?.call();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 105),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..scale(_isPressed
                  ? widget.pressedScale
                  : _hasFocus
                      ? widget.focusedScale
                      : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: _hasFocus
                  ? Border.all(
                      color: widget.outlineColor,
                      width: widget.outlineWidth,
                    )
                  : null,
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: widget.outlineColor.withValues(alpha: widget.glowAlpha),
                        blurRadius: widget.glowWidth,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class TvCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final double height;

  const TvCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.width = 240,
    this.height = 135,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: StreameFocusable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }
}