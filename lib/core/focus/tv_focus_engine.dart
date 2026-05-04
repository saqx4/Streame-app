// TV D-pad focus engine matching Kotlin StreameDpadFocus parity
// Manages focus zones, D-pad key handling, and focus group navigation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Focus zone enum (matching Kotlin FocusZone)
enum FocusZone {
  sidebar,
  content,
  searchInput,
  filters,
  results,
}

/// D-pad repeat gate (matching Kotlin StreameDpadRepeatGate)
/// Throttles repeated D-pad key events to prevent overscroll
class DpadRepeatGate {
  int _lastKeyCode = -1;
  int _lastHandledAtMs = 0;
  final int minRepeatIntervalMs;

  DpadRepeatGate({this.minRepeatIntervalMs = 80});

  bool shouldSkip(int keyCode, int repeatCount) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (repeatCount <= 0) {
      _lastKeyCode = keyCode;
      _lastHandledAtMs = now;
      return false;
    }
    final skip = keyCode == _lastKeyCode && now - _lastHandledAtMs < minRepeatIntervalMs;
    if (!skip) {
      _lastKeyCode = keyCode;
      _lastHandledAtMs = now;
    }
    return skip;
  }

  void reset() {
    _lastKeyCode = -1;
    _lastHandledAtMs = 0;
  }
}

/// Whether a key is a D-pad navigation key
bool isDpadNavigationKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown;
}

/// Detect if the current device is likely a TV (no touchscreen)
final isTvDeviceProvider = Provider<bool>((ref) {
  // Simple heuristic: TV devices typically don't have touch
  // In production, use device_info_plus for accurate detection
  return true; // Default to TV mode for Android TV target
});

/// Current focus zone state
final focusZoneProvider = StateProvider<FocusZone>((ref) => FocusZone.content);

/// Current focused row index in content
final focusedRowProvider = StateProvider<int>((ref) => 0);

/// Current focused item index within a row
final focusedItemProvider = StateProvider<int>((ref) => 0);

/// Sidebar focus index
final sidebarFocusIndexProvider = StateProvider<int>((ref) => 0);

/// A widget that wraps content with D-pad key handling for TV navigation
class TvDpadHandler extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onBack;
  final int totalRows;
  final int Function(int row)? itemCountBuilder;

  const TvDpadHandler({
    super.key,
    required this.child,
    this.onBack,
    this.totalRows = 0,
    this.itemCountBuilder,
  });

  @override
  ConsumerState<TvDpadHandler> createState() => _TvDpadHandlerState();
}

class _TvDpadHandlerState extends ConsumerState<TvDpadHandler> {
  // ignore: unused_field
  final _repeatGate = DpadRepeatGate();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        final key = event.logicalKey;
        if (!isDpadNavigationKey(key) &&
            key != LogicalKeyboardKey.enter &&
            key != LogicalKeyboardKey.escape &&
            key != LogicalKeyboardKey.goBack) {
          return KeyEventResult.ignored;
        }

        final isRepeat = event is KeyRepeatEvent;
        if (isRepeat && key != LogicalKeyboardKey.arrowLeft &&
            key != LogicalKeyboardKey.arrowRight &&
            key != LogicalKeyboardKey.arrowUp &&
            key != LogicalKeyboardKey.arrowDown) {
          return KeyEventResult.ignored;
        }

        final zone = ref.read(focusZoneProvider);
        final currentRow = ref.read(focusedRowProvider);
        final currentItem = ref.read(focusedItemProvider);

