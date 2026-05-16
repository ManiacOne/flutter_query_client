import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/refetch_on_reconnect.dart';
import 'package:flutter_query_client/src/models/cached_query_data.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/network/network_connectivity_observer.dart';

/// Callback invoked when the device reconnects to the network.
///
/// [isStale] indicates whether the controller's data is currently stale,
/// allowing reconnect handlers to decide based on [RefetchOnReconnect].
typedef ReconnectCallback = void Function({required bool isStale});

class QueryClient {
  static final QueryClient instance = QueryClient._internal();

  /// Two-level cache: baseKey → { serializedParams → CachedQueryData }.
  final Map<String, Map<String?, CachedQueryData>> _cache = {};

  // ─── Stale-time observer pattern ─────────────────────────────────

  final Map<String, Timer> _staleTimers = {};
  final Map<String, Set<VoidCallback>> _staleCallbacks = {};

  // ─── Active observer registry ────────────────────────────────────

  final Map<String, int> _observerCounts = {};
  final Map<String, Set<VoidCallback>> _invalidateCallbacks = {};

  // ─── Garbage collection ──────────────────────────────────────────

  final Map<String, Timer> _gcTimers = {};

  // ─── Network connectivity ────────────────────────────────────────

  NetworkConnectivityObserver? _networkObserver;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Registry of reconnect callbacks keyed by serialized key.
  /// Each active controller with networkMode != always registers here.
  final Map<String, Set<ReconnectCallback>> _reconnectCallbacks = {};

  // ─── Global defaults ─────────────────────────────────────────────

  QueryDefaults _defaults = const QueryDefaults();

  QueryClient._internal();

  QueryDefaults get defaults => _defaults;

  void setDefaults(QueryDefaults defaults) {
    _defaults = defaults;
  }

  // ─── Network connectivity ────────────────────────────────────────

  /// Whether the device currently has network connectivity.
  ///
  /// Returns `true` if the observer has not been initialized (optimistic
  /// default to avoid blocking queries on startup).
  bool get isOnline => _networkObserver?.isOnline ?? true;

  /// Ensures the [NetworkConnectivityObserver] is initialized.
  ///
  /// Called lazily when the first controller with [NetworkMode.online] or
  /// [NetworkMode.offlineFirst] registers. Safe to call multiple times.
  /// Called fire-and-forget from constructors — errors are swallowed
  /// gracefully (connectivity features degrade to always-online).
  Future<void> ensureConnectivityInitialized() async {
    if (_networkObserver != null) return;
    _networkObserver = NetworkConnectivityObserver.instance;
    try {
      await _networkObserver!.initialize(
        customEndpoints: _defaults.connectivityEndpoints,
      );
      _connectivitySubscription =
          _networkObserver!.onStatusChange.listen(_onConnectivityChange);
    } catch (_) {
      // Platform channel not available (e.g. in test environment).
      // Connectivity features degrade gracefully — isOnline stays true.
    }
  }

  void _onConnectivityChange(bool isOnline) {
    if (!isOnline) return;
    // Device came online — notify all registered reconnect callbacks.
    for (final callbacks in _reconnectCallbacks.values) {
      for (final cb in callbacks.toList()) {
        cb(isStale: false); // Controllers determine staleness themselves.
      }
    }
  }

  /// Register a reconnect callback for the given cache key.
  ///
  /// Controllers call this so they can be notified when the device
  /// reconnects to the network.
  void registerReconnectCallback(
    String baseKey,
    String? params,
    ReconnectCallback callback,
  ) {
    final key = _serialize(baseKey, params);
    _reconnectCallbacks.putIfAbsent(key, () => {}).add(callback);
  }

  /// Unregister a reconnect callback for the given cache key.
  void unregisterReconnectCallback(
    String baseKey,
    String? params,
    ReconnectCallback callback,
  ) {
    final key = _serialize(baseKey, params);
    _reconnectCallbacks[key]?.remove(callback);
    if (_reconnectCallbacks[key]?.isEmpty ?? false) {
      _reconnectCallbacks.remove(key);
    }
  }

