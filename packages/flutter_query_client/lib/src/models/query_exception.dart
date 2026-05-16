/// Exception thrown by the flutter_query package when an operation fails
/// due to internal machinery (e.g., retry exhaustion).
///
/// User-closure errors (thrown by `queryFn`, `mutationFn`) pass through
/// as-is when retries are not involved. When retries are exhausted, the
/// last user error is wrapped in [QueryException.originalError].
class QueryException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// The underlying error that caused this exception, if any.
  ///
  /// For retry exhaustion, this is the last error thrown by the user's
  /// `queryFn` or `mutationFn`.
  final Object? originalError;

  /// Stack trace of the [originalError], if captured.
  final StackTrace? stackTrace;

  QueryException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('QueryException: $message');
    if (originalError != null) {
      buffer.write(' (caused by: $originalError)');
    }
    return buffer.toString();
  }
}
