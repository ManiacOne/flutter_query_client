import 'dart:async';

import 'package:flutter_query_client/src/enums/connectivity_status.dart';
import 'package:flutter_query_client/src/network/network_connectivity_observer.dart';
import 'package:flutter_query_client/src/network/probe_target.dart';

/// Callback invoked when the device reconnects to the network.
///
/// [isStale] indicates whether the controller's data is currently stale,
/// allowing reconnect handlers to decide based on `RefetchOnReconnect`.
typedef ReconnectCallback = void Function({required bool isStale});

/// Owns everything network-connectivity related: lazy observer initialization,
/// the external status callback, request-outcome reporting, and per-key
/// reconnect subscriptions.
///
/// The rest of the client depends only on this coordinator, not on the
/// `NetworkConnectivityObserver` directly (DIP).
class ConnectivityCoordinator {
  NetworkConnectivityObserver? _observer;
  StreamSubscription<bool>? _subscription;

  /// Reconnect callbacks keyed by the flattened serialized key. Each active
  /// controller with `networkMode != always` registers here.
  final Map<String, Set<ReconnectCallback>> _reconnectCallbacks = {};

  void Function(ConnectivityStatus status)? _externalCallback;

  /// Whether the device currently has connectivity. Optimistically `true`
  /// until the observer is initialized, so startup queries aren't blocked.
  bool get isOnline => _observer?.isOnline ?? true;

  /// Lazily initialize the observer. Safe to call repeatedly; errors (e.g. no
  /// platform channel in tests) degrade gracefully to always-online.
  Future<void> ensureInitialized(List<ProbeTarget>? probeTargets) async {
    if (_observer != null) return;
    _observer = NetworkConnectivityObserver.instance;
    if (probeTargets != null && probeTargets.isNotEmpty) {
      NetworkConnectivityObserver.probeTargets = probeTargets;
    }
    try {
      await _observer!.initialize();
      _subscription = _observer!.onStatusChange.listen(_onChange);
    } catch (_) {
      // Platform channel unavailable — connectivity features degrade;
      // isOnline stays true.
    }
  }

  void setConnectivityChangedCallback(
    void Function(ConnectivityStatus status)? callback,
  ) {
    _externalCallback = callback;
  }

  void reportReachable() => _observer?.reportReachable();
  void reportUnreachable() => _observer?.reportUnreachable();

  void _onChange(bool isOnline) {
    _externalCallback?.call(
      isOnline ? ConnectivityStatus.online : ConnectivityStatus.offline,
    );
    if (!isOnline) return;
    for (final entry in _reconnectCallbacks.entries.toList()) {
      for (final cb in entry.value.toList()) {
        try {
          cb(isStale: false);
        } catch (_) {
          // Transient error — don't unregister a live controller's callback.
        }
      }
    }
  }

  void registerReconnect(String key, ReconnectCallback callback) {
    _reconnectCallbacks.putIfAbsent(key, () => {}).add(callback);
  }

  void unregisterReconnect(String key, ReconnectCallback callback) {
    _reconnectCallbacks[key]?.remove(callback);
    if (_reconnectCallbacks[key]?.isEmpty ?? false) {
      _reconnectCallbacks.remove(key);
    }
  }

  /// Drop all reconnect subscriptions (used by `clear()`).
  void clearReconnect() => _reconnectCallbacks.clear();

  int get reconnectCallbackCount =>
      _reconnectCallbacks.values.fold(0, (sum, set) => sum + set.length);

  /// Tear down the observer and subscription (used by `dispose()`).
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _observer?.dispose();
    _observer = null;
  }
}
