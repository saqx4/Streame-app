import 'package:flutter/material.dart';
import 'package:streame_core/utils/app_theme.dart';

Widget sectionLabel(String text) => Text(
      text,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );

Widget genreChip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.current.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.current.primaryColor.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

Widget castChip(String name) {
  final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
  return Container(
    padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
    decoration: BoxDecoration(
      color: GlassColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GlassColors.borderSubtle, width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.current.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: AppTheme.current.primaryColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(name, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    ),
  );
}

Widget qualityBadge(String q, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
      child: Text(
        q,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

Widget codecBadge(String codec) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        codec,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

Widget iconBtn(IconData icon, bool highlight, VoidCallback onTap) =>
    _IconBtn(icon: icon, highlight: highlight, onTap: onTap);

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final bool highlight;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.highlight, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.highlight
                ? primary.withValues(alpha: _isHovered ? 0.25 : 0.15)
                : AppTheme.surfaceContainerHigh.withValues(alpha: _isHovered ? 0.5 : 0.3),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: widget.highlight
                  ? primary.withValues(alpha: _isHovered ? 0.6 : 0.4)
                  : (_isHovered ? primary.withValues(alpha: 0.3) : AppTheme.border),
            ),
            boxShadow: _isHovered && widget.highlight ? [AppShadows.glow(0.1)] : null,
          ),
          child: Icon(
            widget.icon,
            size: 17,
            color: widget.highlight
                ? primary
                : (_isHovered ? AppTheme.textPrimary : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

Widget scrollArrow(IconData icon, VoidCallback onTap) =>
    _ScrollArrow(icon: icon, onTap: onTap);

class _ScrollArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollArrow({required this.icon, required this.onTap});

  @override
  State<_ScrollArrow> createState() => _ScrollArrowState();
}

class _ScrollArrowState extends State<_ScrollArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _isHovered ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(widget.icon,
            color: _isHovered ? primary : AppTheme.textDisabled, size: 16),
        ),
      ),
    );
  }
}
