import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_query_client/src/utils/error_transform_utils.dart';
import 'package:flutter_query_client/src/utils/network_error.dart';
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

  /// Placeholder data carried across a [setParams] transition when
  /// [keepPreviousData] is set — the previous params' data, shown until the
  /// new params resolve. Cleared once new data lands.
  T? _placeholderData;

  /// Re-entrancy guard: true while this controller is mutating the cache
  /// itself, so its own cache-change callback is a no-op (it emits explicitly).
  bool _isSelfMutating = false;

  /// Stale-listener handle.
  late final StaleListenerHandle _staleHandle = StaleListenerHandle(
    client: client,
    cacheKey: cacheKey,
  );

  /// Periodic refetch handle.
  final RefetchIntervalHandle _refetchHandle = RefetchIntervalHandle();

  /// Callback stored for cache-change events — must be a stable reference
  /// so it can be removed on unregister.
  late final void Function(CacheChangeReason) _onCacheChange =
      _handleCacheChange;

  /// Stable reconnect callback reference.
  late final ReconnectCallback _onReconnect = _handleReconnect;

  /// Stable app-lifecycle callbacks.
  late final void Function() _onAppResume = _handleAppResume;
  late final void Function() _onAppPause = _handleAppPause;

  QueryController(this.cacheKey, {ErrorTransformer? transformError})
    : _transformError = transformError,
      _isVoidParams = _checkVoid<P>(),
      super(const QueryState()) {
    _serializedParams = serializeParams(_params);
    client.registerActiveQuery(
      cacheKey,
      _serializedParams,
      onCacheChange: _onCacheChange,
    );
    _registerConnectivity();
    _registerLifecycle();
    _execute();
  }

  static bool _checkVoid<X>() => null is X;

  // ─── Cache-derived state ─────────────────────────────────────────

  /// The cache entry for the current params, or null.
  CachedQueryData<T>? get _cached => client.get<T>(cacheKey, _serializedParams);

  /// `state` overlaid with the current cache data, so synchronous reads
  /// (`context.query<C>().state.data`) always reflect the cache — the single
  /// source of truth — even between emits. Placeholder states are left as-is
  /// because their data comes from a different params key.
  @override
  QueryState<T> get state {
    final base = super.state;
    if (base.isPlaceholderData) return base;
    final cached = _cached;
    // Build a fresh QueryState<T> rather than base.copyWith — the initial
    // `const QueryState()` can be inferred as QueryState<Null>, whose copyWith
    // would fail to cast non-null data.
    return QueryState<T>(
      data: cached?.data,
      error: base.error,
      status: base.status,
      fetchStatus: base.fetchStatus,
      isStale: cached?.isStale ?? base.isStale,
      isLoadingMore: base.isLoadingMore,
      isPlaceholderData: base.isPlaceholderData,
      params: _params,
    );
  }

  /// Emit a lifecycle state with `data`/`isStale`/`params` sourced from the
  /// cache. This is the load-bearing path: widget builders receive the emitted
  /// object (not the [state] getter), so data must be populated here.
  void _emitFromCache({
    required QueryStatus status,
    FetchStatus fetchStatus = FetchStatus.idle,
    Object? error,
  }) {
    final cached = _cached;
    _safeEmit(
      QueryState<T>(
        status: status,
        data: cached?.data,
        isStale: cached?.isStale ?? false,
        fetchStatus: fetchStatus,
        error: error,
        params: _params,
      ),
    );
  }

  /// Run a cache mutation initiated by this controller with the self-mutation
  /// guard raised, so the resulting cache-change callback is suppressed (the
  /// caller emits explicitly).
  void _selfMutate(void Function() fn) {
    _isSelfMutating = true;
    try {
      fn();
    } finally {
      _isSelfMutating = false;
    }
  }

  // ─── Safe emit ──────────────────────────────────────────────────

  void _safeEmit(QueryState<T> newState) {
    if (!isClosed) emit(newState);
  }

  // ─── Error transform ────────────────────────────────────────────

  /// Override to transform errors at the controller level.
  /// Falls back to the global transform in [QueryDefaults.transformError].
  ErrorTransformer? get transformError => _transformError;

  Object _applyTransformError(Object error) {
    // A network-type failure asks the observer to confirm reachability (it
    // won't flip offline on this alone). Server errors are left untouched.
    if (isNetworkError(error)) client.reportUnreachable();
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

  // Option getters. Each returns `null` when not overridden, so precedence is
  // **controller override → global [QueryDefaults] → hardcoded fallback**.
  // Override in a subclass and your value always wins over the global default.

  /// Whether to background-refetch when mounting with cached data.
  /// `null` defers to [QueryDefaults.refetchOnMount], then [RefetchOnMount.always].
  RefetchOnMount? get refetchOnMount => null;

  /// How long data is considered fresh. `null` defers to
  /// [QueryDefaults.staleTime] (then "never stale automatically").
  Duration? get staleTime => null;

  /// How long an unobserved cache entry is kept before garbage collection.
  /// `null` defers to [QueryDefaults.gcTime] (which itself defaults to `null` =
  /// keep forever).
  Duration? get gcTime => null;

  /// If set, the controller will automatically refetch at this interval.
  /// `null` defers to [QueryDefaults.refetchInterval] (then no polling).
  Duration? get refetchInterval => null;

  /// Number of retry attempts on failure. `null` defers to
  /// [QueryDefaults.retryCount], then `3` (like TanStack Query).
  int? get retryCount => null;

  /// Base delay between retries (exponential backoff). `null` defers to
  /// [QueryDefaults.retryDelay], then 1 second.
  Duration? get retryDelay => null;

  /// Controls whether this query requires network connectivity. `null` defers to
  /// [QueryDefaults.networkMode], then [NetworkMode.online].
  ///
  /// - [NetworkMode.online]: Pauses when offline, resumes on reconnect.
  /// - [NetworkMode.always]: Fetches regardless of connectivity.
  /// - [NetworkMode.offlineFirst]: Executes once, then requires network.
  NetworkMode? get networkMode => null;

  /// Whether this query refetches when connectivity is restored. `null` defers
  /// to [QueryDefaults.refetchOnReconnect], then [RefetchOnReconnect.ifStale].
  RefetchOnReconnect? get refetchOnReconnect => null;

  /// Whether this query refetches when the app returns to the foreground
  /// (mobile analogue of `refetchOnWindowFocus`). `null` defers to
  /// [QueryDefaults.refetchOnAppFocus], then [RefetchOnAppFocus.ifStale].
  RefetchOnAppFocus? get refetchOnAppFocus => null;

  /// Whether [refetchInterval] keeps polling while the app is backgrounded.
  /// `null` defers to [QueryDefaults.refetchIntervalInBackground], then `false`.
  bool? get refetchIntervalInBackground => null;

  /// When true, keeps the previous data visible (flagged
  /// [QueryState.isPlaceholderData]) while fetching after a [setParams] call.
  /// `null` defers to [QueryDefaults.keepPreviousData], then `false`.
  bool? get keepPreviousData => null;

  // ─── Lifecycle hooks (override to customize) ─────────────────────

  /// Called after a successful fetch or refetch.
  void onSuccess(T data) {}

  /// Called after a failed fetch or refetch.
  void onQueryError(Object error) {}

  // ─── Resolved defaults (controller override → global → hardcoded) ─

  Duration? get _resolvedStaleTime => staleTime ?? client.defaults.staleTime;
  Duration? get _resolvedGcTime => gcTime ?? client.defaults.gcTime;
  RefetchOnMount get _resolvedRefetchOnMount =>
      refetchOnMount ?? client.defaults.refetchOnMount ?? RefetchOnMount.always;
  int get _resolvedRetryCount => retryCount ?? client.defaults.retryCount ?? 3;
  Duration get _resolvedRetryDelay =>
      retryDelay ?? client.defaults.retryDelay ?? const Duration(seconds: 1);
  Duration? get _resolvedRefetchInterval =>
      refetchInterval ?? client.defaults.refetchInterval;
  NetworkMode get _resolvedNetworkMode =>
      networkMode ?? client.defaults.networkMode ?? NetworkMode.online;
  RefetchOnReconnect get _resolvedRefetchOnReconnect =>
      refetchOnReconnect ??
      client.defaults.refetchOnReconnect ??
      RefetchOnReconnect.ifStale;
  RefetchOnAppFocus get _resolvedRefetchOnAppFocus =>
      refetchOnAppFocus ??
      client.defaults.refetchOnAppFocus ??
      RefetchOnAppFocus.ifStale;
  bool get _resolvedRefetchIntervalInBackground =>
      refetchIntervalInBackground ??
      client.defaults.refetchIntervalInBackground ??
      false;
  bool get _resolvedKeepPreviousData =>
      keepPreviousData ?? client.defaults.keepPreviousData ?? false;

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

  /// Registers app foreground/background handling (lifecycle is app-global, so
  /// this is done once in the constructor, not per params).
  void _registerLifecycle() {
    client.ensureLifecycleInitialized();
    client.registerLifecycleCallbacks(
      onResume: _onAppResume,
      onPause: _onAppPause,
    );
  }

  void _unregisterLifecycle() {
    client.unregisterLifecycleCallbacks(
      onResume: _onAppResume,
      onPause: _onAppPause,
    );
  }

  /// App backgrounded — pause polling so a suspended timer doesn't drift
  /// (unless the query opts into background polling).
  void _handleAppPause() {
    if (isClosed) return;
    if (!_resolvedRefetchIntervalInBackground) _refetchHandle.pause();
  }

  /// App foregrounded — resume polling and refetch per [refetchOnAppFocus],
  /// catching up data that went stale while backgrounded.
  void _handleAppResume() {
    if (isClosed || !enabled) return;
    // Read overdue status BEFORE resuming (resume resets the baseline).
    final intervalPastDue = _refetchHandle.isPastDue;
    if (_refetchHandle.isPaused) _refetchHandle.resume();

    if (state.isError) {
      _execute();
      return;
    }
    final rof = _resolvedRefetchOnAppFocus;
    final wantFocusRefetch = rof == RefetchOnAppFocus.always ||
        (rof == RefetchOnAppFocus.ifStale && state.isStale);
    // A past-due poll fires regardless of refetchOnAppFocus — the interval was
    // due while backgrounded and should fire now, not a full period later.
    if (intervalPastDue || wantFocusRefetch || !state.hasData) {
      if (state.hasData) {
        _refetchInternal();
      } else {
        _execute();
      }
    }
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

    final dataIsStale = state.isStale;

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
    // Capture the current params' data as placeholder before switching keys,
    // so keepPreviousData can show it while the new params load.
    _placeholderData =
        _resolvedKeepPreviousData ? _cached?.data : null;

    _unregisterConnectivity();
    client.unregisterActiveQuery(
      cacheKey,
      _serializedParams,
      onCacheChange: _onCacheChange,
    );

    _params = params;
    _serializedParams = serializeParams(_params);

    client.registerActiveQuery(
      cacheKey,
      _serializedParams,
      onCacheChange: _onCacheChange,
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
      _placeholderData = null;
      await Future.delayed(Duration.zero);
      if (_serializedParams != capturedSerialized) return; // params changed
      _emitFromCache(status: QueryStatus.success);
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

    // keepPreviousData: show the previous params' data (captured in setParams)
    // with the isPlaceholderData flag while the new params fetch.
    if (_resolvedKeepPreviousData && _placeholderData != null) {
      _safeEmit(QueryState<T>(
        status: QueryStatus.success,
        data: _placeholderData,
        isPlaceholderData: true,
        fetchStatus: FetchStatus.fetching,
        params: _params,
      ));
    } else {
      _emitFromCache(status: QueryStatus.loading);
    }

    try {
      final result = await retryWithBackoff<T>(
        fn: () => queryFn(capturedParams),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );
      if (_serializedParams != capturedSerialized) return; // params changed

      // Mark offlineFirst as having completed its first execution.
      if (_resolvedNetworkMode == NetworkMode.offlineFirst) {
        _offlineFirstExecuted = true;
      }

      _placeholderData = null;
      _selfMutate(() => client.set(
        cacheKey,
        capturedSerialized,
        CachedQueryData(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      ));
      _registerStaleListener();
      _startRefetchInterval();
      QueryLogger.info('[$cacheKey] Fetch success');
      client.reportReachable();
      _emitFromCache(status: QueryStatus.success);
      if (!completer.isCompleted) completer.complete(result);
      onSuccess(result);
    } catch (e) {
      if (_serializedParams != capturedSerialized) return;
      final transformed = _applyTransformError(e);
      QueryLogger.severe('[$cacheKey] Fetch failed', e);
      _emitFromCache(status: QueryStatus.error, error: transformed);
      if (!completer.isCompleted) completer.completeError(e);
      // Ensure the completer's future error doesn't go unhandled.
      completer.future.ignore();
      onQueryError(transformed);
    } finally {
      if (_inFlightFetch == completer) _inFlightFetch = null;
    }
  }

  // ─── Remount (hidden → visible) ───────────────────────────────────

  /// Called by the provider when the widget transitions from hidden → visible
  /// (e.g. switching tabs in an `IndexedStack` or toggling `Visibility`).
  ///
  /// **Note:** Has no effect when the provider is placed at the root level
  /// (e.g. in `MultiQueryProvider` at the app root) because the widget never
  /// unmounts or becomes hidden — so `refetchOnMount` will never trigger.
  /// Use `updateCache`, `refetch`, or `invalidate` to push updates to a
  /// root-level controller from child screens.
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
    final cached = _cached;

    if (cached == null) return;

    // Re-emit success from the cache. External writes while hidden already
    // notified via the cache-change subscription; this ensures a fresh frame.
    _emitFromCache(status: QueryStatus.success);

    _startRefetchInterval();

    final rom = _resolvedRefetchOnMount;
    if (rom == RefetchOnMount.always ||
        (rom == RefetchOnMount.stale && cached.isStale)) {
      _refetchInternal();
    }
  }

  // ─── Cache-change callback ───────────────────────────────────────

  /// Invoked by [QueryClient] when the cache entry for the current params
  /// changes. Implements the split eviction policy: `updated` → success from
  /// cache; `invalidated` → refetch; `cleared`/`evicted` → empty.
  void _handleCacheChange(CacheChangeReason reason) {
    if (isClosed || _isSelfMutating) return;

    switch (reason) {
      case CacheChangeReason.updated:
      case CacheChangeReason.statusChanged:
        // Another controller (or client.update) wrote fresh data. Reflect it,
        // unless we're mid-fetch/error where our own flow will emit.
        if (_cached != null && !state.isLoading) {
          _emitFromCache(status: QueryStatus.success);
        }
      case CacheChangeReason.invalidated:
        if (enabled) {
          refetch();
        } else {
          _emitFromCache(status: QueryStatus.idle);
        }
      case CacheChangeReason.cleared:
      case CacheChangeReason.evicted:
        _placeholderData = null;
        _staleHandle.unregister();
        _safeEmit(QueryState<T>(status: QueryStatus.idle, params: _params));
    }
  }

  // ─── ensureData (TanStack's ensureQueryData) ─────────────────────

  /// Ensures data is available — returns cached data if fresh, otherwise
  /// fetches, caches, and returns the result.
  Future<T> ensureData([P? params]) async {
    if (params != null) {
      _params = params;
      _serializedParams = serializeParams(_params);
    }

    // Capture params to guard against concurrent setParams() calls.
    final capturedParams = _params;
    final capturedSerialized = _serializedParams ?? serializeParams(_params);
    _serializedParams = capturedSerialized;

    final cached = client.get<T>(cacheKey, capturedSerialized);
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

    final completer = Completer<T>();
    _inFlightFetch = completer;

    try {
      _emitFromCache(status: QueryStatus.loading);
      final result = await retryWithBackoff<T>(
        fn: () => queryFn(capturedParams),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );
      if (_serializedParams != capturedSerialized) {
        completer.completeError(
          QueryException('Params changed during ensureData'),
        );
        completer.future.ignore();
        throw QueryException('Params changed during ensureData');
      }
      _selfMutate(() => client.set(
        cacheKey,
        capturedSerialized,
        CachedQueryData(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      ));
      _registerStaleListener();
      client.reportReachable();
      _emitFromCache(status: QueryStatus.success);
      completer.complete(result);
      return result;
    } catch (e) {
      _emitFromCache(
        status: QueryStatus.error,
        error: _applyTransformError(e),
      );
      if (!completer.isCompleted) {
        completer.completeError(e);
        completer.future.ignore();
      }
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

    // Capture params to guard against concurrent setParams() calls.
    final capturedParams = _params;
    final capturedSerialized = _serializedParams;

    QueryLogger.fine('[$cacheKey] Refetching...');
    _safeEmit(state.copyWith(fetchStatus: FetchStatus.refetching));
    try {
      final result = await retryWithBackoff<T>(
        fn: () => queryFn(capturedParams),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );
      if (_serializedParams != capturedSerialized) return;
      _placeholderData = null;
      _selfMutate(() => client.set(
        cacheKey,
        capturedSerialized,
        CachedQueryData(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      ));
      _registerStaleListener();
      _startRefetchInterval();
      client.reportReachable();
      _emitFromCache(status: QueryStatus.success);
      onSuccess(result);
    } catch (e) {
      if (_serializedParams != capturedSerialized) return;
      final transformed = _applyTransformError(e);
      _emitFromCache(status: QueryStatus.error, error: transformed);
      onQueryError(transformed);
    }
  }

  // ─── Cache operations ────────────────────────────────────────────

  Future<void> updateCache(T? Function(T? current) updater) async {
    await Future.delayed(Duration.zero);
    final cached = _cached;
    final updatedData = updater(cached?.data);
    if (updatedData == null) return;
    _selfMutate(() => client.set(
      cacheKey,
      _serializedParams,
      CachedQueryData(
        data: updatedData,
        fetchTime: DateTime.now(),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
      ),
    ));
    _registerStaleListener();
    _emitFromCache(status: QueryStatus.success);
  }

  Future<void> invalidate() async {
    // Guard so the resulting cache-change callback doesn't also refetch — we
    // do it explicitly below.
    _selfMutate(() => client.invalidate(cacheKey, _serializedParams));
    await refetch();
  }

  // ─── Param-scoped access ─────────────────────────────────────────

  /// Synchronously read cached data for the given [params] (defaults to the
  /// controller's current params). Reads the [QueryClient] cache — the single
  /// source of truth — so callers don't reach for the client directly.
  T? dataFor([P? params]) {
    final serialized =
        params != null ? serializeParams(params) : _serializedParams;
    return client.get<T>(cacheKey, serialized)?.data;
  }

  /// Fetch and cache data for arbitrary [params] without disturbing this
  /// controller's current params or emitted state. Returns fresh cached data
  /// when present and not stale, otherwise fetches via [queryFn].
  Future<T> fetchFor(P params) async {
    final serialized = serializeParams(params);
    final cached = client.get<T>(cacheKey, serialized);
    if (cached != null && cached.data != null && !cached.isStale) {
      return cached.data;
    }
    final result = await retryWithBackoff<T>(
      fn: () => queryFn(params),
      maxAttempts: _resolvedRetryCount,
      baseDelay: _resolvedRetryDelay,
      shouldAbort: () => _shouldPause,
    );
    client.set(
      cacheKey,
      serialized,
      CachedQueryData(
        data: result,
        fetchTime: DateTime.now(),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
      ),
    );
    client.reportReachable();
    return result;
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
    _unregisterLifecycle();
    client.unregisterActiveQuery(
      cacheKey,
      _serializedParams,
      onCacheChange: _onCacheChange,
    );
    _staleHandle.unregister();
    _refetchHandle.stop();
    return super.close();
  }
}