        if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
          widget.onBack?.call();
          return KeyEventResult.handled;
        }

        switch (zone) {
          case FocusZone.sidebar:
            return _handleSidebarDpad(key, isRepeat);
          case FocusZone.content:
            return _handleContentDpad(key, isRepeat, currentRow, currentItem);
          case FocusZone.searchInput:
            return _handleSearchInputDpad(key);
          case FocusZone.filters:
            return KeyEventResult.ignored; // Let native focus handle it
          case FocusZone.results:
            return _handleResultsDpad(key, isRepeat, currentRow, currentItem);
        }
      },
      child: widget.child,
    );
  }

  KeyEventResult _handleSidebarDpad(LogicalKeyboardKey key, bool isRepeat) {
    final idx = ref.read(sidebarFocusIndexProvider);
    if (key == LogicalKeyboardKey.arrowUp && idx > 0) {
      ref.read(sidebarFocusIndexProvider.notifier).state--;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && idx < 4) {
      ref.read(sidebarFocusIndexProvider.notifier).state++;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      ref.read(focusZoneProvider.notifier).state = FocusZone.content;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleContentDpad(LogicalKeyboardKey key, bool isRepeat, int row, int item) {
    if (key == LogicalKeyboardKey.arrowLeft && item > 0) {
      ref.read(focusedItemProvider.notifier).state = item - 1;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final maxItem = (widget.itemCountBuilder?.call(row) ?? 10) - 1;
      if (item < maxItem) {
        ref.read(focusedItemProvider.notifier).state = item + 1;
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled; // At end, consume but don't move
    }
    if (key == LogicalKeyboardKey.arrowUp && row > 0) {
      ref.read(focusedRowProvider.notifier).state = row - 1;
      ref.read(focusedItemProvider.notifier).state = 0;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && row < widget.totalRows - 1) {
      ref.read(focusedRowProvider.notifier).state = row + 1;
      ref.read(focusedItemProvider.notifier).state = 0;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && item == 0) {
      ref.read(focusZoneProvider.notifier).state = FocusZone.sidebar;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSearchInputDpad(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowDown) {
      ref.read(focusZoneProvider.notifier).state = FocusZone.content;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      ref.read(focusZoneProvider.notifier).state = FocusZone.sidebar;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleResultsDpad(LogicalKeyboardKey key, bool isRepeat, int row, int item) {
    return _handleContentDpad(key, isRepeat, row, item);
  }
}

/// A focus group widget that manages focus within a horizontal row
/// (matching Kotlin StreameDpadFocusGroup)
class TvFocusGroup extends StatefulWidget {
  final Widget child;
  final bool isFocusGroup;

  const TvFocusGroup({
    super.key,
    required this.child,
    this.isFocusGroup = true,
  });

  @override
  State<TvFocusGroup> createState() => _TvFocusGroupState();
}

class _TvFocusGroupState extends State<TvFocusGroup> {
  final _focusNode = FocusNode();
  final _scopeNode = FocusScopeNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _scopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFocusGroup) return widget.child;
    return FocusScope(
      node: _scopeNode,
      child: Focus(
        focusNode: _focusNode,
        child: widget.child,
      ),
    );
  }
}

/// A scroll controller that auto-scrolls to keep the focused item visible
/// (matching Kotlin's LaunchedEffect scroll-to-focused-item logic)
class TvAutoScroll extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final int focusedIndex;
  final double itemWidth;
  final double itemSpacing;
  final bool isFocused;

  const TvAutoScroll({
    super.key,
    required this.child,
    required this.controller,
    required this.focusedIndex,
    this.itemWidth = 210,
    this.itemSpacing = 14,
    required this.isFocused,
  });

  @override
  State<TvAutoScroll> createState() => _TvAutoScrollState();
}

class _TvAutoScrollState extends State<TvAutoScroll> {
  int _lastScrollIndex = -1;

  @override
  void didUpdateWidget(TvAutoScroll old) {
    super.didUpdateWidget(old);
    if (!widget.isFocused) {
      _lastScrollIndex = -1;
      return;
    }
    if (widget.focusedIndex == old.focusedIndex && widget.isFocused == old.isFocused) return;

    final offset = widget.focusedIndex * (widget.itemWidth + widget.itemSpacing);
    if (_lastScrollIndex == -1) {
      widget.controller.jumpTo(offset.clamp(0, widget.controller.position.maxScrollExtent));
    } else {
      final jumpDistance = (widget.focusedIndex - _lastScrollIndex).abs();
      if (jumpDistance > 7) {
        widget.controller.jumpTo(offset.clamp(0, widget.controller.position.maxScrollExtent));
      } else {
        widget.controller.animateTo(
          offset.clamp(0, widget.controller.position.maxScrollExtent),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _lastScrollIndex = widget.focusedIndex;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
