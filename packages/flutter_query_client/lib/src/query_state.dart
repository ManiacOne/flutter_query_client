import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_query_client/src/enums/query_status.dart';

part 'query_state.freezed.dart';

@freezed
abstract class QueryState<V> with _$QueryState<V> {
  const QueryState._();

  const factory QueryState({
    V? data,
    Object? error,
    @Default(QueryStatus.idle) QueryStatus status,
    @Default(FetchStatus.idle) FetchStatus fetchStatus,
    @Default(false) bool isStale,
    @Default(false) bool isLoadingMore,
  }) = _QueryState<V>;

  // ─── Convenience getters ─────────────────────────────────────────

  bool get isLoading => status == QueryStatus.loading;
  bool get isSuccess => status == QueryStatus.success;
  bool get isError => status == QueryStatus.error;
  bool get isIdle => status == QueryStatus.idle;
  bool get isRefetching => fetchStatus == FetchStatus.refetching;
  bool get isFetching => fetchStatus == FetchStatus.fetching;
  bool get isPaused => fetchStatus == FetchStatus.paused;
  bool get hasData => data != null;
  bool get hasError => error != null;

  /// Safely cast [error] to type [E]. Returns null if error is not of type [E].
  E? errorAs<E>() => error is E ? error as E : null;
}

