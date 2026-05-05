// Toast notification widget
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

enum ToastType { info, success, error }

class Toast {
  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              type == ToastType.success
                  ? Icons.check_circle
                  : type == ToastType.error
                      ? Icons.error
                      : Icons.info,
              color: type == ToastType.error
                  ? AppTheme.errorColor
                  : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: AppTheme.textPrimary)),
            ),
          ],
        ),
        backgroundColor: AppTheme.backgroundCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
