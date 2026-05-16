import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../utils/query_logger.dart';

/// Observes network connectivity using `internet_connection_checker_plus`
/// for true L7 internet verification (HTTP HEAD requests to reliable endpoints),
/// with `connectivity_plus` wired as a trigger stream for faster detection.
///
/// Key design principles:
/// - **True internet verification**: Unlike `connectivity_plus` alone (which only
///   detects L2/L3 interface status), this observer verifies actual internet
///   reachability via HTTP HEAD requests to multiple endpoints.
/// - **Single instance**: Resources are created once and kept alive for the
///   lifetime of the observer. They are never recreated.
/// - **Debounced events**: Rapid connectivity changes (common during app
///   background/foreground transitions) are debounced with a 500ms window
///   to prevent unnecessary refetch storms.
/// - **Lazy initialization**: Call [initialize] to start listening. Before
///   initialization, [isOnline] defaults to `true` to avoid false pauses.
class NetworkConnectivityObserver {
  static NetworkConnectivityObserver? _instance;

  /// When `true`, [initialize] is a no-op and [isOnline] always returns `true`.
  /// Set this in test setUp to prevent real HTTP calls.
  static bool testMode = false;

  InternetConnection? _internetConnection;
  StreamSubscription<InternetStatus>? _subscription;
  Timer? _debounceTimer;

  bool _isOnline = true;
  bool _isInitialized = false;

  final _controller = StreamController<bool>.broadcast();

  /// Debounce duration for rapid connectivity events.
  static const _debounceDuration = Duration(milliseconds: 500);

  NetworkConnectivityObserver._();

  /// Returns the shared singleton instance.
  ///
  /// The observer is NOT automatically initialized. Call [initialize] to
  /// start listening for connectivity changes.
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

  /// A debounced stream of connectivity status changes.
  ///
  /// Emits `true` when the device comes online and `false` when it goes
  /// offline. Rapid-fire events are coalesced within a 500ms window.
  Stream<bool> get onStatusChange => _controller.stream;

