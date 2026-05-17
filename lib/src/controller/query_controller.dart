import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_query_client/src/helpers.dart';
import 'package:flutter_query_client/src/utils/error_transform_utils.dart';
import 'package:flutter_query_client/src/utils/refetch_interval_handle.dart';
import 'package:flutter_query_client/src/utils/retry_utils.dart';
import 'package:flutter_query_client/src/utils/stale_listener_handle.dart';
/// Base class for reactive data fetching with typed params.
///
/// [T] is the data type. [P] is the params type:
///   - `void` for no-param queries (always enabled, auto-fetches on mount)
///   - `int`, `String`, etc. for single-param dependent queries
///   - A record like `({int orgId, String? name})` for multi-param queries
///
/// The [enabled] getter auto-derives from P:
///   - P == void → always true
///   - P != void → true when params != null
abstract class QueryController<T, P> extends Cubit<QueryState<T>> {
  final String cacheKey;
  final QueryClient client = QueryClient.instance;
  final ErrorTransformer? _transformError;

  P? _params;
  String? _serializedParams;
  final bool _isVoidParams;

  /// Tracks an in-flight fetch from [_execute] so [ensureData] can await it
  /// instead of starting a duplicate request.
  Completer<T>? _inFlightFetch;

  /// Whether initial execution has been done for [NetworkMode.offlineFirst].
  bool _offlineFirstExecuted = false;

  /// Stale-listener handle.
  late final StaleListenerHandle _staleHandle = StaleListenerHandle(
    client: client,
    cacheKey: cacheKey,
  );

  /// Periodic refetch handle.
  final RefetchIntervalHandle _refetchHandle = RefetchIntervalHandle();

  /// Callback stored for invalidation — must be a stable reference
  /// so it can be removed on unregister.
  late final VoidCallback _onInvalidate = _handleInvalidation;

  /// Stable reconnect callback reference.
  late final ReconnectCallback _onReconnect = _handleReconnect;

  QueryController(this.cacheKey, {ErrorTransformer? transformError})
    : _transformError = transformError,
      _isVoidParams = _checkVoid<P>(),
      super(const QueryState()) {
    _serializedParams = serializeParams(_params);
    client.registerActiveQuery(
      cacheKey,
      _serializedParams,
      onInvalidate: _onInvalidate,
    );
    _registerConnectivity();
    _execute();
  }

  static bool _checkVoid<X>() => null is X;

  // ─── Safe emit ──────────────────────────────────────────────────

  void _safeEmit(QueryState<T> newState) {
    if (!isClosed) emit(newState);
  }

  // ─── Error transform ────────────────────────────────────────────

  /// Override to transform errors at the controller level.
  /// Falls back to the global transform in [QueryDefaults.transformError].
  ErrorTransformer? get transformError => _transformError;

  Object _applyTransformError(Object error) {
    return applyErrorTransform(
      error: error,
      controllerTransform: transformError,
      globalTransform: client.defaults.transformError,
    );
  }

  // ─── Subclass contract ───────────────────────────────────────────

  /// The fetch function. Receives [P?] params.
  Future<T> queryFn(P? params);

  /// Whether this query should execute.
  bool get enabled => _isVoidParams || _params != null;

  /// Whether to background-refetch when mounting with cached data.
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;

  /// How long data is considered fresh. null = never stale automatically.
  Duration? get staleTime => null;

  /// If set, the controller will automatically refetch at this interval.
  Duration? get refetchInterval => null;

  /// Number of retry attempts on failure. Default 3 (like TanStack Query).
  int get retryCount => 3;

  /// Base delay between retries. Actual delay uses exponential backoff.
  Duration get retryDelay => const Duration(seconds: 1);

  /// Controls whether this query requires network connectivity.
  ///
  /// - [NetworkMode.online] (default): Pauses when offline, resumes on reconnect.
  /// - [NetworkMode.always]: Fetches regardless of connectivity.
  /// - [NetworkMode.offlineFirst]: Executes once (e.g. from local cache),
  ///   then requires network for subsequent fetches.
  NetworkMode get networkMode => NetworkMode.online;

  /// Controls whether this query refetches when network connectivity is restored.
  ///
  /// - [RefetchOnReconnect.always]: Always refetch on reconnect.
  /// - [RefetchOnReconnect.ifStale] (default): Only refetch if data is stale.
  /// - [RefetchOnReconnect.never]: Never auto-refetch on reconnect.
  RefetchOnReconnect get refetchOnReconnect => RefetchOnReconnect.ifStale;

