/// Tracks how many active observers (controllers) are watching each key.
///
/// Keyed by the flattened serialized key. Single responsibility: reference
/// counting; the facade decides what to do when a count hits zero (schedule GC)
/// or leaves zero (cancel GC).
class ObserverRegistry {
  final Map<String, int> _counts = {};

  /// Register an observer; returns the new count.
  int increment(String key) => _counts[key] = (_counts[key] ?? 0) + 1;

  /// Unregister an observer; returns the remaining count (removes the entry
  /// when it reaches zero).
  int decrement(String key) {
    final count = (_counts[key] ?? 1) - 1;
    if (count <= 0) {
      _counts.remove(key);
      return 0;
    }
    _counts[key] = count;
    return count;
  }

  bool hasObservers(String key) => (_counts[key] ?? 0) > 0;

  void clear() => _counts.clear();
}
