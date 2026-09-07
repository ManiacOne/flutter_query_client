import 'dart:async';

/// Manages a periodic refetch interval timer with **wall-clock awareness**.
///
/// A plain `Timer.periodic` is suspended while the app is backgrounded and, on
/// resume, would simply restart its countdown — ignoring the time that passed.
/// This handle instead records when the interval last fired ([_lastTick]) so it
/// can tell whether a poll is overdue ([isPastDue]) and, on [resume], fire at
/// the *remaining* time (or immediately if the full interval already elapsed)
/// rather than starting a fresh countdown from zero.
class RefetchIntervalHandle {
  Timer? _timer;
  Duration? _interval;
  void Function()? _onTick;

  /// When the interval last fired (or was (re)started). The baseline for
  /// computing overdue/remaining time across pause/resume.
  DateTime? _lastTick;

  /// Start a periodic refetch timer. Automatically stops any existing timer and
  /// resets the wall-clock baseline to now.
  void start(Duration interval, void Function() onTick) {
    stop();
    _interval = interval;
    _onTick = onTick;
    _lastTick = DateTime.now();
    _timer = Timer.periodic(interval, (_) => _fire());
  }

  void _fire() {
    _lastTick = DateTime.now();
    _onTick?.call();
  }

  /// Pause the timer without losing the interval/callback or the last-tick
  /// baseline. Call [resume] to continue.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether a full interval has elapsed since the last tick — e.g. the app was
  /// backgrounded longer than the interval, so a poll is overdue. Callers check
  /// this on resume to decide whether to refetch immediately.
  bool get isPastDue {
    final interval = _interval;
    final last = _lastTick;
    if (interval == null || last == null) return false;
    return DateTime.now().difference(last) >= interval;
  }

  /// Resume a paused timer, aligned to wall-clock time.
  ///
  /// - If a full interval already elapsed while paused, the cadence restarts
  ///   from now (the caller fires the overdue tick — see [isPastDue]).
  /// - Otherwise the next tick fires after the *remaining* time so the original
  ///   cadence is preserved, then continues periodically.
  ///
  /// No-op if the timer was never started, was fully stopped, or is running.
  void resume() {
    final interval = _interval;
    final onTick = _onTick;
    final last = _lastTick;
    if (interval == null || onTick == null || last == null || _timer != null) {
      return;
    }
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= interval) {
      // Overdue: reset the baseline and resume the periodic cadence from now.
      // The overdue refetch itself is triggered by the caller (via isPastDue).
      _lastTick = DateTime.now();
      _timer = Timer.periodic(interval, (_) => _fire());
    } else {
      // Fire once at the remaining time, then go periodic — preserving cadence.
      _timer = Timer(interval - elapsed, () {
        _fire();
        _timer = Timer.periodic(interval, (_) => _fire());
      });
    }
  }

  /// Whether the timer is currently paused (started but not running).
  bool get isPaused => _timer == null && _interval != null && _onTick != null;

  /// Stop the periodic refetch timer and clear all configuration.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _interval = null;
    _onTick = null;
    _lastTick = null;
  }
}
