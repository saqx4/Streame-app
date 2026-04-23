import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

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
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
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

Widget castChip(String name) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        name,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );

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
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.current.primaryColor.withValues(alpha: 0.15)
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: highlight
                ? AppTheme.current.primaryColor.withValues(alpha: 0.4)
                : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: highlight
              ? AppTheme.current.primaryColor
              : AppTheme.textSecondary,
        ),
      ),
    );

Widget scrollArrow(IconData icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, color: AppTheme.textDisabled, size: 16),
      ),
    );
