import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/refetch_on_mount.dart';
import 'package:flutter_query_client/src/enums/refetch_on_reconnect.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:logging/logging.dart';

/// Signature for error transformation callbacks.
///
/// Receives any error (either [QueryException] from the package or a
/// user-closure error) and returns the transformed error to store in state.
typedef ErrorTransformer = Object Function(Object error);

/// Global default configuration for all queries and mutations.
///
/// Pass this to [QueryClientProvider] via the `defaults` parameter.
/// Controller-level overrides always take precedence.
/// A `null` field means "use the controller's hardcoded default."
class QueryDefaults {
  final Duration? staleTime;
  final Duration? gcTime;
  final RefetchOnMount? refetchOnMount;
  final int? retryCount;
  final Duration? retryDelay;
  final Duration? refetchInterval;
  final ErrorTransformer? transformError;
  final NetworkMode? networkMode;
  final RefetchOnReconnect? refetchOnReconnect;

  /// Custom endpoints for internet reachability checks.
  ///
  /// By default, `internet_connection_checker_plus` checks Cloudflare,
  /// Google CDN, icanhazip, and Apple captive portal endpoints.
  /// Override this for corporate/private networks where public endpoints
  /// may be unreachable (e.g. behind a proxy or firewall).
  final List<InternetCheckOption>? connectivityEndpoints;

  /// Whether to enable internal logging for flutter_query.
  ///
  /// When `true`, lifecycle events (fetch start/success/error, cache hit,
  /// network changes) are logged via the `logging` package.
  final bool enableLogging;

  /// Minimum log level when logging is enabled. Defaults to [Level.ALL].
  final Level? logLevel;

  /// Custom log handler. If not provided, logs are printed to console.
  final void Function(LogRecord record)? onLog;

  const QueryDefaults({
    this.staleTime,
    this.gcTime,
    this.refetchOnMount,
    this.retryCount,
    this.retryDelay,
    this.refetchInterval,
    this.transformError,
    this.networkMode,
    this.refetchOnReconnect,
    this.connectivityEndpoints,
    this.enableLogging = false,
    this.logLevel,
    this.onLog,
  });
}
