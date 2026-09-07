import 'dart:async';

import 'package:bloc/bloc.dart' show Bloc, BlocObserver;
import 'package:flutter/widgets.dart';
import 'package:flutter_query_client/src/client/app_lifecycle_coordinator.dart';
import 'package:flutter_query_client/src/client/cache_change_notifier.dart';
import 'package:flutter_query_client/src/client/cache_keys.dart';
import 'package:flutter_query_client/src/client/connectivity_coordinator.dart';
import 'package:flutter_query_client/src/client/gc_scheduler.dart';
import 'package:flutter_query_client/src/client/observer_registry.dart';
import 'package:flutter_query_client/src/client/query_cache_store.dart';
import 'package:flutter_query_client/src/client/query_runtime.dart';
import 'package:flutter_query_client/src/client/stale_scheduler.dart';
import 'package:flutter_query_client/src/enums/cache_change_reason.dart';
import 'package:flutter_query_client/src/enums/connectivity_status.dart';
import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/query_status.dart';
import 'package:flutter_query_client/src/models/cached_query_data.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/models/query_exception.dart';
import 'package:flutter_query_client/src/query_state.dart';
import 'package:flutter_query_client/src/utils/network_error.dart';
import 'package:flutter_query_client/src/utils/retry_utils.dart';

export 'package:flutter_query_client/src/client/connectivity_coordinator.dart'
    show ReconnectCallback;

/// Facade over the query cache and its collaborators.
///
/// Holds no cache logic itself — it composes focused collaborators (each with a
/// single responsibility) and exposes the public API by delegating to them:
///
/// * [QueryCacheStore] — the two-level data store
/// * [CacheChangeNotifier] — per-key change subscriptions
/// * [StaleScheduler] — stale-time timers + listeners
/// * [GcScheduler] — garbage-collection timers
/// * [ObserverRegistry] — active-observer reference counting
/// * [ConnectivityCoordinator] — network status + reconnect callbacks
class QueryClient {
  static final QueryClient instance = QueryClient._internal();

  final QueryCacheStore _store = QueryCacheStore();
  final QueryRuntimeStore _runtime = QueryRuntimeStore();
  final CacheChangeNotifier _notifier = CacheChangeNotifier();
  final StaleScheduler _stale = StaleScheduler();
  final ObserverRegistry _observers = ObserverRegistry();
  final ConnectivityCoordinator _connectivity = ConnectivityCoordinator();
  final AppLifecycleCoordinator _lifecycle = AppLifecycleCoordinator();
  late final GcScheduler _gc = GcScheduler(
    gcTimeFor: (baseKey, params) =>
        _store.raw(baseKey, params)?.gcTime ?? _defaults.gcTime,
    hasObservers: (key) => _observers.hasObservers(key),
    onEvict: (baseKey, params) => removeQueries(baseKey, params),
  );

  QueryDefaults _defaults = const QueryDefaults();

  QueryClient._internal();

  // ─── Defaults & observer ─────────────────────────────────────────

  QueryDefaults get defaults => _defaults;

  void setDefaults(QueryDefaults defaults) {
    _defaults = defaults;
  }

  /// Register a [QueryObserver] to receive typed lifecycle events from every
  /// [QueryController], [InfiniteQueryController], and [MutationController].
  ///
  /// Internally sets [Bloc.observer], so no direct `flutter_bloc` dependency
  /// is required in your app.
  void setObserver(BlocObserver observer) {
    Bloc.observer = observer;
  }

  // ─── Network connectivity ────────────────────────────────────────

  /// Whether the device currently has network connectivity. Optimistically
  /// `true` until connectivity is initialized.
  bool get isOnline => _connectivity.isOnline;

  /// Ensures the connectivity observer is initialized. Called fire-and-forget
  /// from controller constructors; errors degrade gracefully.
  Future<void> ensureConnectivityInitialized() =>
      _connectivity.ensureInitialized(_defaults.connectivityProbeTargets);

  /// Registers the callback invoked on every connectivity change (both
  /// directions). Set via [QueryClientProvider.onConnectivityChanged].
  void setConnectivityChangedCallback(
    void Function(ConnectivityStatus status)? callback,
  ) =>
      _connectivity.setConnectivityChangedCallback(callback);

  /// Report that a real network request succeeded — the most authoritative
  /// "online" signal. A no-op if connectivity has not been initialized.
  void reportReachable() => _connectivity.reportReachable();

