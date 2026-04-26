import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'failures.dart';

/// Global error handler that centralizes error logging and reporting
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Log an error with context
  void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final severityStr = severity.toString().split('.').last.toUpperCase();
    
    log.info('[$timestamp] [$severityStr] $message');
    
    if (error != null) {
      log.info('Error: $error');
    }
    
    if (stackTrace != null && kDebugMode) {
      log.info('Stack trace:\n$stackTrace');
    }
  }

  /// Convert exceptions to Failure objects
  Failure handleException(dynamic exception, [StackTrace? stackTrace]) {
    logError('Exception caught', error: exception, stackTrace: stackTrace);

    if (exception is SocketException) {
      return NetworkFailure(
        message: 'No internet connection',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is HttpException) {
      return NetworkFailure(
        message: exception.message,
        error: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is FormatException) {
      return ServerFailure(
        message: 'Invalid data format',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is TimeoutException) {
      return NetworkFailure(
        message: 'Request timed out',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    return UnknownFailure(
      message: exception.toString(),
      error: exception,
      stackTrace: stackTrace,
    );
  }

  /// Handle async errors
  Future<T> handleAsync<T>(
    Future<T> Function() fn, {
    Failure? onFailure,
  }) async {
    try {
      return await fn();
    } catch (e, st) {
      throw onFailure ?? handleException(e, st);
    }
  }
}

enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}
