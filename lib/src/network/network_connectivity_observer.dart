import 'dart:async';

import 'package:flutter/services.dart';

import '../utils/query_logger.dart';
import 'native_connectivity_channel.dart';
import 'probe_target.dart';

/// Observes device internet connectivity, the way production apps do it:
/// the app's own request outcomes are the primary source of truth, an OS
/// event provides an instant trigger, and an active probe is only a
/// confirmation/tiebreaker.
///
/// Signals, in order of authority:
/// 1. **Request outcomes ([reportReachable] / [reportUnreachable]).** A query
///    that *succeeds* proves the device is online — nothing is more
///    authoritative, and it costs no extra network traffic. This also
///    self-corrects a false "offline" (e.g. a probe anchor blocked in some
///    region while the app's own API is perfectly reachable). A query that
///    *fails with a network error* does **not** flip us offline directly —
///    one failure could be a single dead endpoint — it only requests a
///    confirmation probe.
/// 2. **OS path-change hints.** [NativeConnectivityChannel.onNetworkChangeHint]
///    fires the instant an interface changes; the observer responds by
///    re-checking, so detection is immediate rather than waiting for a poll.
/// 3. **Active probe ([NativeConnectivityChannel.isConnected]).** A short TCP
///    connect (default port 443; target configurable via [probeTargets]) used
///    to confirm/deny connectivity when there is no recent request outcome to
///    judge by.
///
/// This ordering matters because in this package a confirmed `offline→online`
/// transition triggers a refetch across *every* registered controller — so
/// "online" must be trustworthy (a real success or a confirmed probe), and a
/// lone failure must never be able to storm the app offline-then-online.
///
/// Concurrent checks are ordered by a monotonic sequence so an out-of-order
/// probe completion can never overwrite a newer result (including a request
/// outcome that arrived while a probe was in flight).
class NetworkConnectivityObserver {
  static NetworkConnectivityObserver? _instance;

  /// When `true`, [initialize] is a no-op and [isOnline] always returns `true`.
  /// Set this in test setUp to prevent real platform channel calls.
  static bool testMode = false;

  /// Hosts the active probe attempts to reach. Defaults to Cloudflare's
  /// anycast anchors on port 443. Override via
  /// [QueryDefaults.connectivityProbeTargets] — ideally with your own backend.
  static List<ProbeTarget> probeTargets = const [
    ProbeTarget('1.1.1.1'),
    ProbeTarget('1.0.0.1'),
  ];

  Timer? _pollTimer;
  Timer? _hintDebounce;
  StreamSubscription<dynamic>? _hintSubscription;

  /// Monotonic counter used to discard the results of superseded checks.
  int _checkSeq = 0;

  /// When a request last proved the device reachable — lets the backstop poll
  /// skip probing while real traffic is already confirming connectivity.
  DateTime? _lastReachableAt;

  bool _isOnline = true;
  bool _isInitialized = false;

  StreamController<bool>? _broadcastController;
  int _activeListenerCount = 0;

  StreamController<bool> get _controller {
    if (_broadcastController == null || _broadcastController!.isClosed) {
      _broadcastController = StreamController<bool>.broadcast(
        onListen: () => _activeListenerCount++,
        onCancel: () => _activeListenerCount--,
      );
    }
    return _broadcastController!;
  }

  int get listenerCount => _activeListenerCount;

  /// Backstop interval on which the active probe is re-run when there is no
  /// recent request outcome. Only a safety net — instant detection comes from
  /// request outcomes and OS hints. Kept modest to conserve battery.
  ///
  /// Mutable (rather than `const`) so tests can shorten it.
  static Duration pollInterval = const Duration(seconds: 15);

  /// How long to coalesce a burst of OS change hints / failure reports before
  /// probing. Short enough to still feel instant.
  ///
  /// Mutable (rather than `const`) so tests can shorten it.
  static Duration hintDebounce = const Duration(milliseconds: 250);

  NetworkConnectivityObserver._();

  /// Returns the shared singleton instance.
  static NetworkConnectivityObserver get instance {
    return _instance ??= NetworkConnectivityObserver._();
  }

  /// Whether the device currently has internet connectivity.
  ///
  /// Defaults to `true` before [initialize] is called to prevent queries
  /// from starting in a paused state on a connected device.
  bool get isOnline => _isOnline;

  /// Whether the observer has been initialized and is actively listening.
  bool get isInitialized => _isInitialized;