  /// Report that a request failed with a network-type error. Asks the observer
  /// to confirm with a probe rather than flipping offline directly.
  void reportUnreachable() => _connectivity.reportUnreachable();

  // ─── App lifecycle ───────────────────────────────────────────────

  /// Lazily attach the single app-lifecycle observer. Called fire-and-forget
  /// from controllers that poll or refetch on focus.
  void ensureLifecycleInitialized() => _lifecycle.ensureInitialized();

  void registerLifecycleCallbacks({
    required LifecycleCallback onResume,
    required LifecycleCallback onPause,
  }) {
    _lifecycle.registerResume(onResume);
    _lifecycle.registerPause(onPause);
  }

  void unregisterLifecycleCallbacks({
    required LifecycleCallback onResume,
    required LifecycleCallback onPause,
  }) {
    _lifecycle.unregisterResume(onResume);
    _lifecycle.unregisterPause(onPause);
  }

  /// Simulate an app foreground/background transition (for tests without a
  /// real widgets binding).
  @visibleForTesting
  void emitAppLifecycle(AppLifecycleState state) =>
      _lifecycle.didChangeAppLifecycleState(state);

  void registerReconnectCallback(
    String baseKey,
    String? params,
    ReconnectCallback callback,
  ) =>
      _connectivity.registerReconnect(serializeKey(baseKey, params), callback);

  void unregisterReconnectCallback(
    String baseKey,
    String? params,
    ReconnectCallback callback,
  ) =>
      _connectivity.unregisterReconnect(serializeKey(baseKey, params), callback);

  // ─── Cache access ────────────────────────────────────────────────

  CachedQueryData<T>? get<T>(String baseKey, [String? params]) =>
      _store.get<T>(baseKey, params);

  /// Read cached data by [baseKey] and typed [params] without a controller.
  T? getData<T>(String baseKey, [Object? params]) =>
      _store.get<T>(baseKey, serializeParams(params))?.data;

  void set<T>(String baseKey, String? params, CachedQueryData<T> value) {
    final key = serializeKey(baseKey, params);
    _store.put<T>(baseKey, params, value);
    // Reflect the write in the fetch lifecycle so `stateFor` reports success.
    final rt = _runtime.of(key);
    rt.status = QueryStatus.success;
    rt.fetchStatus = FetchStatus.idle;
    rt.error = null;
    rt.invalidated = false;
    _stale.schedule(key, value.staleTime);
    _notifier.notify(key, CacheChangeReason.updated);
  }

  /// The full [QueryState] for a `(baseKey, params)` — data (from the cache
  /// store) merged with fetch lifecycle (from the runtime store). This makes
  /// status addressable by params, so one controller can expose per-param
  /// loading via `stateFor` without a separate instance per param.
  QueryState<T> stateFor<T>(String baseKey, [Object? params]) {
    final serialized = serializeParams(params);
    final cached = _store.get<T>(baseKey, serialized);
    final rt = _runtime.peek(serializeKey(baseKey, serialized));
    return QueryState<T>(
      data: cached?.data,
      error: rt?.error,
      status: rt?.status ??
          (cached != null ? QueryStatus.success : QueryStatus.idle),
      fetchStatus: rt?.fetchStatus ?? FetchStatus.idle,
      isStale: (cached?.isStale ?? false) || (rt?.invalidated ?? false),
      params: params,
    );
  }

  bool _shouldPause(NetworkMode mode, QueryRuntime rt) {
    if (mode == NetworkMode.always) return false;
    if (mode == NetworkMode.offlineFirst && !rt.offlineFirstExecuted) {
      return false;
    }
    return !isOnline;
  }

