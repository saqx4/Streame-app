import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streame/core/theme/app_theme.dart';

class StreameDpadConfig {
  final int minRepeatIntervalMs;
  final int initialDelayMs;
  final int repeatAccelerationMs;

  const StreameDpadConfig({
    this.minRepeatIntervalMs = 82,
    this.initialDelayMs = 300,
    this.repeatAccelerationMs = 50,
  });
}

class DpadNavigationKey {
  static const LogicalKeyboardKey directionUp = LogicalKeyboardKey.arrowUp;
  static const LogicalKeyboardKey directionDown = LogicalKeyboardKey.arrowDown;
  static const LogicalKeyboardKey directionLeft = LogicalKeyboardKey.arrowLeft;
  static const LogicalKeyboardKey directionRight = LogicalKeyboardKey.arrowRight;
  static const LogicalKeyboardKey enter = LogicalKeyboardKey.enter;
  static const LogicalKeyboardKey select = LogicalKeyboardKey.select;
  static const LogicalKeyboardKey escape = LogicalKeyboardKey.escape;

  static bool isDpadNavigation(LogicalKeyboardKey key) {
    return key == directionUp ||
        key == directionDown ||
        key == directionLeft ||
        key == directionRight;
  }
}

class StreameDpadController extends ChangeNotifier {
  final StreameDpadConfig config;
  int _lastKeyCode = -1;
  DateTime? _lastHandledAt;
  int _repeatCount = 0;
  DateTime? _repeatStartTime;
  void Function(LogicalKeyboardKey key, int repeatCount)? _onKeyRepeat;

  StreameDpadController({
    this.config = const StreameDpadConfig(),
    void Function(LogicalKeyboardKey key, int repeatCount)? onKeyRepeat,
  }) : _onKeyRepeat = onKeyRepeat;

  bool shouldSkipKey(int keyCode, int repeatCount) {
    if (repeatCount <= 0) {
      _lastKeyCode = keyCode;
      _lastHandledAt = DateTime.now();
      _repeatCount = 0;
      _repeatStartTime = null;
      return false;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastHandledAt ?? now).inMilliseconds;

    if (keyCode != _lastKeyCode) {
      _lastKeyCode = keyCode;
      _lastHandledAt = now;
      _repeatCount = 0;
      _repeatStartTime = null;
      return false;
    }

    if (_repeatStartTime == null) {
      _repeatStartTime = now;
    }

    // ignore: unused_local_variable
    final repeatDiff = now.difference(_repeatStartTime ?? now).inMilliseconds;

    bool shouldSkip;
    if (repeatCount == 1) {
      shouldSkip = diff < config.initialDelayMs;
    } else {
      final adjustedInterval = config.minRepeatIntervalMs -
          ((repeatCount - 1) * config.repeatAccelerationMs).clamp(0, 70);
      shouldSkip = diff < adjustedInterval;
    }

    if (!shouldSkip) {
      _lastHandledAt = now;
    }

    return shouldSkip;
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (DpadNavigationKey.isDpadNavigation(key)) {
        _repeatCount++;
        final shouldSkip = shouldSkipKey(key.keyId, _repeatCount);
        if (!shouldSkip) {
          _onKeyRepeat?.call(key, _repeatCount);
        }
      }
    } else if (event is KeyUpEvent) {
      _lastKeyCode = -1;
      _repeatCount = 0;
      _repeatStartTime = null;
    }
  }

  void reset() {
    _lastKeyCode = -1;
    _lastHandledAt = null;
    _repeatCount = 0;
    _repeatStartTime = null;
  }
}

class TvRail extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final ScrollController? scrollController;
  final double itemWidth;
  final double itemHeight;
  final double spacing;
  final EdgeInsets padding;

  const TvRail({
    super.key,
    required this.title,
    required this.items,
    this.scrollController,
    this.itemWidth = 240,
    this.itemHeight = 180,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right, top: padding.top),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: itemHeight,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding.left),
            itemCount: items.length,
            separatorBuilder: (context, index) => SizedBox(width: spacing),
            itemBuilder: (context, index) => items[index],
          ),
        ),
      ],
    );
  }
}

class TvSidebar extends StatelessWidget {
  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double width;

  const TvSidebar({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.onSelected,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppTheme.backgroundDark.withValues(alpha: 0.87),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: Semantics(
              button: true,
              label: item.label,
              child: GestureDetector(
                onTap: () => onSelected?.call(index),
                child: Container(
                  alignment: Alignment.center,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Icon(
                    item.icon,
                    color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SidebarItem {
  final IconData icon;
  final String label;

  const SidebarItem({required this.icon, required this.label});
}

class TvHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onPlay;
  final VoidCallback? onInfo;
  final double height;

  const TvHero({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onPlay,
    this.onInfo,
    this.height = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppTheme.backgroundDark.withValues(alpha: 0.7),
              AppTheme.backgroundDark,
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: AppTheme.backgroundDark,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onInfo,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('More Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TvDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<DialogAction>? actions;

  const TvDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundDark.withValues(alpha: 0.54),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppTheme.backgroundElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accentCyan,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              content,
              if (actions != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!.map((action) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Semantics(
                        button: true,
                        label: action.label,
                        child: GestureDetector(
                          onTap: action.onPressed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: action.isPrimary
                                  ? AppTheme.accentCyan
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: action.isPrimary
                                    ? AppTheme.accentCyan
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            child: Text(
                              action.label,
                              style: TextStyle(
                                color: action.isPrimary
                                    ? AppTheme.backgroundDark
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const DialogAction({
    required this.label,
    this.onPressed,
    this.isPrimary = false,
  });
}