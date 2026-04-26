import 'package:flutter/material.dart';
import 'package:streame_core/utils/app_theme.dart';

class ExpandableSynopsis extends StatefulWidget {
  final String text;
  const ExpandableSynopsis({super.key, required this.text});

  @override
  State<ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlassColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: GlassColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: AppTheme.current.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'Synopsis',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstChild: Text(
              widget.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: scaledFontSize(context, 13.5),
                height: 1.6,
              ),
            ),
            secondChild: Text(
              widget.text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: scaledFontSize(context, 13.5),
                height: 1.6,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.current.primaryColor, size: 18),
                ),
                const SizedBox(width: 4),
                Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: TextStyle(
                    color: AppTheme.current.primaryColor,
                    fontSize: scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
