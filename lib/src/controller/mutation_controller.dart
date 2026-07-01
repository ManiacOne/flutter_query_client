import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/client/query_client.dart';
import 'package:flutter_query_client/src/enums/query_status.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/query_state.dart';
import 'package:flutter_query_client/src/utils/error_transform_utils.dart';
import 'package:flutter_query_client/src/utils/query_logger.dart';
import 'package:flutter_query_client/src/utils/retry_utils.dart';

/// Base class for user-triggered mutations with typed params.
///
/// [T] is the result type. [P] is the params type:
///   - `void` for no-param mutations (call `mutate()` with no arguments)
///   - A record type like `({String title, double price})` for typed params
///
/// Subclasses must override [mutationFn] to define the mutation logic.
///
/// ```dart
/// class CreatePostMutation
///     extends MutationController<Post, ({String title, String body})> {
///   @override
///   Future<Post> mutationFn(({String title, String body}) params) {
///     return postService.createPost(title: params.title, body: params.body);
///   }
/// }
///
/// // Usage:
/// context.query<CreatePostMutation>().mutate((title: 'Hi', body: '...'));
/// ```
abstract class MutationController<T, P> extends Cubit<QueryState<T>> {
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

  // ─── Subclass contract ───────────────────────────────────────────

  /// The mutation function. Receives typed [P] params provided via [mutate].
  ///
  /// Override this in your subclass to define the mutation logic.
  Future<T> mutationFn(P params);

  // ─── Lifecycle hooks (override to customize) ─────────────────────

  /// Called after a successful mutation.
  void onSuccess(T data) {}

  /// Called after a failed mutation.
  void onMutationError(Object error) {}

  /// Called after mutation completes (success or error).
  void onSettled(T? data, Object? error) {}

  // ─── Mutate ──────────────────────────────────────────────────────

  /// Execute the mutation with optional [params].
  ///
  /// For `MutationController<T, void>`, call with no arguments: `mutate()`.
  /// For typed params, pass the params: `mutate((title: 'Hi', body: '...'))`.
  Future<void> mutate([P? params]) async {
    QueryLogger.fine('[Mutation] Starting mutation');
    _safeEmit(const QueryState(status: QueryStatus.loading));
    try {
      final result = await retryWithBackoff<T>(
        fn: () => mutationFn(params as P),
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
      _safeEmit(QueryState<T>(status: QueryStatus.error, error: transformed));
      onMutationError(transformed);
      onSettled(null, transformed);
    }
  }

  /// Reset mutation state to initial.
  void reset() => _safeEmit(const QueryState());
}
