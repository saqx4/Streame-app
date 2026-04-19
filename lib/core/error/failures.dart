/// Base class for all failures/errors in the app
abstract class Failure {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) : super(message: message, error: error, stackTrace: stackTrace);
}

/// Server/API failures
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required String message,
    this.statusCode,
    dynamic error,
    StackTrace? stackTrace,
  }) : super(message: message, error: error, stackTrace: stackTrace);
}

/// Cache/storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) : super(message: message, error: error, stackTrace: stackTrace);
}

/// Torrent/streaming failures
class TorrentFailure extends Failure {
  const TorrentFailure({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) : super(message: message, error: error, stackTrace: stackTrace);
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) : super(message: message, error: error, stackTrace: stackTrace);
}

/// Unknown/unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) : super(message: message, error: error, stackTrace: stackTrace);
}