  /// A stream of connectivity status changes.
  Stream<bool> get onStatusChange => _controller.stream;

  /// Start observing connectivity changes.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Gracefully handles missing platform bindings (e.g. in test environments
  /// without `TestWidgetsFlutterBinding.ensureInitialized()`).
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // In test mode, skip real platform channel calls entirely.
    if (testMode) return;

    // Platform channels require ServicesBinding — bail early if unavailable.
    if (!_isBindingInitialized) return;

    try {
      _isOnline = await NativeConnectivityChannel.isConnected(
        targets: probeTargets,
      );
      QueryLogger.info(
        '[NetworkObserver] Initial status: ${_isOnline ? "online" : "offline"}',
      );
    } catch (_) {
      _isOnline = true;
    }

    // Instant, event-driven detection: re-probe the moment the OS reports a
    // network path change. The hint is only a trigger — a probe or request
    // outcome remains the source of truth.
    try {
      _hintSubscription = NativeConnectivityChannel.onNetworkChangeHint.listen(
        (_) => _scheduleRecheck(),
        onError: (_) {
          // Event channel unavailable — polling backstop still covers us.
        },
      );
    } catch (_) {
      // Event channel not wired on this platform — rely on polling.
    }

    // Backstop: probe on a fixed cadence, but only when no recent request has
    // already proven reachability.
    _pollTimer = Timer.periodic(pollInterval, (_) {
      final last = _lastReachableAt;
      if (last != null && DateTime.now().difference(last) < pollInterval) {
        return; // real traffic is already confirming we're online
      }
      _recheck();
    });
  }

  // ─── Primary signal: request outcomes ──────────────────────────────

  /// Report that a real network request **succeeded**.
  ///
  /// This is the most authoritative "online" signal — the server was reached.
  /// Flips the status online immediately (superseding any in-flight probe) and,
  /// on an `offline→online` transition, drives the package's reconnect refetch.
  void reportReachable() {
    _lastReachableAt = DateTime.now();
    // A confirmed success wins over anything a slower probe might report:
    // bump the sequence to discard any probe already in flight, and cancel a
    // pending (debounced) confirmation probe that hasn't started yet — both
    // would otherwise apply a now-stale "offline" after this.
    _checkSeq++;
    _hintDebounce?.cancel();
    _hintDebounce = null;
    _applyStatus(true);
  }

  /// Report that a request **failed with a network-type error**.
  ///
  /// Deliberately does *not* set the status offline on its own — a single
  /// failure could be one dead endpoint. It only schedules a confirmation
  /// probe; the status flips offline only if that probe (or the OS/backstop)
  /// agrees.
  void reportUnreachable() {
    _scheduleRecheck();
  }

  // ─── Recheck / probe ───────────────────────────────────────────────

  /// Coalesce a burst of OS hints / failure reports into a single probe.
  void _scheduleRecheck() {
    _hintDebounce?.cancel();
    _hintDebounce = Timer(hintDebounce, _recheck);
  }

  /// Run a fresh active probe and apply the result if it hasn't been
  /// superseded by a newer check (probe or request outcome).
  Future<void> _recheck() async {
    final seq = ++_checkSeq;
    bool isConnected;
    try {
      isConnected = await NativeConnectivityChannel.isConnected(
        targets: probeTargets,
      );
    } catch (_) {
      // Transient channel error — keep the last known value.
      return;
    }

    if (seq != _checkSeq) return; // a newer check superseded this probe
    if (isConnected) _lastReachableAt = DateTime.now();
    _applyStatus(isConnected);
  }

  /// Set the status and emit only on a genuine change.
  void _applyStatus(bool online) {
    final wasOnline = _isOnline;
    _isOnline = online;
    if (wasOnline != online) {
      QueryLogger.info(
        '[NetworkObserver] Status changed: ${online ? "online" : "offline"}',
      );
      _controller.add(online);
    }
  }

  /// Whether the Flutter services binding has been initialized.
  static bool get _isBindingInitialized {
    try {
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clean up resources. After disposal, the singleton is reset and
  /// [initialize] must be called again on a new instance.
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _hintDebounce?.cancel();
    _hintDebounce = null;
    _hintSubscription?.cancel();
    _hintSubscription = null;
    _broadcastController?.close();
    _activeListenerCount = 0;
    _isInitialized = false;
    _lastReachableAt = null;
    _instance = null;
  }
}