  /// When true, keeps the previous data visible (with [QueryState.isPlaceholderData]
  /// set to true) while fetching new data after a [setParams] call.
  /// Similar to TanStack Query's `keepPreviousData` / `placeholderData`.
  bool get keepPreviousData => false;

  // ─── Lifecycle hooks (override to customize) ─────────────────────

  /// Called after a successful fetch or refetch.
  void onSuccess(T data) {}

  /// Called after a failed fetch or refetch.
  void onQueryError(Object error) {}

  // ─── Resolved defaults (controller override → global → hardcoded) ─

  Duration? get _resolvedStaleTime => staleTime ?? client.defaults.staleTime;
  RefetchOnMount get _resolvedRefetchOnMount =>
      client.defaults.refetchOnMount ?? refetchOnMount;
  int get _resolvedRetryCount => client.defaults.retryCount ?? retryCount;
  Duration get _resolvedRetryDelay => client.defaults.retryDelay ?? retryDelay;
  Duration? get _resolvedRefetchInterval =>
      refetchInterval ?? client.defaults.refetchInterval;
  Duration? get _resolvedGcTime => client.defaults.gcTime;
  NetworkMode get _resolvedNetworkMode =>
      client.defaults.networkMode ?? networkMode;
  RefetchOnReconnect get _resolvedRefetchOnReconnect =>
      client.defaults.refetchOnReconnect ?? refetchOnReconnect;

  // ─── Network helpers ────────────────────────────────────────────

  /// Whether the controller should block fetching due to network state.
  bool get _shouldPause {
    final mode = _resolvedNetworkMode;
    if (mode == NetworkMode.always) return false;
    if (mode == NetworkMode.offlineFirst && !_offlineFirstExecuted) {
      return false;
    }
    return !client.isOnline;
  }

  /// Registers for connectivity events if this controller needs network.
  void _registerConnectivity() {
    final mode = _resolvedNetworkMode;
    if (mode == NetworkMode.always) return;
    // Fire-and-forget — errors are handled internally.
    client.ensureConnectivityInitialized().ignore();
    client.registerReconnectCallback(cacheKey, _serializedParams, _onReconnect);
  }

  /// Unregisters connectivity events.
  void _unregisterConnectivity() {
    client.unregisterReconnectCallback(
      cacheKey,
      _serializedParams,
      _onReconnect,
    );
  }

  /// Called when the device reconnects to the network.
  void _handleReconnect({required bool isStale}) {
    if (isClosed || !enabled) return;
    if (_resolvedNetworkMode == NetworkMode.always) return;

    QueryLogger.info('[$cacheKey] Network reconnected');

    // Resume polling timer if it was paused.
    if (_refetchHandle.isPaused) _refetchHandle.resume();

    // Always refetch if in error state — the failure was likely network-related.
    if (state.isError) {
      QueryLogger.info('[$cacheKey] Retrying after error (reconnect)');
      _execute();
      return;
    }

    final ror = _resolvedRefetchOnReconnect;
    if (ror == RefetchOnReconnect.never) return;

    final dataIsStale =
        state.isStale ||
        (state.hasData &&
            _resolvedStaleTime != null &&
            client.get<T>(cacheKey, _serializedParams)?.isStale == true);

    if (ror == RefetchOnReconnect.ifStale && !dataIsStale && state.hasData) {
      // Data is fresh — just clear paused status if set.
      if (state.isPaused) {
        _safeEmit(state.copyWith(fetchStatus: FetchStatus.idle));
      }
      QueryLogger.fine(
        '[$cacheKey] Skipping reconnect refetch (data is fresh)',
      );
      return;
    }

    QueryLogger.info(
      '[$cacheKey] Refetching on reconnect (refetchOnReconnect: ${ror.name})',
    );
    // Refetch: use _execute() if no data yet, _refetchInternal() if we have data.
    if (state.hasData) {
      _refetchInternal();
    } else {
      _execute();
    }
  }

  // ─── Params ──────────────────────────────────────────────────────

  P? get params => _params;

  /// Update params and re-execute if enabled.
  void setParams(P params) {
    _unregisterConnectivity();
    client.unregisterActiveQuery(
      cacheKey,
      _serializedParams,
      onInvalidate: _onInvalidate,
    );

    _params = params;
    _serializedParams = serializeParams(_params);

    client.registerActiveQuery(
      cacheKey,
      _serializedParams,
      onInvalidate: _onInvalidate,
    );
    _registerConnectivity();

    _execute();
  }

  // ─── Core execution ──────────────────────────────────────────────