  // ─── Cache access ────────────────────────────────────────────────

  CachedQueryData<T>? get<T>(String baseKey, [String? params]) {
    return _cache[baseKey]?[params] as CachedQueryData<T>?;
  }

  void set<T>(String baseKey, String? params, CachedQueryData<T> value) {
    _cache.putIfAbsent(baseKey, () => {})[params] = value;
    _scheduleStaleNotification(_serialize(baseKey, params), value.staleTime);
  }

  // ─── Invalidation ───────────────────────────────────────────────

  /// Invalidate a specific cache entry for the given key + params.
  void invalidate(String baseKey, [String? params]) {
    final paramMap = _cache[baseKey];
    if (paramMap == null) return;
    paramMap.remove(params);
    if (paramMap.isEmpty) _cache.remove(baseKey);

    final serialized = _serialize(baseKey, params);
    _staleTimers[serialized]?.cancel();
    _staleTimers.remove(serialized);
    _gcTimers[serialized]?.cancel();
    _gcTimers.remove(serialized);
  }

  /// Invalidate ALL cache entries under a base key, regardless of params.
  void invalidateAll(String baseKey) {
    final paramMap = _cache.remove(baseKey);
    if (paramMap == null) return;
    for (final params in paramMap.keys) {
      final serialized = _serialize(baseKey, params);
      _staleTimers[serialized]?.cancel();
      _staleTimers.remove(serialized);
      _gcTimers[serialized]?.cancel();
      _gcTimers.remove(serialized);
    }
  }

  /// Invalidate multiple query keys and trigger refetch on active controllers.
  ///
  /// For each key, all param variants are invalidated and any active
  /// controllers watching those keys are notified to refetch.
  void invalidateQueries(List<String> baseKeys) {
    for (final baseKey in baseKeys) {
      final paramMap = _cache[baseKey];
      if (paramMap == null) {
        // No cache, but there may still be active controllers to notify.
        _notifyInvalidateCallbacks(baseKey, null);
        continue;
      }
      final paramKeys = paramMap.keys.toList();
      for (final params in paramKeys) {
        invalidate(baseKey, params);
        _notifyInvalidateCallbacks(baseKey, params);
      }
    }
  }

  void _notifyInvalidateCallbacks(String baseKey, String? params) {
    final key = _serialize(baseKey, params);
    final callbacks = _invalidateCallbacks[key];
    if (callbacks == null) return;
    for (final cb in callbacks.toList()) {
      cb();
    }
  }

  // ─── Update ──────────────────────────────────────────────────────

  /// Update data across all param variants of a base key.
  ///
  /// The [updater] callback receives the current data for each param entry.
  /// Return the updated value to replace it, or `null` to skip that entry.
  /// Type mismatches are silently skipped.
  void update<T>(String baseKey, T? Function(T current) updater) {
    final paramMap = _cache[baseKey];
    if (paramMap == null) return;
    for (final paramKey in paramMap.keys.toList()) {
      try {
        final cached = paramMap[paramKey]!;
        final currentData = cached.data as T;
        final updated = updater(currentData);
        if (updated == null) continue;
        paramMap[paramKey] = CachedQueryData<T>(
          data: updated,
          fetchTime: cached.fetchTime,
          staleTime: cached.staleTime,
          gcTime: cached.gcTime,
        );
      } catch (_) {
        // Type mismatch or other error — skip this entry
      }
    }
  }

  /// Type-safe update for infinite query caches (pages array).
  ///
  /// Operates on the raw `List<List<T>>` page structure. For simple
  /// item-level updates, use the controller's `updateItem`/`removeItem`
  /// methods instead.
  void updateInfiniteQuery<T>(
    String baseKey,
    List<List<T>> Function(List<List<T>> currentPages) updater,
  ) {
    update<List<List<T>>>(baseKey, (current) => updater(current));
  }

  // ─── Active observer registry ────────────────────────────────────

