import 'package:flutter/widgets.dart';

typedef LifecycleCallback = void Function();

/// Owns a single [WidgetsBindingObserver] for the whole app and fans out
/// foreground/background transitions to registered controllers.
///
/// Backgrounding suspends `Timer.periodic`, so a polling query stops ticking
/// and its data can go stale; on resume controllers pause/resume their interval
/// and refetch as configured. One observer serves every controller (mirroring
/// [ConnectivityCoordinator]) rather than each `Cubit` registering its own.
class AppLifecycleCoordinator with WidgetsBindingObserver {
  bool _initialized = false;

  // Flat sets — a lifecycle change is app-global, so every subscriber fires.
  final Set<LifecycleCallback> _onResume = {};
  final Set<LifecycleCallback> _onPause = {};

  /// Lazily attach to [WidgetsBinding]. Safe to call repeatedly; degrades
  /// gracefully when there is no widgets binding (pure-Dart unit tests).
  void ensureInitialized() {
    if (_initialized) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
    } catch (_) {
      // No WidgetsFlutterBinding (e.g. a `flutter test` without pumping a
      // widget) — lifecycle features degrade to no-ops.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _fire(_onResume);
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _fire(_onPause);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _fire(Set<LifecycleCallback> callbacks) {
    for (final cb in callbacks.toList()) {
      try {
        cb();
      } catch (_) {
        // A transient error must not unregister a live controller.
      }
    }
  }

  void registerResume(LifecycleCallback cb) => _onResume.add(cb);
  void registerPause(LifecycleCallback cb) => _onPause.add(cb);
  void unregisterResume(LifecycleCallback cb) => _onResume.remove(cb);
  void unregisterPause(LifecycleCallback cb) => _onPause.remove(cb);

  int get resumeCallbackCount => _onResume.length;
  int get pauseCallbackCount => _onPause.length;

  void clearCallbacks() {
    _onResume.clear();
    _onPause.clear();
  }

  void dispose() {
    if (_initialized) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _initialized = false;
    }
    clearCallbacks();
  }
}
