import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class AudioFilterMenu extends StatefulWidget {
  final List<String> allTags;
  final Set<String> activeTags;
  final ValueChanged<Set<String>> onChanged;
  const AudioFilterMenu({
    super.key,
    required this.allTags,
    required this.activeTags,
    required this.onChanged,
  });

  @override
  State<AudioFilterMenu> createState() => _AudioFilterMenuState();
}

class _AudioFilterMenuState extends State<AudioFilterMenu> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.activeTags);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.graphic_eq,
                    size: 14,
                    color: AppTheme.textDisabled,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Audio',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selected.clear());
                        widget.onChanged({});
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: AppTheme.border, height: 8),
            ...widget.allTags.map((tag) {
              final on = _selected.contains(tag);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (on) {
                      _selected.remove(tag);
                    } else {
                      _selected.add(tag);
                    }
                  });
                  widget.onChanged(Set<String>.from(_selected));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: on
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: on ? AppTheme.primaryColor : AppTheme.border,
                            width: 1.5,
                          ),
                        ),
                        child: on
                            ? Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: AppTheme.textPrimary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tag,
                        style: TextStyle(
                          color: on
                              ? AppTheme.textPrimary
                              : AppTheme.textDisabled,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
