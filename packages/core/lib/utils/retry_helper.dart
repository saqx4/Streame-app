import 'dart:async';
import '../error/either.dart';
import '../error/failures.dart';
import '../error/error_handler.dart';

/// Utility class for retrying failed operations with exponential backoff
class RetryHelper {
  static final ErrorHandler _errorHandler = ErrorHandler();

  /// Retry a function that returns a Future with exponential backoff
  /// 
  /// [fn] - The function to retry
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [delayMs] - Initial delay in milliseconds (default: 1000)
  /// [backoffMultiplier] - Multiplier for exponential backoff (default: 2.0)
  /// [retryIf] - Optional predicate to determine if an error should be retried
  static Future<T> retry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
    int delayMs = 1000,
    double backoffMultiplier = 2.0,
    bool Function(Failure)? retryIf,
  }) async {
    int attempts = 0;
    int currentDelay = delayMs;

    while (attempts < maxAttempts) {
      try {
        return await fn();
      } catch (e, st) {
        attempts++;
        
        final failure = _errorHandler.handleException(e, st);
        
        // Check if we should retry this error
        if (retryIf != null && !retryIf(failure)) {
          throw failure;
        }
        
        // Don't retry on last attempt
        if (attempts >= maxAttempts) {
          _errorHandler.logError(
            'Operation failed after $maxAttempts attempts',
            error: e,
            stackTrace: st,
          );
          throw failure;
        }
        
        _errorHandler.logError(
          'Attempt $attempts/$maxAttempts failed, retrying in ${currentDelay}ms...',
          error: e,
          stackTrace: st,
          severity: ErrorSeverity.warning,
        );
        
        await Future.delayed(Duration(milliseconds: currentDelay));
        currentDelay = (currentDelay * backoffMultiplier).toInt();
      }
    }
    
    throw UnknownFailure(message: 'Retry failed after $maxAttempts attempts');
  }

  /// Retry a function that returns an Either type
  static Future<Either<Failure, T>> retryEither<T>(
    Future<Either<Failure, T>> Function() fn, {
    int maxAttempts = 3,
    int delayMs = 1000,
    double backoffMultiplier = 2.0,
    bool Function(Failure)? retryIf,
  }) async {
    int attempts = 0;
    int currentDelay = delayMs;

    while (attempts < maxAttempts) {
      final result = await fn();
      
      if (result.isRight()) {
        return result;
      }
      
      final failure = result.left!;
      attempts++;
      
      // Check if we should retry this error
      if (retryIf != null && !retryIf(failure)) {
        return result;
      }
      
      // Don't retry on last attempt
      if (attempts >= maxAttempts) {
        _errorHandler.logError(
          'Operation failed after $maxAttempts attempts',
          error: failure,
        );
        return result;
      }
      
      _errorHandler.logError(
        'Attempt $attempts/$maxAttempts failed, retrying in ${currentDelay}ms...',
        error: failure,
        severity: ErrorSeverity.warning,
      );
      
      await Future.delayed(Duration(milliseconds: currentDelay));
      currentDelay = (currentDelay * backoffMultiplier).toInt();
    }
    
    return Either.left(UnknownFailure(message: 'Retry failed after $maxAttempts attempts'));
  }

  /// Default retry condition - retry network and server errors
  static bool defaultRetryCondition(Failure failure) {
    return failure is NetworkFailure || 
           (failure is ServerFailure && failure.statusCode != null && failure.statusCode! >= 500);
  }
}
