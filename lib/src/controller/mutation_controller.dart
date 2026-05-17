import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/client/query_client.dart';
import 'package:flutter_query_client/src/enums/query_status.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/query_state.dart';
import 'package:flutter_query_client/src/utils/error_transform_utils.dart';
import 'package:flutter_query_client/src/utils/query_logger.dart';
import 'package:flutter_query_client/src/utils/retry_utils.dart';

abstract class MutationController<T> extends Cubit<QueryState<T>> {
  final QueryClient _client = QueryClient.instance;
  final ErrorTransformer? _transformError;

  MutationController({ErrorTransformer? transformError})
      : _transformError = transformError,
        super(const QueryState());

  /// Number of retries on failure. Default 0 (mutations don't auto-retry).
  ///
  /// Unlike queries, mutations are user-triggered actions and should fail fast.
  /// Override this only if you explicitly want retry behavior for this mutation.
  /// **Note**: Global [QueryDefaults.retryCount] is intentionally NOT applied
  /// to mutations — only the controller-level override is used.
  int get retryCount => 0;

  /// Base delay between retries. Actual delay uses exponential backoff.
  Duration get retryDelay => const Duration(seconds: 1);

  // ─── Resolved defaults ───────────────────────────────────────────

  // Mutations intentionally DO NOT inherit global retryCount —
  // retrying mutations automatically is dangerous (duplicate writes, etc).
  // Only the controller-level retryCount is used.
  int get _resolvedRetryCount => retryCount;
  Duration get _resolvedRetryDelay =>
      _client.defaults.retryDelay ?? retryDelay;

  // ─── Safe emit ──────────────────────────────────────────────────

  void _safeEmit(QueryState<T> newState) {
    if (!isClosed) emit(newState);
  }

  // ─── Error transform ────────────────────────────────────────────

  Object _applyTransformError(Object error) {
    return applyErrorTransform(
      error: error,
      controllerTransform: _transformError,
      globalTransform: _client.defaults.transformError,
    );
  }

  // ─── Lifecycle hooks (override to customize) ─────────────────────

  /// Called after a successful mutation.
  void onSuccess(T data) {}

  /// Called after a failed mutation.
  void onMutationError(Object error) {}

  /// Called after mutation completes (success or error).
  void onSettled(T? data, Object? error) {}

  // ─── Mutate ──────────────────────────────────────────────────────

  Future<void> mutate(Future<T> Function() mutationFn) async {
    QueryLogger.fine('[Mutation] Starting mutation');
    _safeEmit(const QueryState(status: QueryStatus.loading));
    try {
      final result = await retryWithBackoff<T>(
        fn: mutationFn,
        maxAttempts: _resolvedRetryCount + 1,
        baseDelay: _resolvedRetryDelay,
      );
      QueryLogger.info('[Mutation] Success');
      _safeEmit(QueryState<T>(status: QueryStatus.success, data: result));
      onSuccess(result);
      onSettled(result, null);
    } catch (e) {
      final transformed = _applyTransformError(e);
      QueryLogger.warning('[Mutation] Error: $transformed');
      _safeEmit(state.copyWith(status: QueryStatus.error, error: transformed));
      onMutationError(transformed);
      onSettled(null, transformed);
    }
  }

  /// Reset mutation state to initial.
  void reset() => _safeEmit(const QueryState());
}