  /// Fetch (and cache) data for `(baseKey, params)` — the **record-owned**
  /// fetch loop. Ownership of retry, in-flight dedup, network gating, and
  /// status transitions lives here rather than in the caller, so:
  ///
  /// * multiple callers of the same key coalesce into ONE request (dedup), and
  /// * status is written to the shared runtime, visible to every observer via
  ///   [stateFor] (per-param loading, shared status).
  ///
  /// Returns fresh cached data when present and not stale (unless [force]).
  Future<T?> fetchQuery<T>(
    String baseKey,
    Object? params, {
    required Future<T> Function() queryFn,
    Duration? staleTime,
    Duration? gcTime,
    int retryCount = 3,
    Duration retryDelay = const Duration(seconds: 1),
    NetworkMode networkMode = NetworkMode.online,
    Object Function(Object error)? transformError,
    bool force = false,
  }) async {
    final serialized = serializeParams(params);
    final key = serializeKey(baseKey, serialized);
    final rt = _runtime.of(key);

    // Dedup: join an in-flight request for the same key.
    if (rt.inFlight != null) {
      try {
        return await rt.inFlight!.future as T?;
      } catch (_) {
        // Fall through and retry below if the shared fetch failed.
      }
    }

    final cached = _store.get<T>(baseKey, serialized);
    if (!force && cached != null && !cached.isStale) {
      rt.status = QueryStatus.success;
      rt.fetchStatus = FetchStatus.idle;
      return cached.data;
    }

    if (_shouldPause(networkMode, rt)) {
      rt.fetchStatus = FetchStatus.paused;
      _notifier.notify(key, CacheChangeReason.statusChanged);
      if (cached != null) return cached.data;
      throw QueryException('Cannot fetch: device is offline');
    }

    final completer = Completer<Object?>();
    rt.inFlight = completer;
    final hasData = cached != null;
    rt.status = hasData ? QueryStatus.success : QueryStatus.loading;
    rt.fetchStatus = hasData ? FetchStatus.refetching : FetchStatus.fetching;
    rt.error = null;
    _notifier.notify(key, CacheChangeReason.statusChanged);

    try {
      final result = await retryWithBackoff<T>(
        fn: queryFn,
        maxAttempts: retryCount,
        baseDelay: retryDelay,
        shouldAbort: () => _shouldPause(networkMode, rt),
      );
      if (networkMode == NetworkMode.offlineFirst) {
        rt.offlineFirstExecuted = true;
      }
      reportReachable();
      // `set` writes data and flips the runtime to success + notifies.
      set<T>(
        baseKey,
        serialized,
        CachedQueryData<T>(
          data: result,
          fetchTime: DateTime.now(),
          staleTime: staleTime,
          gcTime: gcTime,
        ),
      );
      completer.complete(result);
      return result;
    } catch (e) {
      if (isNetworkError(e)) reportUnreachable();
      rt.status = QueryStatus.error;
      rt.error = transformError?.call(e) ?? e;
      rt.fetchStatus = FetchStatus.idle;
      _notifier.notify(key, CacheChangeReason.statusChanged);
      completer.completeError(e);
      completer.future.ignore();
      return cached?.data;
    } finally {
      if (identical(rt.inFlight, completer)) rt.inFlight = null;
    }
  }

  // ─── Invalidation ───────────────────────────────────────────────

  /// Invalidate a specific cache entry for the given key + params.
  ///
  /// [reason] defaults to [CacheChangeReason.invalidated]; GC eviction passes
  /// Invalidate a cache entry: mark it stale and ask active observers to
  /// refetch — **without discarding the existing data**. The current data stays
  /// visible (with a refetching/stale indicator) until fresh data replaces it.
  /// To actually drop data, use [removeQueries] or [clear] (TanStack semantics).
  void invalidate(String baseKey, [String? params]) {
    final key = serializeKey(baseKey, params);
    _stale.cancel(key);
    _runtime.of(key).invalidated = true;
    // Notify even when no entry existed — an active controller may still be
    // watching this key and needs to refetch.
    _notifier.notify(key, CacheChangeReason.invalidated);
  }

  /// Invalidate ALL cache entries under a base key (keeps data, refetches).
  void invalidateAll(String baseKey) {
    for (final params in _store.paramKeys(baseKey)) {
      invalidate(baseKey, params);
    }
  }

  /// Hard-remove a cache entry: drops the data and resets its lifecycle. Used
  /// by garbage collection ([CacheChangeReason.evicted]); call directly for a
  /// TanStack `removeQueries`-style purge.
  void removeQueries(
    String baseKey, [
    String? params,
    CacheChangeReason reason = CacheChangeReason.evicted,
  ]) {
    final key = serializeKey(baseKey, params);
    _stale.cancel(key);
    _gc.cancel(key);
    _store.remove(baseKey, params);
    final rt = _runtime.peek(key);
    if (rt != null) {
      rt.status = QueryStatus.idle;
      rt.fetchStatus = FetchStatus.idle;
      rt.error = null;
      rt.invalidated = false;
    }
    _notifier.notify(key, reason);
  }

