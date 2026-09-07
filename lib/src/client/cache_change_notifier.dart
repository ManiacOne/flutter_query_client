import 'package:flutter_query_client/src/enums/cache_change_reason.dart';

typedef CacheChangeCallback = void Function(CacheChangeReason reason);

/// Owns the per-key cache-change subscriptions and their delivery.
///
/// Keyed by the flattened serialized key (see `serializeKey`). This is how
/// controllers keep their state derived from the cache — the single
/// responsibility here is subscription bookkeeping + notification (SRP).
class CacheChangeNotifier {
  final Map<String, Set<CacheChangeCallback>> _callbacks = {};

  void add(String key, CacheChangeCallback cb) {
    _callbacks.putIfAbsent(key, () => {}).add(cb);
  }

  void remove(String key, CacheChangeCallback cb) {
    _callbacks[key]?.remove(cb);
    if (_callbacks[key]?.isEmpty ?? false) _callbacks.remove(key);
  }

  /// Deliver [reason] to every subscriber of [key]. Callbacks that throw are
  /// dropped (a dead controller), never propagated.
  void notify(String key, CacheChangeReason reason) {
    final callbacks = _callbacks[key];
    if (callbacks == null) return;
    final stale = <CacheChangeCallback>[];
    for (final cb in callbacks.toList()) {
      try {
        cb(reason);
      } catch (_) {
        stale.add(cb);
      }
    }
    callbacks.removeAll(stale);
    if (callbacks.isEmpty) _callbacks.remove(key);
  }

  /// A flat snapshot of every subscriber, across all keys — used by `clear()`
  /// to broadcast a `cleared` reason before the registry is emptied.
  List<CacheChangeCallback> get subscribers =>
      _callbacks.values.expand((set) => set).toList(growable: false);

  void clearAll() => _callbacks.clear();

  int get callbackCount =>
      _callbacks.values.fold(0, (sum, set) => sum + set.length);
}
