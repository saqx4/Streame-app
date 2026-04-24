/// A simple Either type for handling errors without exceptions
/// Left represents a Failure, Right represents a Success value
class Either<L, R> {
  final L? _left;
  final R? _right;

  const Either._(this._left, this._right);

  factory Either.left(L value) => Either._(value, null);
  factory Either.right(R value) => Either._(null, value);

  bool isLeft() => _left != null;
  bool isRight() => _right != null;

  L? get left => _left;
  R? get right => _right;

  /// Transform the right value
  Either<L, R2> map<R2>(R2 Function(R) f) {
    if (isRight()) {
      return Either.right(f(_right as R));
    }
    return Either.left(_left as L);
  }

  /// Transform the left value
  Either<L2, R> mapLeft<L2>(L2 Function(L) f) {
    if (isLeft()) {
      return Either.left(f(_left as L));
    }
    return Either.right(_right as R);
  }

  /// Chain operations that may fail
  Either<L, R2> flatMap<R2>(Either<L, R2> Function(R) f) {
    if (isRight()) {
      return f(_right as R);
    }
    return Either.left(_left as L);
  }

  /// Execute a function based on which side this is
  T fold<T>(
    T Function(L) onLeft,
    T Function(R) onRight,
  ) {
    if (isLeft()) {
      return onLeft(_left as L);
    }
    return onRight(_right as R);
  }
}
