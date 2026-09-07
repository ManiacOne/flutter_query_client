import 'dart:async';

/// Owns garbage-collection timers for cache entries with no active observers.
///
/// Depends on injected abstractions rather than the client (DIP/OCP): it asks
/// [gcTimeFor] how long to wait, [hasObservers] whether the entry is still
/// unobserved when the timer fires, and calls [onEvict] to remove it.
class GcScheduler {
  GcScheduler({
    required this.gcTimeFor,
    required this.hasObservers,
    required this.onEvict,
  });

  final Duration? Function(String baseKey, String? params) gcTimeFor;
  final bool Function(String serializedKey) hasObservers;
  final void Function(String baseKey, String? params) onEvict;

  final Map<String, Timer> _timers = {};

  /// Schedule eviction of `(baseKey, params)` after its gcTime, keyed by the
  /// already-flattened [serializedKey].
  void schedule(String serializedKey, String baseKey, String? params) {
    final gcTime = gcTimeFor(baseKey, params);
    if (gcTime == null) return; // null = keep forever

    _timers[serializedKey]?.cancel();
    _timers[serializedKey] = Timer(gcTime, () {
      _timers.remove(serializedKey);
      if (!hasObservers(serializedKey)) {
        onEvict(baseKey, params);
      }
    });
  }

  void cancel(String serializedKey) {
    _timers[serializedKey]?.cancel();
    _timers.remove(serializedKey);
  }

  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  int get timerCount => _timers.length;
}