  /// Start listening for connectivity changes.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Uses `connectivity_plus` as a trigger stream so that interface-level
  /// changes (WiFi on/off) immediately trigger an internet check, rather
  /// than waiting for the default 10s polling interval.
  ///
  /// [customEndpoints] allows overriding the default check endpoints used by
  /// `internet_connection_checker_plus`. Useful for corporate/private networks
  /// where public endpoints may be unreachable.
  ///
  /// Gracefully handles missing platform bindings (e.g. in test environments
  /// without `TestWidgetsFlutterBinding.ensureInitialized()`).
  Future<void> initialize({
    List<InternetCheckOption>? customEndpoints,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // In test mode, skip real network initialization entirely.
    if (testMode) return;

    // Platform channels require ServicesBinding — bail early if unavailable.
    if (!_isBindingInitialized) return;

    try {
      // Create connectivity_plus instance as a trigger stream for faster
      // detection. When the network interface changes, it immediately triggers
      // an actual internet check instead of waiting for the poll interval.
      final connectivity = Connectivity();
      final triggerStream = connectivity.onConnectivityChanged;

      _internetConnection = InternetConnection.createInstance(
        checkInterval: const Duration(seconds: 30),
        triggerStream: triggerStream,
        customCheckOptions: customEndpoints,
      );
    } catch (_) {
      QueryLogger.warning(
        '[NetworkObserver] Failed to create InternetConnection instance',
      );
      return;
    }

    try {
      _isOnline = await _internetConnection!.hasInternetAccess;
      QueryLogger.info(
        '[NetworkObserver] Initial status: ${_isOnline ? "online" : "offline"}',
      );
    } catch (_) {
      _isOnline = true;
    }

    try {
      _subscription =
          _internetConnection!.onStatusChange.listen(_onStatusEvent);
    } catch (_) {
      // Stream unavailable — observer reports based on initial check.
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

  void _onStatusEvent(InternetStatus status) {
    // Cancel any pending debounce to coalesce rapid events.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      final wasOnline = _isOnline;
      _isOnline = status == InternetStatus.connected;

      if (wasOnline != _isOnline) {
        QueryLogger.info(
          '[NetworkObserver] Status changed: ${_isOnline ? "online" : "offline"}',
        );
        _controller.add(_isOnline);
      }
    });
  }

  /// Clean up resources. After disposal, the singleton is reset and
  /// [initialize] must be called again on a new instance.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
    _isInitialized = false;
    _instance = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Previous implementation using connectivity_plus only (L2/L3 detection).
// Kept for reference — connectivity_plus has known inversion bugs where
// WiFi off reports "wifi" and WiFi on reports "none".
// ═══════════════════════════════════════════════════════════════════════════
//
// import 'dart:async';
//
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/services.dart';
//
// import '../utils/query_logger.dart';
//
// /// Observes network connectivity changes using `connectivity_plus`.
// ///
// /// Key design principles:
// /// - **Single instance**: One [Connectivity] object is created and kept alive
// ///   for the lifetime of the observer. It is never recreated.
// /// - **Debounced events**: Rapid connectivity changes (common during app
// ///   background/foreground transitions) are debounced with a 500ms window
// ///   to prevent unnecessary refetch storms.
// /// - **Lazy initialization**: Call [initialize] to start listening. Before
// ///   initialization, [isOnline] defaults to `true` to avoid false pauses.
// ///
// /// Note: `connectivity_plus` reports L2/L3 connectivity (WiFi/mobile
// /// association) but does NOT verify actual internet reachability. Captive
// /// portals, DNS failures, and ISP outages will still report as "connected."
// class NetworkConnectivityObserver {
//   static NetworkConnectivityObserver? _instance;
//
//   Connectivity? _connectivity;
//   StreamSubscription<List<ConnectivityResult>>? _subscription;
//   Timer? _debounceTimer;
//
//   bool _isOnline = true;
//   bool _isInitialized = false;
//
//   final _controller = StreamController<bool>.broadcast();
//
//   /// Debounce duration for rapid connectivity events.
//   static const _debounceDuration = Duration(milliseconds: 500);
//
//   NetworkConnectivityObserver._();
//
//   /// Returns the shared singleton instance.
//   ///
//   /// The observer is NOT automatically initialized. Call [initialize] to
//   /// start listening for connectivity changes.
//   static NetworkConnectivityObserver get instance {
//     return _instance ??= NetworkConnectivityObserver._();
//   }
//
//   /// Whether the device currently has network connectivity.
//   ///
//   /// Defaults to `true` before [initialize] is called to prevent queries
//   /// from starting in a paused state on a connected device.
//   bool get isOnline => _isOnline;
//
//   /// Whether the observer has been initialized and is actively listening.
//   bool get isInitialized => _isInitialized;
//
//   /// A debounced stream of connectivity status changes.
//   ///
//   /// Emits `true` when the device comes online and `false` when it goes
//   /// offline. Rapid-fire events are coalesced within a 500ms window.
//   Stream<bool> get onStatusChange => _controller.stream;
//
//   /// Start listening for connectivity changes.
//   ///
//   /// Safe to call multiple times — subsequent calls are no-ops.
//   /// Performs an initial connectivity check and then listens for changes.
//   /// Gracefully handles missing platform bindings (e.g. in test environments
//   /// without `TestWidgetsFlutterBinding.ensureInitialized()`).
//   Future<void> initialize() async {
//     if (_isInitialized) return;
//     _isInitialized = true;
//
//     // Platform channels require ServicesBinding — bail early if unavailable.
//     if (!_isBindingInitialized) return;
//
//     try {
//       _connectivity = Connectivity();
//     } catch (_) {
//       return;
//     }
//
//     try {
//       final result = await _connectivity!.checkConnectivity();
//       _isOnline = _hasConnectivity(result);
//     } catch (_) {
//       _isOnline = true;
//     }
//
//     try {
//       _subscription = _connectivity!.onConnectivityChanged.listen(_onEvent);
//     } catch (_) {
//       // Platform channel not available — observer reports based on initial check.
//     }
//   }
//
//   /// Whether the Flutter services binding has been initialized.
//   static bool get _isBindingInitialized {
//     try {
//       ServicesBinding.instance;
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   void _onEvent(List<ConnectivityResult> results) {
//     // Cancel any pending debounce to coalesce rapid events.
//     _debounceTimer?.cancel();
//     _debounceTimer = Timer(_debounceDuration, () {
//       final wasOnline = _isOnline;
//       _isOnline = _hasConnectivity(results);
//
//       if (wasOnline != _isOnline) {
//         QueryLogger.info(
//           '[NetworkObserver] Status changed: ${_isOnline ? "online" : "offline"} (raw: $results)',
//         );
//         _controller.add(_isOnline);
//       }
//     });
//   }
//
//   /// Returns `true` if at least one result indicates connectivity
//   /// (anything other than [ConnectivityResult.none]).
//   static bool _hasConnectivity(List<ConnectivityResult> results) {
//     if (results.isEmpty) return false;
//     return results.any((r) => r != ConnectivityResult.none);
//   }
//
//   /// Clean up resources. After disposal, the singleton is reset and
//   /// [initialize] must be called again on a new instance.
//   void dispose() {
//     _debounceTimer?.cancel();
//     _debounceTimer = null;
//     _subscription?.cancel();
//     _subscription = null;
//     _controller.close();
//     _isInitialized = false;
//     _instance = null;
//   }
// }
