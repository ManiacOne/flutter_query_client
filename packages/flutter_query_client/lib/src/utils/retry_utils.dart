import 'dart:async';

import 'package:flutter_query_client/src/models/query_exception.dart';

/// Executes [fn] with exponential backoff retry logic.
///
/// Retries up to [maxAttempts] times. On each failure, waits an
/// exponentially increasing delay starting from [baseDelay], capped at 30s.
/// After exhausting retries, throws a [QueryException] wrapping the last error.
///
/// If [shouldAbort] is provided and returns `true` before a retry attempt,
/// the retry loop exits immediately by throwing a [QueryException]. This is
/// used to cancel retries when the device goes offline with [NetworkMode.online].
Future<T> retryWithBackoff<T>({
  required Future<T> Function() fn,
  required int maxAttempts,
  required Duration baseDelay,
  bool Function()? shouldAbort,
}) async {
  int attempts = 0;
  Object? lastError;
  StackTrace? lastStackTrace;

  while (true) {
    if (shouldAbort != null && shouldAbort()) {
      throw QueryException(
        'Operation aborted (network offline)',
        originalError: lastError,
        stackTrace: lastStackTrace,
      );
    }
    try {
      return await fn();
    } catch (e, st) {
      lastError = e;
      lastStackTrace = st;
      attempts++;
      if (attempts >= maxAttempts) {
        throw QueryException(
          'Operation failed after $attempts attempt(s)',
          originalError: lastError,
          stackTrace: lastStackTrace,
        );
      }
      final delayMs = baseDelay.inMilliseconds * (1 << (attempts - 1));
      final cappedMs = delayMs > 30000 ? 30000 : delayMs;
      await Future.delayed(Duration(milliseconds: cappedMs));
    }
  }
}
