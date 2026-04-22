import 'package:flutter/material.dart';
import '../error/failures.dart';
import '../../utils/app_theme.dart';

/// User-friendly error dialog that shows different messages based on failure type
class ErrorDialog extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.failure,
    this.onRetry,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required Failure failure,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        failure: failure,
        onRetry: onRetry,
        onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = _getErrorInfo();

    return AlertDialog(
      backgroundColor: AppTheme.bgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ),
      actions: [
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        TextButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: const Text('OK'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  (String, String, IconData) _getErrorInfo() {
    switch (failure) {
      case NetworkFailure():
        return (
          'Network Error',
          failure.message.isEmpty 
            ? 'Please check your internet connection and try again.' 
            : failure.message,
          Icons.wifi_off,
        );
      case ServerFailure():
        return (
          'Server Error',
          failure.message.isEmpty 
            ? 'Something went wrong on our end. Please try again later.' 
            : failure.message,
          Icons.cloud_off,
        );
      case CacheFailure():
        return (
          'Storage Error',
          failure.message.isEmpty 
            ? 'There was a problem saving or loading data.' 
            : failure.message,
          Icons.storage,
        );
      case TorrentFailure():
        return (
          'Streaming Error',
          failure.message.isEmpty 
            ? 'Unable to stream the content. The torrent may be unavailable.' 
            : failure.message,
          Icons.play_disabled,
        );
      case AuthFailure():
        return (
          'Authentication Error',
          failure.message.isEmpty 
            ? 'Please check your credentials and try again.' 
            : failure.message,
          Icons.lock,
        );
      default:
        return (
          'Error',
          failure.message.isEmpty 
            ? 'An unexpected error occurred.' 
            : failure.message,
          Icons.error_outline,
        );
    }
  }
}

/// Snackbar widget for showing non-critical errors
void showErrorSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Loading overlay with error handling
class LoadingOrErrorWidget extends StatelessWidget {
  final bool isLoading;
  final Failure? error;
  final Widget child;
  final VoidCallback? onRetry;

  const LoadingOrErrorWidget({
    super.key,
    required this.isLoading,
    this.error,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                error!.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return child;
  }
}
