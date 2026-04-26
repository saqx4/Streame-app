import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'error_handler.dart';
import 'failures.dart';

/// Global error boundary widget that catches Flutter errors
class ErrorBoundary extends ConsumerStatefulWidget {
  final Widget child;

  const ErrorBoundary({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  dynamic _error;
  void Function(FlutterErrorDetails)? _previousErrorHandler;

  @override
  void initState() {
    super.initState();
    // Chain our handler on top of the existing one so we don't stomp it
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // Let the previous handler run first (e.g. default crash reporting)
    _previousErrorHandler?.call(details);

    ErrorHandler().logError(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = details.exception;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Restore the previous handler to avoid dangling references
    FlutterError.onError = _previousErrorHandler;
    super.dispose();
  }

  void _resetError() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(
        error: _error,
        onReset: _resetError,
      );
    }

    return widget.child;
  }
}

/// Error screen shown when a fatal error occurs
class _ErrorScreen extends StatelessWidget {
  final dynamic error;
  final VoidCallback onReset;

  const _ErrorScreen({
    required this.error,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Provider observer for logging Riverpod state changes
class ProviderLogger extends ProviderObserver {
  final ErrorHandler _errorHandler = ErrorHandler();

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (value is Failure) {
      _errorHandler.logError(
        'Provider error: ${provider.name ?? provider.runtimeType}',
        error: value,
      );
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _errorHandler.logError(
      'Provider failed: ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