  Future<void> _execute() async {
    if (!enabled) return;

    // Capture params locally to guard against concurrent setParams() calls.
    final capturedParams = _params;
    final capturedSerialized = serializeParams(capturedParams);
    _serializedParams = capturedSerialized;

    final cached = client.get<T>(cacheKey, capturedSerialized);

    if (cached != null) {
      QueryLogger.info('[$cacheKey] Cache hit (stale: ${cached.isStale})');
      await Future.delayed(Duration.zero);
      if (_serializedParams != capturedSerialized) return; // params changed
      _safeEmit(
        QueryState<T>(
          status: QueryStatus.success,
          data: cached.data,
          isStale: cached.isStale,
        ),
      );
      _registerStaleListener();
      _startRefetchInterval();
      final rom = _resolvedRefetchOnMount;
      if (rom == RefetchOnMount.always ||
          (rom == RefetchOnMount.stale && cached.isStale)) {
        QueryLogger.fine(
          '[$cacheKey] Triggering background refetch (refetchOnMount: ${rom.name})',
        );
        _refetchInternal();
      }
      return;
    }

    // Check if we should pause due to network state.
    if (_shouldPause) {
      QueryLogger.warning(
        '[$cacheKey] Paused — device is offline (networkMode: ${_resolvedNetworkMode.name})',
      );
      await Future.delayed(Duration.zero);
      if (_serializedParams != capturedSerialized) return;
      _safeEmit(state.copyWith(fetchStatus: FetchStatus.paused));
      return;
    }

    final completer = Completer<T>();
    _inFlightFetch = completer;

    await Future.delayed(Duration.zero);
    if (_serializedParams != capturedSerialized) return; // params changed
    QueryLogger.info('[$cacheKey] Fetching...');

    // keepPreviousData: show old data with isPlaceholderData flag while fetching
    final previousData = state.data;
    if (keepPreviousData && previousData != null) {
      _safeEmit(QueryState<T>(
        status: QueryStatus.success,
        data: previousData,
        isPlaceholderData: true,
        fetchStatus: FetchStatus.fetching,
      ));
    } else {
      _safeEmit(const QueryState(status: QueryStatus.loading));
    }

    try {
      final result = await retryWithBackoff<T>(
        fn: () => queryFn(capturedParams),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: _shouldPause ? () => true : null,
      );
      if (_serializedParams != capturedSerialized) return; // params changed

      // Mark offlineFirst as having completed its first execution.
      if (_resolvedNetworkMode == NetworkMode.offlineFirst) {
        _offlineFirstExecuted = true;
      }

      client.set(
        cacheKey,
        capturedSerialized,
        CachedQueryData(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      );
      _registerStaleListener();
      _startRefetchInterval();
      QueryLogger.info('[$cacheKey] Fetch success');
      _safeEmit(QueryState<T>(status: QueryStatus.success, data: result));
      if (!completer.isCompleted) completer.complete(result);
      onSuccess(result);
    } catch (e) {
      if (_serializedParams != capturedSerialized) return;
      final transformed = _applyTransformError(e);
      QueryLogger.severe('[$cacheKey] Fetch failed', e);
      _safeEmit(
        QueryState<T>(
          status: QueryStatus.error,
          error: transformed,
        ),
      );
      if (!completer.isCompleted) completer.completeError(e);
      // Ensure the completer's future error doesn't go unhandled.
      completer.future.ignore();
      onQueryError(transformed);
    } finally {
      if (_inFlightFetch == completer) _inFlightFetch = null;
    }
  }

  // ─── Remount (hidden → visible) ───────────────────────────────────

  /// Called by the provider when the widget transitions from hidden → visible.
  void handleRemount() {
    if (!enabled) return;
    if (state.isLoading || state.isRefetching) return;

    // Always retry if in error state — the network issue may have resolved.
    if (state.isError) {
      QueryLogger.info('[$cacheKey] Retrying after error (remount)');
      _execute();
      return;
    }

    _serializedParams = serializeParams(_params);
    final cached = client.get<T>(cacheKey, _serializedParams);

    if (cached == null) return;

    if (cached.data != state.data) {
      _safeEmit(
        QueryState<T>(
          status: QueryStatus.success,
          data: cached.data,
          isStale: cached.isStale,
        ),
      );
    }

    final rom = _resolvedRefetchOnMount;
    if (rom == RefetchOnMount.always ||
        (rom == RefetchOnMount.stale && cached.isStale)) {
      _refetchInternal();
    }
  }

  // ─── Invalidation callback ───────────────────────────────────────

  void _handleInvalidation() {
    if (!isClosed) refetch();
  }

  // ─── ensureData (TanStack's ensureQueryData) ─────────────────────

  /// Ensures data is available — returns cached data if fresh, otherwise
  /// fetches, caches, and returns the result.
  Future<T> ensureData([P? params]) async {
    if (params != null) {
      _params = params;
      _serializedParams = serializeParams(_params);
    }

    _serializedParams ??= serializeParams(_params);
    final cached = client.get<T>(cacheKey, _serializedParams);
    if (cached != null && cached.data != null && !cached.isStale) {
      return cached.data;
    }

    // Check network before attempting fetch.
    if (_shouldPause) {
      // If we have stale cached data, return it rather than blocking.
      if (cached != null && cached.data != null) return cached.data;
      throw QueryException(
        'Cannot fetch data: device is offline',
        originalError: null,
      );
    }

    if (_inFlightFetch != null) {
      try {
        return await _inFlightFetch!.future;
      } catch (_) {
        // In-flight fetch failed — fall through to retry below
      }
    }

    _serializedParams ??= serializeParams(_params);
    final completer = Completer<T>();
    _inFlightFetch = completer;

    try {
      _safeEmit(const QueryState(status: QueryStatus.loading));
      final result = await retryWithBackoff<T>(
        fn: () => queryFn(_params),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );
      client.set(
        cacheKey,
        _serializedParams,
        CachedQueryData(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      );
      _registerStaleListener();
      _safeEmit(QueryState<T>(status: QueryStatus.success, data: result));
      completer.complete(result);
      return result;
    } catch (e) {
      _safeEmit(
        QueryState<T>(
          status: QueryStatus.error,
          error: _applyTransformError(e),
        ),
      );
      completer.completeError(e);
      rethrow;
    } finally {
      if (_inFlightFetch == completer) _inFlightFetch = null;
    }
  }

  // ─── Refetch ─────────────────────────────────────────────────────

  Future<void> refetch() async {
    if (!enabled) return;
    await _refetchInternal();
  }

  Future<void> _refetchInternal() async {
    // Check network before refetching.
    if (_shouldPause) {
      QueryLogger.warning('[$cacheKey] Refetch paused — device is offline');
      _safeEmit(state.copyWith(fetchStatus: FetchStatus.paused));
      _refetchHandle.pause();
      return;
    }

    QueryLogger.fine('[$cacheKey] Refetching...');
    _safeEmit(state.copyWith(fetchStatus: FetchStatus.refetching));
    try {
      final result = await retryWithBackoff<T>(
        fn: () => queryFn(_params),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );
      client.set(
        cacheKey,
        _serializedParams,
        CachedQueryData(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      );
      _registerStaleListener();
      _startRefetchInterval();
      _safeEmit(
        state.copyWith(
          status: QueryStatus.success,
          data: result,
          fetchStatus: FetchStatus.idle,
          isStale: false,
        ),
      );
      onSuccess(result);
    } catch (e) {
      final transformed = _applyTransformError(e);
      _safeEmit(
        state.copyWith(
          error: transformed,
          fetchStatus: FetchStatus.idle,
        ),
      );
      onQueryError(transformed);
    }
  }

  // ─── Cache operations ────────────────────────────────────────────

  Future<void> updateCache(T? Function(T? current) updater) async {
    await Future.delayed(Duration.zero);
    final cached = client.get<T>(cacheKey, _serializedParams);
    final updatedData = updater(cached?.data);
    if (updatedData == null) return;
    client.set(
      cacheKey,
      _serializedParams,
      CachedQueryData(
        data: updatedData,
        fetchTime: DateTime.now(),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
      ),
    );
    _registerStaleListener();
    _safeEmit(
      state.copyWith(
        status: QueryStatus.success,
        data: updatedData,
        isStale: false,
      ),
    );
  }

  Future<void> invalidate() async {
    client.invalidate(cacheKey, _serializedParams);
    await refetch();
  }

  // ─── Stale listener management ───────────────────────────────────

  void _registerStaleListener() {
    if (isClosed || _resolvedStaleTime == null) return;
    _staleHandle.register(_serializedParams, () {
      if (!isClosed) {
        _safeEmit(state.copyWith(isStale: true));
      }
    });
  }

  // ─── Refetch interval (polling) ──────────────────────────────────

  void _startRefetchInterval() {
    final interval = _resolvedRefetchInterval;
    if (interval == null || isClosed) return;
    _refetchHandle.start(interval, () {
      if (!isClosed && !state.isRefetching && !state.isLoading) {
        _refetchInternal();
      }
    });
  }

  @override
  Future<void> close() {
    _unregisterConnectivity();
    client.unregisterActiveQuery(
      cacheKey,
      _serializedParams,
      onInvalidate: _onInvalidate,
    );
    _staleHandle.unregister();
    _refetchHandle.stop();
    return super.close();
  }
}
