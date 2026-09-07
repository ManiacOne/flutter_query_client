import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns stale-time timers and the listeners fired when data goes stale.
///
/// Keyed by the flattened serialized key. Single responsibility: schedule a
/// one-shot timer per key and notify its listeners when it elapses (SRP).
class StaleScheduler {
  final Map<String, Timer> _timers = {};
  final Map<String, Set<VoidCallback>> _listeners = {};

  void addListener(String key, VoidCallback cb) {
    _listeners.putIfAbsent(key, () => {}).add(cb);
  }

  void removeListener(String key, VoidCallback cb) {
    _listeners[key]?.remove(cb);
    if (_listeners[key]?.isEmpty ?? false) _listeners.remove(key);
  }

  /// (Re)arm the stale timer for [key]. A null [staleTime] just cancels it.
  void schedule(String key, Duration? staleTime) {
    _timers[key]?.cancel();
    _timers.remove(key);
    if (staleTime == null) return;
    _timers[key] = Timer(staleTime, () {
      _timers.remove(key);
      final callbacks = _listeners[key];
      if (callbacks != null) {
        for (final cb in callbacks.toList()) {
          cb();
        }
      }
    });
  }

  void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _listeners.clear();
  }

  int get timerCount => _timers.length;
}
