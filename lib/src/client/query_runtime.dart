import 'dart:async';

import 'package:flutter_query_client/src/enums/query_status.dart';

/// The fetch lifecycle for a single `(key, params)` — the part of a query's
/// state that is NOT data: status, fetchStatus, error, the in-flight request
/// (for dedup), and offline-first bookkeeping.
///
/// Together with the data in [QueryCacheStore], this is the per-`(key,params)`
/// "record" that makes status a single source of truth addressable by params.
class QueryRuntime {
  QueryStatus status = QueryStatus.idle;
  FetchStatus fetchStatus = FetchStatus.idle;
  Object? error;

  /// In-flight request shared by all callers of the same key — the basis of
  /// request dedup.
  Completer<Object?>? inFlight;

  /// Whether an offline-first query has completed its first execution.
  bool offlineFirstExecuted = false;

  /// Set by `invalidate` and cleared on the next successful fetch. While true
  /// the entry is considered stale even if its `staleTime` has not elapsed — so
  /// the (kept) data can be shown with a stale/refetching indicator until fresh
  /// data arrives.
  bool invalidated = false;
}

/// Owns the per-key [QueryRuntime] records. Single responsibility: fetch-
/// lifecycle state storage, keyed by the flattened serialized key.
class QueryRuntimeStore {
  final Map<String, QueryRuntime> _runtimes = {};

  /// Get (creating if needed) the runtime for [flatKey].
  QueryRuntime of(String flatKey) =>
      _runtimes.putIfAbsent(flatKey, QueryRuntime.new);

  /// Read the runtime for [flatKey] without creating one.
  QueryRuntime? peek(String flatKey) => _runtimes[flatKey];

  void remove(String flatKey) => _runtimes.remove(flatKey);

  void clear() => _runtimes.clear();
}
