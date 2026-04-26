import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV-specific focus management utilities for D-pad navigation.
class TvFocusManager {
  TvFocusManager._();

  /// Request focus to the first focusable widget in a context.
  /// Useful for initial focus when a screen loads.
  static void requestInitialFocus(BuildContext context) {
    try {
      FocusScope.of(context).requestFocus();
    } catch (_) {}
  }

  /// Move focus in a direction (up, down, left, right).
  /// Returns true if focus was moved successfully.
  static bool moveFocusInDirection(BuildContext context, {bool up = false, bool down = false, bool left = false, bool right = false}) {
    final focusScope = FocusScope.of(context);
    final currentFocus = focusScope.focusedChild;
    
    if (currentFocus == null) return false;
    
    bool moved = false;
    
    if (up) {
      moved = focusScope.previousFocus() != focusScope.focusedChild;
    } else if (down) {
      moved = focusScope.nextFocus() != focusScope.focusedChild;
    } else if (left) {
      moved = focusScope.previousFocus() != focusScope.focusedChild;
    } else if (right) {
      moved = focusScope.nextFocus() != focusScope.focusedChild;
    }
    
    return moved;
  }

  /// Handle D-pad key events for TV navigation.
  /// Returns true if the key was handled.
  static bool handleDpadKeyEvent(KeyEvent event, BuildContext context) {
    if (event is! KeyDownEvent) return false;
    
    final key = event.logicalKey;
    
    if (key == LogicalKeyboardKey.arrowUp) {
      return moveFocusInDirection(context, up: true);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      return moveFocusInDirection(context, down: true);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      return moveFocusInDirection(context, left: true);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      return moveFocusInDirection(context, right: true);
    }
    
    return false;
  }
}
