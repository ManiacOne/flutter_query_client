import 'dart:async';

/// Manages a periodic refetch interval timer.
///
/// Encapsulates the start/stop lifecycle of the refetch polling timer.
/// Supports pausing when the device is offline and resuming on reconnect.
class RefetchIntervalHandle {
  Timer? _timer;
  Duration? _interval;
  void Function()? _onTick;

  /// Start a periodic refetch timer. Automatically stops any existing timer.
  ///
  /// [interval] — how often to refetch.
  /// [onTick] — callback invoked on each interval tick.
  void start(Duration interval, void Function() onTick) {
    stop();
    _interval = interval;
    _onTick = onTick;
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  /// Pause the timer without losing the interval/callback.
  ///
  /// Call [resume] to restart with the same configuration.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Resume a previously paused timer.
  ///
  /// No-op if the timer was never started or was fully stopped.
  void resume() {
    if (_interval != null && _onTick != null && _timer == null) {
      _timer = Timer.periodic(_interval!, (_) => _onTick!());
    }
  }

  /// Whether the timer is currently paused (was started but not running).
  bool get isPaused => _timer == null && _interval != null && _onTick != null;

  /// Stop the periodic refetch timer and clear configuration.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _interval = null;
    _onTick = null;
  }
}
