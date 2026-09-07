import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/client/query_client.dart';
import 'package:flutter_query_client/src/enums/cache_change_reason.dart';
import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/query_status.dart';
import 'package:flutter_query_client/src/enums/refetch_on_app_focus.dart';
import 'package:flutter_query_client/src/enums/refetch_on_mount.dart';
import 'package:flutter_query_client/src/enums/refetch_on_reconnect.dart';
import 'package:flutter_query_client/src/helpers.dart';
import 'package:flutter_query_client/src/models/cached_query_data.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/query_state.dart';
import 'package:flutter_query_client/src/utils/error_transform_utils.dart';
import 'package:flutter_query_client/src/utils/network_error.dart';
import 'package:flutter_query_client/src/utils/query_logger.dart';
import 'package:flutter_query_client/src/utils/refetch_interval_handle.dart';
import 'package:flutter_query_client/src/utils/retry_utils.dart';
import 'package:flutter_query_client/src/utils/stale_listener_handle.dart';

/// Controller for cursor-based infinite pagination queries.
///
/// [T] is the item type (e.g. Product).
/// [PageParam] is the page parameter type (e.g. `int` for page numbers,
/// `String` for cursors).
/// [P] is the filters type (`void` for no-filter queries).
///
/// Subclasses must implement [queryFn] and [getNextPageParam].
///
/// The loaded pages are stored in the [QueryClient] cache (as `List<List<T>>`)
/// which is the single source of truth for data — the controller derives its
/// flattened `state.data` from the cache and owns only the fetch lifecycle
/// (`fetchStatus`, `isLoadingMore`, `error`). Like [QueryController], `enabled`
/// is derived from [P]: always `true` for `void` filters, otherwise `true` only
/// when filters are non-null.
///
/// [initialPageParam] and [limit] are optional — they fall back to
/// [QueryDefaults.initialPageParam] (default `0`) and
/// [QueryDefaults.limit] (default `20`) respectively.
abstract class InfiniteQueryController<T, PageParam, P>
    extends Cubit<QueryState<List<T>>> {
  final String cacheKey;
  final QueryClient client = QueryClient.instance;
  final ErrorTransformer? _transformError;

  P? _filters;
  final bool _isVoidParams;
  bool _isInitialized = false;
  int _filterVersion = 0;

  /// Whether initial execution has been done for [NetworkMode.offlineFirst].
  bool _offlineFirstExecuted = false;

  /// Placeholder data carried across a [setParams] transition when
  /// [keepPreviousData] is set — the previous filters' flattened data.
  List<T>? _placeholderData;

  /// Re-entrancy guard: true while this controller writes to the cache itself,
  /// so its own cache-change callback is a no-op (it emits explicitly).
  bool _isSelfMutating = false;

  /// Memoized flattened view of the current cache pages, keyed by the pages
  /// list identity (the cache replaces the whole entry on every mutation).
  List<List<T>>? _flatMemoSource;
  List<T>? _flatMemo;

  /// Stale-listener handle.
  late final StaleListenerHandle _staleHandle = StaleListenerHandle(
    client: client,
    cacheKey: cacheKey,
  );

  /// Periodic refetch handle.
  final RefetchIntervalHandle _refetchHandle = RefetchIntervalHandle();

  /// Stable cache-change callback reference.
  late final void Function(CacheChangeReason) _onCacheChange =
      _handleCacheChange;

  /// Stable reconnect callback reference.
  late final ReconnectCallback _onReconnect = _handleReconnect;

  /// Stable app-lifecycle callbacks.
  late final void Function() _onAppResume = _handleAppResume;
  late final void Function() _onAppPause = _handleAppPause;

  InfiniteQueryController(this.cacheKey, {ErrorTransformer? transformError})
    : _transformError = transformError,
      _isVoidParams = _checkVoid<P>(),
      super(const QueryState()) {
    client.registerActiveQuery(
      cacheKey,
      _serializeFilters(_filters),
      onCacheChange: _onCacheChange,
    );
    _registerConnectivity();
    _registerLifecycle();
    _executeFirstPage();
  }

  /// Registers app foreground/background handling (once, in the constructor).
  void _registerLifecycle() {
    client.ensureLifecycleInitialized();
    client.registerLifecycleCallbacks(
      onResume: _onAppResume,
      onPause: _onAppPause,
    );
  }

  void _unregisterLifecycle() {
    client.unregisterLifecycleCallbacks(
      onResume: _onAppResume,
      onPause: _onAppPause,
    );
  }

  void _handleAppPause() {
    if (isClosed) return;
    if (!_resolvedRefetchIntervalInBackground) _refetchHandle.pause();
  }

  void _handleAppResume() {
    if (isClosed || !enabled) return;
    final intervalPastDue = _refetchHandle.isPastDue;
    if (_refetchHandle.isPaused) _refetchHandle.resume();

    if (state.isError) {
      _executeFirstPage();
      return;
    }
    final rof = _resolvedRefetchOnAppFocus;
    final wantFocusRefetch = rof == RefetchOnAppFocus.always ||
        (rof == RefetchOnAppFocus.ifStale && state.isStale);
    if (intervalPastDue || wantFocusRefetch || !state.hasData) {
      if (state.hasData) {
        _refetchInternal();
      } else {
        _executeFirstPage();
      }
    }
  }

  static bool _checkVoid<X>() => null is X;

  // ─── Cache-derived state ─────────────────────────────────────────

  CachedQueryData<List<List<T>>>? get _cachedEntry =>
      client.get<List<List<T>>>(cacheKey, _serializeFilters(_filters));

  List<List<T>>? get _cachedPages => _cachedEntry?.data;

  List<T> _flatten(List<List<T>> pages) {
    if (identical(pages, _flatMemoSource) && _flatMemo != null) {
      return _flatMemo!;
    }
    final flat = pages.expand((p) => p).toList();
    _flatMemoSource = pages;
    _flatMemo = flat;
    return flat;
  }

  void _resetFlatMemo() {
    _flatMemoSource = null;
    _flatMemo = null;
  }

  /// Flattened items across all loaded pages (from the cache).
  List<T> get _flatData {
    final pages = _cachedPages;
    if (pages == null) return const [];
    return _flatten(pages);
  }

  /// `state` overlaid with the current cache data — synchronous reads always
  /// reflect the cache. Placeholder states are left as-is.
  @override
  QueryState<List<T>> get state {
    final base = super.state;
    if (base.isPlaceholderData) return base;
    final entry = _cachedEntry;
    // Build a fresh QueryState rather than base.copyWith — the initial
    // `const QueryState()` can be inferred as QueryState<Null>, whose copyWith
    // would fail to cast non-null data.
    return QueryState<List<T>>(
      data: entry == null ? null : _flatten(entry.data),
      error: base.error,
      status: base.status,
      fetchStatus: base.fetchStatus,
      isStale: entry?.isStale ?? base.isStale,
      isLoadingMore: base.isLoadingMore,
      isPlaceholderData: base.isPlaceholderData,
      params: _filters,
    );
  }

  /// Emit a lifecycle state with `data`/`isStale`/`params` sourced from the
  /// cache. Widget builders receive this emitted object, so data must be
  /// populated here (not only via the [state] getter).
  void _emitFromCache({
    required QueryStatus status,
    FetchStatus fetchStatus = FetchStatus.idle,
    Object? error,
  }) {
    final entry = _cachedEntry;
    _safeEmit(
      QueryState<List<T>>(
        status: status,
        data: entry == null ? null : _flatten(entry.data),
        isStale: entry?.isStale ?? false,
        fetchStatus: fetchStatus,
        error: error,
        params: _filters,
      ),
    );
  }

  /// Persist [pages] to the cache under the current filters, with the
  /// self-mutation guard raised so the resulting notification is suppressed.
  void _savePages(List<List<T>> pages) {
    _resetFlatMemo();
    _isSelfMutating = true;
    try {
      client.set<List<List<T>>>(
        cacheKey,
        _serializeFilters(_filters),
        CachedQueryData<List<List<T>>>(
          data: pages,
          fetchTime: DateTime.now(),
          staleTime: _resolvedStaleTime,
          gcTime: _resolvedGcTime,
        ),
      );
    } finally {
      _isSelfMutating = false;
    }
  }

  void _selfMutate(void Function() fn) {
    _isSelfMutating = true;
    try {
      fn();
    } finally {
      _isSelfMutating = false;
    }
  }

  // ─── Safe emit ──────────────────────────────────────────────────

  void _safeEmit(QueryState<List<T>> newState) {
    if (!isClosed) emit(newState);
  }

  // ─── Error transform ────────────────────────────────────────────

  /// Override to transform errors at the controller level.
  /// Falls back to the global transform in [QueryDefaults.transformError].
  ErrorTransformer? get transformError => _transformError;

  Object _applyTransformError(Object error) {
    if (isNetworkError(error)) client.reportUnreachable();
    return applyErrorTransform(
      error: error,
      controllerTransform: transformError,
      globalTransform: client.defaults.transformError,
    );
  }

  // ─── Subclass contract ───────────────────────────────────────────

  /// Fetch a single page of data for the given [pageParam].
  Future<List<T>> queryFn(PageParam pageParam, P? filters);

  /// The first page parameter passed to [queryFn] on the initial fetch.
  PageParam get initialPageParam =>
      client.defaults.initialPageParam as PageParam;

  /// Derive the next page parameter from the last fetched page and all pages.
  /// Return `null` to signal "no more pages."
  PageParam? getNextPageParam(List<T> lastPage, List<List<T>> allPages);

  /// Whether this query should execute. Derived from [P] like [QueryController]:
  /// always `true` for `void` filters, otherwise `true` when filters != null.
  bool get enabled => _isVoidParams || _filters != null;

  /// Whether to background-refetch when mounting with cached data.
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;

  /// Items per page — used as a convenience value in [queryFn] and
  /// [getNextPageParam].
  int get limit => client.defaults.limit;

  /// How long data is considered fresh.
  Duration? get staleTime => null;

  /// If set, the controller will automatically refetch at this interval.
  Duration? get refetchInterval => null;

  /// Number of retry attempts on failure.
  int get retryCount => 3;

  /// Base delay between retries. Uses exponential backoff.
  Duration get retryDelay => const Duration(seconds: 1);

  /// Controls whether this query requires network connectivity.
  NetworkMode get networkMode => NetworkMode.online;

  /// Controls whether this query refetches when network connectivity is restored.
  RefetchOnReconnect get refetchOnReconnect => RefetchOnReconnect.ifStale;

  /// Controls whether this query refetches when the app returns to the
  /// foreground. Defaults to [RefetchOnAppFocus.ifStale].
  RefetchOnAppFocus get refetchOnAppFocus => RefetchOnAppFocus.ifStale;

  /// Whether [refetchInterval] keeps polling while the app is backgrounded.
  bool get refetchIntervalInBackground => false;

  /// When true, keeps the previous filters' data visible (with
  /// [QueryState.isPlaceholderData] set) while fetching after a [setParams] call.
  bool get keepPreviousData => false;

  // ─── Lifecycle hooks (override to customize) ─────────────────────

  /// Called after a successful fetch, refetch, or loadMore.
  void onSuccess(List<T> data) {}

  /// Called after a failed fetch, refetch, or loadMore.
  void onQueryError(Object error) {}

  // ─── Resolved defaults (controller override → global → hardcoded) ─

  Duration? get _resolvedStaleTime => staleTime ?? client.defaults.staleTime;
  RefetchOnMount get _resolvedRefetchOnMount =>
      client.defaults.refetchOnMount ?? refetchOnMount;
  int get _resolvedRetryCount => client.defaults.retryCount ?? retryCount;
  Duration get _resolvedRetryDelay => client.defaults.retryDelay ?? retryDelay;
  Duration? get _resolvedRefetchInterval =>
      refetchInterval ?? client.defaults.refetchInterval;
  Duration? get _resolvedGcTime => client.defaults.gcTime;
  NetworkMode get _resolvedNetworkMode =>
      client.defaults.networkMode ?? networkMode;
  RefetchOnReconnect get _resolvedRefetchOnReconnect =>
      client.defaults.refetchOnReconnect ?? refetchOnReconnect;
  RefetchOnAppFocus get _resolvedRefetchOnAppFocus =>
      client.defaults.refetchOnAppFocus ?? refetchOnAppFocus;
  bool get _resolvedRefetchIntervalInBackground =>
      client.defaults.refetchIntervalInBackground ?? refetchIntervalInBackground;
  bool get _resolvedKeepPreviousData =>
      client.defaults.keepPreviousData ?? keepPreviousData;

  // ─── Network helpers ────────────────────────────────────────────

  bool get _shouldPause {
    final mode = _resolvedNetworkMode;
    if (mode == NetworkMode.always) return false;
    if (mode == NetworkMode.offlineFirst && !_offlineFirstExecuted) {
      return false;
    }
    return !client.isOnline;
  }

  void _registerConnectivity() {
    final mode = _resolvedNetworkMode;
    if (mode == NetworkMode.always) return;
    client.ensureConnectivityInitialized().ignore();
    client.registerReconnectCallback(
      cacheKey,
      _serializeFilters(_filters),
      _onReconnect,
    );
  }

  void _unregisterConnectivity() {
    client.unregisterReconnectCallback(
      cacheKey,
      _serializeFilters(_filters),
      _onReconnect,
    );
  }

  void _handleReconnect({required bool isStale}) {
    if (isClosed || !enabled) return;
    if (_resolvedNetworkMode == NetworkMode.always) return;

    QueryLogger.info('[$cacheKey] Network reconnected (infinite)');

    if (_refetchHandle.isPaused) _refetchHandle.resume();

    if (state.isError) {
      QueryLogger.info('[$cacheKey] Retrying after error (reconnect)');
      _executeFirstPage();
      return;
    }

    final ror = _resolvedRefetchOnReconnect;
    if (ror == RefetchOnReconnect.never) return;

    final dataIsStale = state.isStale;

    if (ror == RefetchOnReconnect.ifStale && !dataIsStale && state.hasData) {
      if (state.isPaused) {
        _safeEmit(state.copyWith(fetchStatus: FetchStatus.idle));
      }
      return;
    }

    QueryLogger.info(
      '[$cacheKey] Refetching on reconnect (refetchOnReconnect: ${ror.name})',
    );
    if (state.hasData) {
      _refetchInternal();
    } else {
      _executeFirstPage();
    }
  }

  // ─── Filters ─────────────────────────────────────────────────────

  P? get filters => _filters;

  /// Update filters, reset pagination, and re-fetch from the initial page.
  void setParams(P params) {
    final oldSerialized = _serializeFilters(_filters);
    final newSerialized = serializeParams(params);
    final bool filtersChanged =
        _isInitialized && oldSerialized != newSerialized;

    if (filtersChanged) {
      // Capture the previous filters' data for keepPreviousData.
      _placeholderData = (_resolvedKeepPreviousData && _flatData.isNotEmpty)
          ? List<T>.of(_flatData)
          : null;

      _unregisterConnectivity();
      client.unregisterActiveQuery(
        cacheKey,
        oldSerialized,
        onCacheChange: _onCacheChange,
      );

      _filterVersion++;
      _filters = params;
      _resetFlatMemo();

      client.registerActiveQuery(
        cacheKey,
        _serializeFilters(_filters),
        onCacheChange: _onCacheChange,
      );
      _registerConnectivity();

      if (_cachedPages != null) {
        _emitFromCache(status: QueryStatus.success);
        _registerStaleListener();
        _startRefetchInterval();
        return;
      }

      // Emit placeholder data or reset to idle so _executeFirstPage doesn't
      // short-circuit on a stale loading state from the previous filters.
      if (_placeholderData != null && _placeholderData!.isNotEmpty) {
        _safeEmit(
          QueryState<List<T>>(
            status: QueryStatus.success,
            data: _placeholderData,
            isPlaceholderData: true,
            params: _filters,
          ),
        );
      } else {
        _safeEmit(QueryState<List<T>>(params: _filters));
      }
    } else {
      _filters = params;
    }

    _executeFirstPage();
  }

  // ─── Cache-change callback ───────────────────────────────────────

  void _handleCacheChange(CacheChangeReason reason) {
    if (isClosed || _isSelfMutating) return;

    switch (reason) {
      case CacheChangeReason.updated:
      case CacheChangeReason.statusChanged:
        if (_cachedPages != null && !state.isLoading) {
          _emitFromCache(status: QueryStatus.success);
        }
      case CacheChangeReason.invalidated:
        if (enabled) {
          refetch();
        } else {
          _emitFromCache(status: QueryStatus.idle);
        }
      case CacheChangeReason.cleared:
      case CacheChangeReason.evicted:
        _placeholderData = null;
        _resetFlatMemo();
        _staleHandle.unregister();
        _safeEmit(QueryState<List<T>>(status: QueryStatus.idle, params: _filters));
    }
  }

  // ─── Cache helpers ───────────────────────────────────────────────

  String? _serializeFilters([P? filters]) => serializeParams(filters);

  // ─── First page execution ───────────────────────────────────────

  Future<void> _executeFirstPage() async {
    if (!enabled) return;

    _isInitialized = true;

    // Cache already holds pages for these filters — emit and maybe refetch.
    if (_cachedPages != null) {
      final capturedVersion = _filterVersion;
      await Future.delayed(Duration.zero);
      if (capturedVersion != _filterVersion) return;
      final entry = _cachedEntry;
      _emitFromCache(status: QueryStatus.success);
      _registerStaleListener();
      _startRefetchInterval();
      final rom = _resolvedRefetchOnMount;
      final isStale = entry?.isStale ?? false;
      if (rom == RefetchOnMount.always ||
          (rom == RefetchOnMount.stale && isStale)) {
        _refetchInternal();
      }
      return;
    }

    if (state.isLoading || state.isLoadingMore) return;

    if (_shouldPause) {
      final capturedVersionPause = _filterVersion;
      await Future.delayed(Duration.zero);
      if (capturedVersionPause != _filterVersion) return;
      _safeEmit(state.copyWith(fetchStatus: FetchStatus.paused));
      return;
    }

    final capturedVersion = _filterVersion;

    await Future.delayed(Duration.zero);
    if (capturedVersion != _filterVersion) return;

    // keepPreviousData: keep placeholder visible instead of a loading spinner.
    if (!state.isPlaceholderData) {
      _emitFromCache(status: QueryStatus.loading);
    }

    try {
      final pageData = await retryWithBackoff<List<T>>(
        fn: () => queryFn(initialPageParam, _filters),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );

      if (capturedVersion != _filterVersion) return;

      if (_resolvedNetworkMode == NetworkMode.offlineFirst) {
        _offlineFirstExecuted = true;
      }

      _placeholderData = null;
      _savePages(<List<T>>[pageData]);
      _registerStaleListener();
      _startRefetchInterval();

      client.reportReachable();
      _emitFromCache(status: QueryStatus.success);
      onSuccess(_flatData);
    } catch (e) {
      if (capturedVersion != _filterVersion) return;
      final transformed = _applyTransformError(e);
      _emitFromCache(status: QueryStatus.error, error: transformed);
      onQueryError(transformed);
    }
  }

  // ─── Remount (hidden → visible) ───────────────────────────────────

  /// Called by the provider when the widget transitions from hidden → visible.
  ///
  /// **Note:** Has no effect at the root level (the widget never unmounts).
  /// Use `updateItem`, `refetch`, or `invalidateAndRefresh` to push updates to
  /// a root-level controller from child screens.
  void handleRemount() {
    if (!enabled) return;
    if (state.isLoading || state.isRefetching || state.isLoadingMore) return;

    if (state.isError) {
      QueryLogger.info('[$cacheKey] Retrying after error (remount, infinite)');
      _executeFirstPage();
      return;
    }

    final entry = _cachedEntry;
    if (entry == null) return;

    // External writes while hidden already notified via the subscription; this
    // ensures a fresh frame on show.
    _emitFromCache(status: QueryStatus.success);

    _startRefetchInterval();

    final rom = _resolvedRefetchOnMount;
    if (rom == RefetchOnMount.always ||
        (rom == RefetchOnMount.stale && entry.isStale)) {
      _refetchInternal();
    }
  }

  // ─── Load more ───────────────────────────────────────────────────

  /// Fetch the next page of data.
  Future<void> loadMore() async {
    if (!enabled) return;
    final pages = _cachedPages;
    if (pages == null || pages.isEmpty) return;

    final nextParam = getNextPageParam(pages.last, pages);
    if (nextParam == null) return;
    if (state.isLoading || state.isLoadingMore) return;

    if (_shouldPause) return;

    final capturedVersion = _filterVersion;

    _safeEmit(state.copyWith(isLoadingMore: true));

    try {
      final pageData = await retryWithBackoff<List<T>>(
        fn: () => queryFn(nextParam, _filters),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );

      if (capturedVersion != _filterVersion) return;

      // Re-read in case the cache changed while awaiting.
      final basePages = _cachedPages ?? pages;
      _savePages(<List<T>>[...basePages, pageData]);
      _registerStaleListener();
      _startRefetchInterval();

      client.reportReachable();
      _emitFromCache(status: QueryStatus.success);
      onSuccess(_flatData);
    } catch (e) {
      if (capturedVersion != _filterVersion) return;
      final transformed = _applyTransformError(e);
      _safeEmit(state.copyWith(
        error: transformed,
        isLoadingMore: false,
        fetchStatus: FetchStatus.idle,
      ));
      onQueryError(transformed);
    }
  }

  // ─── Refetch ─────────────────────────────────────────────────────

  /// Refetch all currently-loaded pages (TanStack parity), preserving depth.
  Future<void> refetch() async {
    if (!enabled) return;
    await _refetchInternal();
  }

  Future<void> _refetchInternal() async {
    if (_shouldPause) {
      _safeEmit(state.copyWith(fetchStatus: FetchStatus.paused));
      _refetchHandle.pause();
      return;
    }

    final capturedVersion = _filterVersion;
    // Replay as many pages as were loaded (at least one).
    final targetPageCount = (_cachedPages?.length ?? 0).clamp(1, 1 << 30);

    _safeEmit(state.copyWith(fetchStatus: FetchStatus.refetching));

    try {
      final newPages = <List<T>>[];
      PageParam param = initialPageParam;
      for (var i = 0; i < targetPageCount; i++) {
        final page = await retryWithBackoff<List<T>>(
          fn: () => queryFn(param, _filters),
          maxAttempts: _resolvedRetryCount,
          baseDelay: _resolvedRetryDelay,
          shouldAbort: () => _shouldPause,
        );
        if (capturedVersion != _filterVersion) return;
        newPages.add(page);
        // Derive the next param from the freshly fetched page, like TanStack.
        final next = getNextPageParam(page, newPages);
        if (next == null) break; // no more pages available now
        param = next;
      }

      _savePages(newPages);
      _registerStaleListener();
      _startRefetchInterval();

      client.reportReachable();
      _emitFromCache(status: QueryStatus.success);
      onSuccess(_flatData);
    } catch (e) {
      if (capturedVersion != _filterVersion) return;
      final transformed = _applyTransformError(e);
      _emitFromCache(status: QueryStatus.error, error: transformed);
      onQueryError(transformed);
    }
  }

  // ─── Invalidate & refresh ────────────────────────────────────────

  Future<void> invalidateAndRefresh() async {
    // Guard so the resulting cache-change callback doesn't also refetch.
    _selfMutate(() => client.invalidate(cacheKey, _serializeFilters(_filters)));
    _resetFlatMemo();
    _safeEmit(QueryState<List<T>>(params: _filters));
    await _executeFirstPage();
  }

  /// Reset pagination state to initial (clears the cached pages).
  void reset() {
    _selfMutate(() => client.invalidate(cacheKey, _serializeFilters(_filters)));
    _resetFlatMemo();
    _safeEmit(QueryState<List<T>>(params: _filters));
  }

  // ─── Optimistic updates ──────────────────────────────────────────

  void updateItem(bool Function(T item) predicate, T updatedItem) {
    final pages = _cachedPages;
    if (pages == null) return;
    for (var i = 0; i < pages.length; i++) {
      final idx = pages[i].indexWhere(predicate);
      if (idx != -1) {
        final newPages = pages.map((p) => List<T>.of(p)).toList();
        newPages[i][idx] = updatedItem;
        _savePages(newPages);
        _emitFromCache(status: QueryStatus.success);
        return;
      }
    }
  }

  void removeItem(bool Function(T item) predicate) {
    final pages = _cachedPages;
    if (pages == null) return;
    final newPages =
        pages.map((p) => List<T>.of(p)..removeWhere(predicate)).toList();
    _savePages(newPages);
    _emitFromCache(status: QueryStatus.success);
  }

  void prependItem(T item) {
    final pages = _cachedPages;
    if (pages == null || pages.isEmpty) {
      _savePages(<List<T>>[<T>[item]]);
    } else {
      final newPages = pages.map((p) => List<T>.of(p)).toList();
      newPages.first.insert(0, item);
      _savePages(newPages);
    }
    _emitFromCache(status: QueryStatus.success);
  }

  void appendItem(T item) {
    final pages = _cachedPages;
    if (pages == null || pages.isEmpty) {
      _savePages(<List<T>>[<T>[item]]);
    } else {
      final newPages = pages.map((p) => List<T>.of(p)).toList();
      newPages.last.add(item);
      _savePages(newPages);
    }
    _emitFromCache(status: QueryStatus.success);
  }

  // ─── Param-scoped access ─────────────────────────────────────────

  /// Synchronously read the flattened cached data for the given [filters]
  /// (defaults to current filters), from the [QueryClient] cache.
  List<T>? dataFor([P? filters]) {
    final serialized =
        filters != null ? serializeParams(filters) : _serializeFilters(_filters);
    final pages = client.get<List<List<T>>>(cacheKey, serialized)?.data;
    return pages?.expand((p) => p).toList();
  }

  /// Fetch and cache the first page for arbitrary [filters] without disturbing
  /// this controller's current filters or emitted state.
  Future<List<T>> fetchFor(P filters) async {
    final serialized = serializeParams(filters);
    final existing = client.get<List<List<T>>>(cacheKey, serialized);
    if (existing != null && !existing.isStale) {
      return existing.data.expand((p) => p).toList();
    }
    final page = await retryWithBackoff<List<T>>(
      fn: () => queryFn(initialPageParam, filters),
      maxAttempts: _resolvedRetryCount,
      baseDelay: _resolvedRetryDelay,
      shouldAbort: () => _shouldPause,
    );
    client.set<List<List<T>>>(
      cacheKey,
      serialized,
      CachedQueryData<List<List<T>>>(
        data: <List<T>>[page],
        fetchTime: DateTime.now(),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
      ),
    );
    client.reportReachable();
    return page;
  }

  // ─── Stale listener management ───────────────────────────────────

  void _registerStaleListener() {
    if (isClosed || _resolvedStaleTime == null) return;
    _staleHandle.register(_serializeFilters(_filters), () {
      if (!isClosed) {
        _safeEmit(state.copyWith(isStale: true));
      }
    });
  }

  // ─── Refetch interval (polling) ──────────────────────────────────

  void _startRefetchInterval() {
    final interval = _resolvedRefetchInterval;
    if (interval == null || isClosed) return;
    _refetchHandle.start(interval, () {
      if (!isClosed && !state.isRefetching && !state.isLoading) {
        _refetchInternal();
      }
    });
  }

  // ─── Getters ─────────────────────────────────────────────────────

  /// Whether more pages can be loaded.
  bool get hasMore {
    final pages = _cachedPages;
    if (pages == null || pages.isEmpty) return true;
    return getNextPageParam(pages.last, pages) != null;
  }

  /// Number of pages loaded.
  int get currentPage => _cachedPages?.length ?? 0;

  /// Total number of items across all pages.
  int get totalItems => _flatData.length;

  @override
  Future<void> close() {
    _unregisterConnectivity();
    _unregisterLifecycle();
    client.unregisterActiveQuery(
      cacheKey,
      _serializeFilters(_filters),
      onCacheChange: _onCacheChange,
    );
    _staleHandle.unregister();
    _refetchHandle.stop();
    return super.close();
  }
}