  /// Register an active controller for a cache key.
  ///
  /// Cancels any pending GC timer for this key. The optional [onInvalidate]
  /// callback is invoked when [invalidateQueries] targets this key.
  void registerActiveQuery(
    String baseKey,
    String? params, {
    VoidCallback? onInvalidate,
  }) {
    final key = _serialize(baseKey, params);
    _observerCounts[key] = (_observerCounts[key] ?? 0) + 1;

    // Cancel GC — an active controller is watching this key.
    _gcTimers[key]?.cancel();
    _gcTimers.remove(key);

    if (onInvalidate != null) {
      _invalidateCallbacks.putIfAbsent(key, () => {}).add(onInvalidate);
    }
  }

  /// Unregister an active controller for a cache key.
  ///
  /// When the last observer leaves, schedules garbage collection.
  void unregisterActiveQuery(
    String baseKey,
    String? params, {
    VoidCallback? onInvalidate,
  }) {
    final key = _serialize(baseKey, params);
    final count = (_observerCounts[key] ?? 1) - 1;

    if (count <= 0) {
      _observerCounts.remove(key);
      _scheduleGc(baseKey, params);
    } else {
      _observerCounts[key] = count;
    }

    if (onInvalidate != null) {
      _invalidateCallbacks[key]?.remove(onInvalidate);
      if (_invalidateCallbacks[key]?.isEmpty ?? false) {
        _invalidateCallbacks.remove(key);
      }
    }
  }

  // ─── Garbage collection ──────────────────────────────────────────

  void _scheduleGc(String baseKey, String? params) {
    final key = _serialize(baseKey, params);
    final cached = _cache[baseKey]?[params];
    final gcTime = cached?.gcTime ?? _defaults.gcTime;
    if (gcTime == null) return; // null = keep forever

    _gcTimers[key]?.cancel();
    _gcTimers[key] = Timer(gcTime, () {
      _gcTimers.remove(key);
      // Only remove if still no observers.
      if ((_observerCounts[key] ?? 0) == 0) {
        invalidate(baseKey, params);
      }
    });
  }

  // ─── Stale-time observer pattern ─────────────────────────────────

  void addStaleListener(
    String baseKey,
    String? params,
    VoidCallback callback,
  ) {
    final serialized = _serialize(baseKey, params);
    _staleCallbacks.putIfAbsent(serialized, () => {}).add(callback);
  }

  void removeStaleListener(
    String baseKey,
    String? params,
    VoidCallback callback,
  ) {
    final serialized = _serialize(baseKey, params);
    _staleCallbacks[serialized]?.remove(callback);
    if (_staleCallbacks[serialized]?.isEmpty ?? false) {
      _staleCallbacks.remove(serialized);
    }
  }

  void _scheduleStaleNotification(String key, Duration? staleTime) {
    _staleTimers[key]?.cancel();
    _staleTimers.remove(key);
    if (staleTime == null) return;
    _staleTimers[key] = Timer(staleTime, () {
      _staleTimers.remove(key);
      final callbacks = _staleCallbacks[key];
      if (callbacks != null) {
        for (final cb in callbacks.toList()) {
          cb();
        }
      }
    });
  }

  // ─── Clear ───────────────────────────────────────────────────────

  void clear() {
    _cache.clear();
    for (final timer in _staleTimers.values) {
      timer.cancel();
    }
    _staleTimers.clear();
    for (final timer in _gcTimers.values) {
      timer.cancel();
    }
    _gcTimers.clear();
    _observerCounts.clear();
    _invalidateCallbacks.clear();
    _reconnectCallbacks.clear();
  }

  /// Dispose the connectivity observer and clean up all resources.
  ///
  /// Call this when the app is shutting down or in tests.
  void dispose() {
    clear();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _networkObserver?.dispose();
    _networkObserver = null;
  }

  // ─── Internal ────────────────────────────────────────────────────

  String _serialize(String baseKey, String? params) {
    if (params == null || params.isEmpty) return baseKey;
    return '$baseKey:$params';
  }
}
