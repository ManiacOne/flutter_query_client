import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/client/query_client.dart';
import 'package:flutter_query_client/src/enums/cache_change_reason.dart';
import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/refetch_on_app_focus.dart';
import 'package:flutter_query_client/src/enums/refetch_on_mount.dart';
import 'package:flutter_query_client/src/helpers.dart';
import 'package:flutter_query_client/src/models/cached_query_data.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/query_state.dart';
import 'package:flutter_query_client/src/utils/refetch_interval_handle.dart';

/// Observes **many params of one query key at once** — the analogue of
/// TanStack Query's `useQueries`.
///
/// A single controller instance drives per-param loading for a dynamic set of
/// params: its state is a `Map<P, QueryState<T>>`, one entry per param, each
/// with its own `status`/`fetchStatus`/`data`. No per-param instance juggling.
///
/// Fetches run through the client's record-owned engine, so requests for the
/// same key coalesce (dedup) and status is shared across every observer.
///
/// ```dart
/// class ProductsByIds extends QueriesController<Product, int> {
///   ProductsByIds() : super('product');
///   @override
///   Future<Product> queryFn(int id) => productService.getProductById(id);
/// }
///
/// final c = ProductsByIds()..setParams([1, 2, 3]);
/// c.stateFor(2).isLoading; // per-param loading, one instance
/// ```
abstract class QueriesController<T, P> extends Cubit<Map<P, QueryState<T>>> {
  QueriesController(this.cacheKey, {ErrorTransformer? transformError})
      : _transformError = transformError,
        super(const {}) {
    client.ensureLifecycleInitialized();
    client.registerLifecycleCallbacks(
      onResume: _onAppResume,
      onPause: _onAppPause,
    );
    _startInterval();
  }

  final String cacheKey;
  final QueryClient client = QueryClient.instance;
  final ErrorTransformer? _transformError;

  final List<P> _params = [];

  final RefetchIntervalHandle _refetchHandle = RefetchIntervalHandle();
  late final void Function() _onAppResume = _handleAppResume;
  late final void Function() _onAppPause = _handleAppPause;

  /// One stable callback per observed param key, so the controller knows which
  /// param changed (e.g. to refetch just that one on invalidation).
  final Map<String?, void Function(CacheChangeReason)> _callbacks = {};

  void _onParamChange(P p, CacheChangeReason reason) {
    if (isClosed) return;
    // Active-observer behaviour: an invalidated param refetches (TanStack
    // parity). cleared/evicted/updated/statusChanged just re-read state.
    if (reason == CacheChangeReason.invalidated) {
      _fetch(p, force: true);
    }
    _recompute();
  }

  // ─── Subclass contract ───────────────────────────────────────────

  /// Fetch a single param's data.
  Future<T> queryFn(P params);

  /// How long data is considered fresh. null = never stale automatically.
  Duration? get staleTime => null;

  /// Number of retry attempts on failure.
  int get retryCount => 3;

  /// Base delay between retries (exponential backoff).
  Duration get retryDelay => const Duration(seconds: 1);

  /// Network mode for these queries.
  NetworkMode get networkMode => NetworkMode.online;

  /// If set, every observed param is refetched on this interval (polling).
  Duration? get refetchInterval => null;

  /// Policy for [handleRemount] (refetch-on-visible) — refetch observed params
  /// when the screen becomes visible again. Defaults to [RefetchOnMount.always].
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;

  /// Refetch stale params when the app returns to the foreground.
  RefetchOnAppFocus get refetchOnAppFocus => RefetchOnAppFocus.ifStale;

  /// Whether [refetchInterval] keeps polling while the app is backgrounded.
  bool get refetchIntervalInBackground => false;

  // ─── Resolved defaults (controller override → global → hardcoded) ─

  Duration? get _resolvedStaleTime => staleTime ?? client.defaults.staleTime;
  Duration? get _resolvedGcTime => client.defaults.gcTime;
  int get _resolvedRetryCount => client.defaults.retryCount ?? retryCount;
  Duration get _resolvedRetryDelay => client.defaults.retryDelay ?? retryDelay;
  NetworkMode get _resolvedNetworkMode =>
      client.defaults.networkMode ?? networkMode;
  RefetchOnMount get _resolvedRefetchOnMount =>
      client.defaults.refetchOnMount ?? refetchOnMount;
  Duration? get _resolvedRefetchInterval =>
      refetchInterval ?? client.defaults.refetchInterval;
  RefetchOnAppFocus get _resolvedRefetchOnAppFocus =>
      client.defaults.refetchOnAppFocus ?? refetchOnAppFocus;
  bool get _resolvedRefetchIntervalInBackground =>
      client.defaults.refetchIntervalInBackground ?? refetchIntervalInBackground;
  Object Function(Object)? get _resolvedTransform =>
      _transformError ?? client.defaults.transformError;

  // ─── Interval polling + app lifecycle ────────────────────────────

