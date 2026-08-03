import 'package:flutter/services.dart';

import 'probe_target.dart';

/// Thin wrapper around the platform channels backed by this package's native
/// Android and iOS implementations.
///
/// Two channels are exposed:
///
/// - [isConnected] — a one-shot **active reachability probe**. Native code
///   first checks the OS route (Android `activeNetwork`, iOS
///   `NWPathMonitor`); if a route exists it opens a short-lived TCP connection
///   to one of the given [ProbeTarget]s (default `443`, which is far more
///   universally reachable than DNS port `53`) with a short timeout. This is
///   what distinguishes "connected to Wi-Fi/emulator but no real internet"
///   from genuinely online.
///
/// - [onNetworkChangeHint] — a lightweight event stream that fires whenever
///   the OS network path changes. The payload is deliberately **not** treated
///   as authoritative state: each hint tells the observer to re-check
///   reachability, so a fresh probe (or a real request outcome) is always the
///   source of truth. A stale/spurious hint can only trigger a re-check, never
///   set a wrong value.
class NativeConnectivityChannel {
  NativeConnectivityChannel._();

  static const MethodChannel _methodChannel = MethodChannel(
    'flutter_query_client/connectivity',
  );

  static const EventChannel _eventChannel = EventChannel(
    'flutter_query_client/connectivity/events',
  );

  /// A fresh, one-shot active reachability probe of the current connectivity.
  ///
  /// [targets] overrides the hosts the native side attempts to connect to;
  /// when omitted or empty, the native default anchors (on port 443) are used.
  static Future<bool> isConnected({List<ProbeTarget>? targets}) async {
    final Map<String, dynamic>? args =
        (targets == null || targets.isEmpty)
            ? null
            : {'targets': targets.map((t) => t.toMap()).toList()};
    final result = await _methodChannel.invokeMethod<bool>('isConnected', args);
    return result ?? true;
  }

  /// A stream of "the OS network path changed" hints.
  ///
  /// The emitted values carry no meaning — consumers should re-check
  /// reachability on each event rather than trusting the payload.
  static Stream<dynamic> get onNetworkChangeHint =>
      _eventChannel.receiveBroadcastStream();
}
