import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/refetch_on_app_focus.dart';
import 'package:flutter_query_client/src/enums/refetch_on_mount.dart';
import 'package:flutter_query_client/src/enums/refetch_on_reconnect.dart';
import 'package:flutter_query_client/src/network/probe_target.dart';
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

  /// Global default for refetching when the app returns to the foreground
  /// (mobile analogue of `refetchOnWindowFocus`). `null` defers to each
  /// controller's `refetchOnAppFocus` (which defaults to `ifStale`).
  final RefetchOnAppFocus? refetchOnAppFocus;

  /// Global default for whether the `refetchInterval` timer keeps polling while
  /// the app is backgrounded. `null`/`false` pauses polling in the background
  /// and resumes (refetching per `refetchOnAppFocus`) on resume.
  final bool? refetchIntervalInBackground;

  /// Global default for keeping the previous params' data visible (flagged
  /// [QueryState.isPlaceholderData]) while a new params fetch is in flight,
  /// instead of flashing a loading state. `null` defers to each controller's
  /// `keepPreviousData` getter (which defaults to `false`).
  final bool? keepPreviousData;

  /// Hosts the native connectivity probe attempts to reach when confirming
  /// reachability (used only as a tiebreaker — the app's own request outcomes
  /// are the primary online/offline signal).
  ///
  /// Defaults to Cloudflare's anycast anchors on port 443. **For the most
  /// accurate result across all regions, set this to your own backend host**
  /// (e.g. `[ProbeTarget('api.myapp.com')]`) — a reachable backend means
  /// "online" for your app, and avoids region-specific blocking of public
  /// anchors. When `null`, the built-in defaults are used.
  final List<ProbeTarget>? connectivityProbeTargets;

  /// The default first-page parameter for every [InfiniteQueryController]
  /// that does not override [InfiniteQueryController.initialPageParam].
  ///
  /// Defaults to `0` (zero-indexed integer pages). Set to `1` for
  /// one-indexed APIs, or to a [String] / custom type for cursor-based
  /// APIs — then also override [initialPageParam] in each controller whose
  /// [PageParam] type differs from the global default.
  final dynamic initialPageParam;

  /// The default page size for every [InfiniteQueryController] that does
  /// not override [InfiniteQueryController.limit].
  ///
  /// Defaults to `20`. Set this once here instead of repeating it in every
  /// controller subclass.
  final int limit;

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
    this.refetchOnAppFocus,
    this.refetchIntervalInBackground,
    this.keepPreviousData,
    this.connectivityProbeTargets,
    this.initialPageParam = 0,
    this.limit = 20,
    this.enableLogging = false,
    this.logLevel,
    this.onLog,
  });
}