  void _startInterval() {
    final interval = _resolvedRefetchInterval;
    if (interval == null || isClosed) return;
    _refetchHandle.start(interval, () {
      if (isClosed) return;
      for (final p in _params) {
        _fetch(p, force: true);
      }
    });
  }

  void _handleAppPause() {
    if (isClosed) return;
    if (!_resolvedRefetchIntervalInBackground) _refetchHandle.pause();
  }

  void _handleAppResume() {
    if (isClosed) return;
    final intervalPastDue = _refetchHandle.isPastDue;
    if (_refetchHandle.isPaused) _refetchHandle.resume();
    final rof = _resolvedRefetchOnAppFocus;
    for (final p in _params) {
      final s = client.stateFor<T>(cacheKey, p);
      final wantFocus = rof == RefetchOnAppFocus.always || s.isStale;
      if (intervalPastDue || wantFocus || !s.hasData) {
        _fetch(p, force: true);
      }
    }
  }

  // ─── Params ──────────────────────────────────────────────────────

  List<P> get params => List.unmodifiable(_params);

  /// Observe exactly [next] params — registers newly-added params (kicking off
  /// their fetches), unregisters removed ones, and re-emits the state map.
  void setParams(List<P> next) {
    final nextByKey = <String?, P>{
      for (final p in next) serializeParams(p): p,
    };

    for (final key in _callbacks.keys.toList()) {
      if (!nextByKey.containsKey(key)) {
        client.unregisterActiveQuery(cacheKey, key,
            onCacheChange: _callbacks.remove(key));
      }
    }

    nextByKey.forEach((key, p) {
      if (!_callbacks.containsKey(key)) {
        _callbacks[key] = (reason) => _onParamChange(p, reason);
        client.registerActiveQuery(cacheKey, key,
            onCacheChange: _callbacks[key]);
        _fetch(p);
      }
    });

    _params
      ..clear()
      ..addAll(next);
    _recompute();
  }

  /// Start observing one more [params] (no-op if already observed) — kicks off
  /// its fetch. Convenience over [setParams] for adding params incrementally.
  void addParam(P params) {
    if (_params.contains(params)) return;
    setParams([..._params, params]);
  }

  /// Stop observing [params].
  void removeParam(P params) {
    setParams(_params.where((p) => p != params).toList());
  }

  // ─── State ───────────────────────────────────────────────────────

  /// The current [QueryState] for a single [params] — reads the shared engine.
  QueryState<T> stateFor(P params) => client.stateFor<T>(cacheKey, params);

  /// Optimistically write [data] for [params] into the cache (typed — no manual
  /// serialization). Every observer updates instantly, no network.
  void setData(P params, T data) {
    client.set<T>(
      cacheKey,
      serializeParams(params),
      CachedQueryData<T>(
        data: data,
        fetchTime: DateTime.now(),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
      ),
    );
  }

  void _recompute() {
    if (isClosed) return;
    emit({for (final p in _params) p: client.stateFor<T>(cacheKey, p)});
  }

  Future<void> _fetch(P p, {bool force = false}) async {
    try {
      await client.fetchQuery<T>(
        cacheKey,
        p,
        queryFn: () => queryFn(p),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
        retryCount: _resolvedRetryCount,
        retryDelay: _resolvedRetryDelay,
        networkMode: _resolvedNetworkMode,
        transformError: _resolvedTransform,
        force: force,
      );
    } catch (_) {
      // Errors are recorded in the engine runtime and surfaced via stateFor.
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────

  /// Refetch-on-visible: called automatically by the `Query*` builder widgets
  /// when the screen becomes visible again (a tab flip or a `Navigator`
  /// pop-back). Refetches observed params per [refetchOnMount] — `always`
  /// refetches all, `stale` only the stale ones, `never` does nothing.
  void handleRemount() {
    if (isClosed) return;
    final rom = _resolvedRefetchOnMount;
    if (rom == RefetchOnMount.never) return;
    for (final p in _params) {
      if (rom == RefetchOnMount.always ||
          client.stateFor<T>(cacheKey, p).isStale) {
        _fetch(p, force: true);
      }
    }
  }

  /// Refetch a single [params], or all observed params when omitted.
  Future<void> refetch([P? params]) async {
    if (params != null) {
      await _fetch(params, force: true);
      return;
    }
    await Future.wait(_params.map((p) => _fetch(p, force: true)));
  }

  /// Invalidate + refetch a single [params], or all observed params when
  /// omitted.
  Future<void> invalidate([P? params]) async {
    final targets = params != null ? [params] : List<P>.from(_params);
    for (final p in targets) {
      client.invalidate(cacheKey, serializeParams(p));
    }
    await Future.wait(targets.map((p) => _fetch(p, force: true)));
  }

  @override
  Future<void> close() {
    _refetchHandle.stop();
    client.unregisterLifecycleCallbacks(
      onResume: _onAppResume,
      onPause: _onAppPause,
    );
    for (final entry in _callbacks.entries) {
      client.unregisterActiveQuery(cacheKey, entry.key,
          onCacheChange: entry.value);
    }
    _callbacks.clear();
    return super.close();
  }
}
