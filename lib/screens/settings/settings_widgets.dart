import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ExpandableSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const ExpandableSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(
            alpha: _isExpanded ? 0.15 : 0.08,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isExpanded
                ? AppTheme.current.primaryColor.withValues(alpha: 0.2)
                : AppTheme.border,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 20,
                      color: _isExpanded
                          ? AppTheme.current.primaryColor
                          : AppTheme.textDisabled,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: _isExpanded
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _isExpanded
                            ? AppTheme.current.primaryColor
                            : AppTheme.textDisabled,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding:
                    const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}

class FocusableToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const FocusableToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      onTap: () => onChanged(!value),
      scaleOnFocus: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppTheme.current.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class FocusableDropdown extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const FocusableDropdown({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableControl(
      onTap: () {},
      scaleOnFocus: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: value,
                dropdownColor: Color.lerp(
                  AppTheme.current.bgDark,
                  AppTheme.current.primaryColor,
                  0.08,
                ),
                underline: const SizedBox.shrink(),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.current.primaryColor,
                ),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                selectedItemBuilder: (BuildContext context) {
                  return options.map<Widget>((String item) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: options
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(
                          o,
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
