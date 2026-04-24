import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Show less' : 'Show more',
            style: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.9),
              fontSize: scaledFontSize(context, 12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