  /// Invalidate multiple query keys and trigger refetch on active controllers.
  void invalidateQueries(List<String> baseKeys) {
    for (final baseKey in baseKeys) {
      final params = _store.paramKeys(baseKey);
      if (params.isEmpty) {
        // No cache, but there may still be active controllers to notify.
        _notifier.notify(serializeKey(baseKey, null), CacheChangeReason.invalidated);
        continue;
      }
      for (final p in params) {
        invalidate(baseKey, p);
      }
    }
  }

  // ─── Update ──────────────────────────────────────────────────────

  /// Update data across all param variants of a base key.
  void update<T>(String baseKey, T? Function(T current) updater) {
    final paramMap = _store.baseMap(baseKey);
    if (paramMap == null) return;
    for (final paramKey in paramMap.keys.toList()) {
      try {
        final cached = paramMap[paramKey]!;
        final currentData = cached.data as T;
        final updated = updater(currentData);
        if (updated == null) continue;
        _store.put<T>(
          baseKey,
          paramKey,
          CachedQueryData<T>(
            data: updated,
            fetchTime: cached.fetchTime,
            staleTime: cached.staleTime,
            gcTime: cached.gcTime,
          ),
        );
        _notifier.notify(
            serializeKey(baseKey, paramKey), CacheChangeReason.updated);
      } catch (_) {
        // Type mismatch or other error — skip this entry.
      }
    }
  }

  /// Type-safe update for infinite query caches (pages array).
  void updateInfiniteQuery<T>(
    String baseKey,
    List<List<T>> Function(List<List<T>> currentPages) updater,
  ) {
    update<List<List<T>>>(baseKey, (current) => updater(current));
  }

  // ─── Active observer registry ────────────────────────────────────

  /// Register an active controller for a cache key. The optional
  /// [onCacheChange] callback fires (with the reason) on every change to this
  /// key's entry.
  void registerActiveQuery(
    String baseKey,
    String? params, {
    void Function(CacheChangeReason)? onCacheChange,
  }) {
    final key = serializeKey(baseKey, params);
    _observers.increment(key);
    _gc.cancel(key); // an active observer is watching this key
    if (onCacheChange != null) _notifier.add(key, onCacheChange);
  }

  /// Unregister an active controller. When the last observer leaves, schedules
  /// garbage collection.
  void unregisterActiveQuery(
    String baseKey,
    String? params, {
    void Function(CacheChangeReason)? onCacheChange,
  }) {
    final key = serializeKey(baseKey, params);
    if (_observers.decrement(key) == 0) {
      _gc.schedule(key, baseKey, params);
    }
    if (onCacheChange != null) _notifier.remove(key, onCacheChange);
  }

  // ─── Stale-time listeners ────────────────────────────────────────

  void addStaleListener(String baseKey, String? params, VoidCallback callback) =>
      _stale.addListener(serializeKey(baseKey, params), callback);

  void removeStaleListener(
    String baseKey,
    String? params,
    VoidCallback callback,
  ) =>
      _stale.removeListener(serializeKey(baseKey, params), callback);

  // ─── Clear / dispose ─────────────────────────────────────────────

  void clear() {
    // Snapshot subscribers before wiping so mounted controllers get a
    // `cleared` signal (their callback then reads back null from the store).
    final subscribers = _notifier.subscribers;

    _store.clear();
    _stale.clear();
    _gc.clear();

    for (final cb in subscribers) {
      try {
        cb(CacheChangeReason.cleared);
      } catch (_) {
        // Dead controller — ignore; registry is cleared below.
      }
    }

    _runtime.clear();
    _observers.clear();
    _notifier.clearAll();
    _connectivity.clearReconnect();
    _lifecycle.clearCallbacks();
  }

  /// Dispose connectivity and clean up all resources. Call on app shutdown /
  /// in tests.
  void dispose() {
    clear();
    _connectivity.dispose();
    _lifecycle.dispose();
  }

  // ─── Diagnostics ─────────────────────────────────────────────────

  int get activeStaleTimerCount => _stale.timerCount;
  int get activeGcTimerCount => _gc.timerCount;
  int get activeCacheChangeCallbackCount => _notifier.callbackCount;

  /// Deprecated alias for [activeCacheChangeCallbackCount].
  int get activeInvalidateCallbackCount => _notifier.callbackCount;

  int get activeReconnectCallbackCount => _connectivity.reconnectCallbackCount;

  int get cacheEntryCount => _store.entryCount;
}
