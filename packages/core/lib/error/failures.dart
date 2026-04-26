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
    required super.message,
    super.error,
    super.stackTrace,
  });
}

/// Server/API failures
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required super.message,
    this.statusCode,
    super.error,
    super.stackTrace,
  });
}

/// Cache/storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.error,
    super.stackTrace,
  });
}

/// Torrent/streaming failures
class TorrentFailure extends Failure {
  const TorrentFailure({
    required super.message,
    super.error,
    super.stackTrace,
  });
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.error,
    super.stackTrace,
  });
}

/// Unknown/unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    required super.message,
    super.error,
    super.stackTrace,
  });
}
