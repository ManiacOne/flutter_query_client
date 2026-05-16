import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/client/query_client.dart';
import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/query_status.dart';
import 'package:flutter_query_client/src/enums/refetch_on_mount.dart';
import 'package:flutter_query_client/src/enums/refetch_on_reconnect.dart';
import 'package:flutter_query_client/src/helpers.dart';
import 'package:flutter_query_client/src/models/cached_query_data.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/query_state.dart';
import 'package:flutter_query_client/src/utils/error_transform_utils.dart';
import 'package:flutter_query_client/src/utils/query_logger.dart';
import 'package:flutter_query_client/src/utils/refetch_interval_handle.dart';
import 'package:flutter_query_client/src/utils/retry_utils.dart';
import 'package:flutter_query_client/src/utils/stale_listener_handle.dart';
import 'package:meta/meta.dart';

/// Controller for cursor-based infinite pagination queries.
///
/// [T] is the item type (e.g. Product).
/// [PageParam] is the page parameter type (e.g. `int` for page numbers,
/// `String` for cursors).
/// [P] is the filters type (`void` for no-filter queries).
///
/// Subclasses must implement [queryFn], [initialPageParam], and
/// [getNextPageParam].
abstract class InfiniteQueryController<T, PageParam, P>
    extends Cubit<QueryState<List<T>>> {
  final String cacheKey;
  final QueryClient client = QueryClient.instance;
  final ErrorTransformer? _transformError;

  final List<List<T>> _pages = [];
  final List<PageParam> _pageParams = [];
  P? _filters;
  bool _isInitialized = false;
  int _filterVersion = 0;

  /// Whether initial execution has been done for [NetworkMode.offlineFirst].
  bool _offlineFirstExecuted = false;

  /// Cached flat list — invalidated on page mutations to avoid repeated allocations.
  List<T>? _flatCache;

  /// Stale-listener handle.
  late final StaleListenerHandle _staleHandle = StaleListenerHandle(
    client: client,
    cacheKey: cacheKey,
  );

  /// Periodic refetch handle.
  final RefetchIntervalHandle _refetchHandle = RefetchIntervalHandle();

  /// Stable callback reference for invalidation.
  late final VoidCallback _onInvalidate = _handleInvalidation;

  /// Stable reconnect callback reference.
  late final ReconnectCallback _onReconnect = _handleReconnect;

  InfiniteQueryController(
    this.cacheKey, {
    ErrorTransformer? transformError,
  })  : _transformError = transformError,
        super(const QueryState()) {
    final params = _serializeFilters(_filters);
    client.registerActiveQuery(
      cacheKey,
      params,
      onInvalidate: _onInvalidate,
    );
    _registerConnectivity();
    _executeFirstPage();
  }

  // ─── Safe emit ──────────────────────────────────────────────────

  void _safeEmit(QueryState<List<T>> newState) {
    if (!isClosed) emit(newState);
  }

  // ─── Error transform ────────────────────────────────────────────

  Object _applyTransformError(Object error) {
    return applyErrorTransform(
      error: error,
      controllerTransform: _transformError,
      globalTransform: client.defaults.transformError,
    );
  }

  // ─── Subclass contract ───────────────────────────────────────────

  /// Fetch a single page of data for the given [pageParam].
  Future<List<T>> queryFn(PageParam pageParam, P? filters);

  /// The initial page parameter (e.g., `0` for page numbers, `''` for cursors).
  PageParam get initialPageParam;

  /// Derive the next page parameter from the last fetched page and all pages.
  /// Return `null` to signal "no more pages."
  PageParam? getNextPageParam(List<T> lastPage, List<List<T>> allPages);

  /// Whether this query should execute.
  bool get enabled => true;

  /// Whether to background-refetch when mounting with cached data.
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;

  /// Items per page (convenience — used in your queryFn/getNextPageParam).
  int get limit => 20;

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

  // ─── Network helpers ────────────────────────────────────────────

  /// Whether the controller should block fetching due to network state.
  bool get _shouldPause {
    final mode = _resolvedNetworkMode;
    if (mode == NetworkMode.always) return false;
    if (mode == NetworkMode.offlineFirst && !_offlineFirstExecuted) return false;
    return !client.isOnline;
  }

  void _registerConnectivity() {
    final mode = _resolvedNetworkMode;
    if (mode == NetworkMode.always) return;
    // Fire-and-forget — errors are handled internally.
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

    // Always refetch if in error state — the failure was likely network-related.
    if (state.isError) {
      QueryLogger.info('[$cacheKey] Retrying after error (reconnect)');
      _executeFirstPage();
      return;
    }

    final ror = _resolvedRefetchOnReconnect;
    if (ror == RefetchOnReconnect.never) return;

    final dataIsStale = state.isStale ||
        (state.hasData &&
            _resolvedStaleTime != null &&
            client
                    .get<List<List<T>>>(cacheKey, _serializeFilters(_filters))
                    ?.isStale ==
                true);

    if (ror == RefetchOnReconnect.ifStale && !dataIsStale && state.hasData) {
      if (state.isPaused) {
        _safeEmit(state.copyWith(fetchStatus: FetchStatus.idle));
      }
      return;
    }

    QueryLogger.info('[$cacheKey] Refetching on reconnect (refetchOnReconnect: ${ror.name})');
    if (state.hasData) {
      _refetchInternal();
    } else {
      _executeFirstPage();
    }
  }

  // ─── Internal helpers ────────────────────────────────────────────

  List<T> get _flatData => _flatCache ??= _pages.expand((p) => p).toList();

  void _invalidateFlat() => _flatCache = null;

  // ─── Filters ─────────────────────────────────────────────────────

  P? get filters => _filters;

  /// Update filters, reset pagination, and re-fetch from initial page.
  void setParams(P params) {
    final oldSerialized = _serializeFilters(_filters);
    final newSerialized = serializeParams(params);
    final bool filtersChanged = _isInitialized && oldSerialized != newSerialized;

    if (filtersChanged) {
      _saveToCache();

      _unregisterConnectivity();
      client.unregisterActiveQuery(
        cacheKey,
        oldSerialized,
        onInvalidate: _onInvalidate,
      );

      _resetPagination();
      _filterVersion++;
      _filters = params;

      client.registerActiveQuery(
        cacheKey,
        _serializeFilters(_filters),
        onInvalidate: _onInvalidate,
      );
      _registerConnectivity();

      if (_restoreFromCache(params)) {
        _safeEmit(QueryState<List<T>>(
          status: QueryStatus.success,
          data: _flatData,
        ));
        return;
      }
    } else {
      _filters = params;
    }

    _executeFirstPage();
  }

  // ─── Invalidation callback ───────────────────────────────────────

  void _handleInvalidation() {
    if (!isClosed) refetch();
  }

  // ─── Cache helpers ───────────────────────────────────────────────

  String? _serializeFilters([P? filters]) {
    return serializeParams(filters);
  }

  void _saveToCache() {
    if (_pages.isEmpty) return;
    client.set<List<List<T>>>(
      cacheKey,
      _serializeFilters(_filters),
      CachedQueryData<List<List<T>>>(
        data: _pages.map((p) => List<T>.from(p)).toList(),
        fetchTime: DateTime.now(),
        staleTime: _resolvedStaleTime,
        gcTime: _resolvedGcTime,
      ),
    );
  }

  bool _restoreFromCache(P? filters) {
    final params = _serializeFilters(filters);
    final cached = client.get<List<List<T>>>(cacheKey, params);
    if (cached != null && cached.isValid) {
      _pages.clear();
      _pageParams.clear();
      for (var i = 0; i < cached.data.length; i++) {
        _pages.add(List<T>.from(cached.data[i]));
        if (i == 0) {
          _pageParams.add(initialPageParam);
        } else {
          final nextParam =
              getNextPageParam(_pages[i - 1], _pages.sublist(0, i));
          if (nextParam != null) {
            _pageParams.add(nextParam);
          }
        }
      }
      _invalidateFlat();
      return true;
    }
    return false;
  }

  void _resetPagination() {
    _pages.clear();
    _pageParams.clear();
    _invalidateFlat();
  }

  // ─── First page execution ───────────────────────────────────────

  Future<void> _executeFirstPage() async {
    if (!enabled) return;

    _isInitialized = true;

    if (_pages.isEmpty && _restoreFromCache(_filters)) {
      await Future.delayed(Duration.zero);
      final cached = client.get<List<List<T>>>(
        cacheKey,
        _serializeFilters(_filters),
      );
      _safeEmit(QueryState<List<T>>(
        status: QueryStatus.success,
        data: _flatData,
        isStale: cached?.isStale ?? false,
      ));
      _registerStaleListener();
      _startRefetchInterval();
      final rom = _resolvedRefetchOnMount;
      if (rom == RefetchOnMount.always ||
          (rom == RefetchOnMount.stale && (cached?.isStale ?? false))) {
        _refetchInternal();
      }
      return;
    }

    if (_pages.isNotEmpty) return;
    if (state.isLoading || state.isLoadingMore) return;

    // Check network before fetching.
    if (_shouldPause) {
      await Future.delayed(Duration.zero);
      _safeEmit(state.copyWith(fetchStatus: FetchStatus.paused));
      return;
    }

    final capturedVersion = _filterVersion;

    await Future.delayed(Duration.zero);
    _safeEmit(const QueryState(status: QueryStatus.loading));

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

      _pages.add(pageData);
      _pageParams.add(initialPageParam);
      _invalidateFlat();
      _saveToCache();
      _registerStaleListener();
      _startRefetchInterval();

      _safeEmit(QueryState<List<T>>(
        status: QueryStatus.success,
        data: _flatData,
      ));
    } catch (e) {
      if (capturedVersion != _filterVersion) return;
      _safeEmit(state.copyWith(
        status: QueryStatus.error,
        error: _applyTransformError(e),
      ));
    }
  }

  // ─── Remount (hidden → visible) ───────────────────────────────────

  /// Called by the provider when the widget transitions from hidden → visible.
  @internal
  void handleRemount() {
    if (!enabled) return;
    if (state.isLoading || state.isRefetching || state.isLoadingMore) return;

    // Always retry if in error state — the network issue may have resolved.
    if (state.isError) {
      QueryLogger.info('[$cacheKey] Retrying after error (remount, infinite)');
      _resetPagination();
      _executeFirstPage();
      return;
    }

    final params = _serializeFilters(_filters);
    final cached = client.get<List<List<T>>>(cacheKey, params);

    if (cached == null) return;

    final cachedFlat = cached.data.expand((p) => p).toList();
    if (_flatData.length != cachedFlat.length ||
        !identical(_flatData, state.data)) {
      _pages.clear();
      _pageParams.clear();
      for (var i = 0; i < cached.data.length; i++) {
        _pages.add(List<T>.from(cached.data[i]));
        if (i == 0) {
          _pageParams.add(initialPageParam);
        } else {
          final nextParam =
              getNextPageParam(_pages[i - 1], _pages.sublist(0, i));
          if (nextParam != null) _pageParams.add(nextParam);
        }
      }
      _invalidateFlat();
      _safeEmit(QueryState<List<T>>(
        status: QueryStatus.success,
        data: _flatData,
        isStale: cached.isStale,
      ));
    }

    final rom = _resolvedRefetchOnMount;
    if (rom == RefetchOnMount.always ||
        (rom == RefetchOnMount.stale && cached.isStale)) {
      _refetchInternal();
    }
  }

  // ─── Load more ───────────────────────────────────────────────────

  /// Fetch the next page of data.
  ///
  /// Returns early if the device is offline and [networkMode] requires
  /// connectivity. User-triggered action — fails fast rather than queuing.
  Future<void> loadMore() async {
    if (!enabled) return;
    if (_pages.isEmpty) return;

    final nextParam = getNextPageParam(_pages.last, _pages);
    if (nextParam == null) return;
    if (state.isLoading || state.isLoadingMore) return;

    // Fail fast if offline and network is required.
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

      _pages.add(pageData);
      _pageParams.add(nextParam);
      _invalidateFlat();
      _saveToCache();
      _registerStaleListener();

      _safeEmit(QueryState<List<T>>(
        status: QueryStatus.success,
        data: _flatData,
      ));
    } catch (e) {
      if (capturedVersion != _filterVersion) return;
      _safeEmit(state.copyWith(
        error: _applyTransformError(e),
        isLoadingMore: false,
      ));
    }
  }

  // ─── Refetch ─────────────────────────────────────────────────────

  /// Refetch from initial page.
  Future<void> refetch() async {
    if (!enabled) return;
    await _refetchInternal();
  }

  Future<void> _refetchInternal() async {
    // Check network before refetching.
    if (_shouldPause) {
      _safeEmit(state.copyWith(fetchStatus: FetchStatus.paused));
      _refetchHandle.pause();
      return;
    }

    final capturedVersion = _filterVersion;
    _safeEmit(state.copyWith(fetchStatus: FetchStatus.refetching));

    try {
      final pageData = await retryWithBackoff<List<T>>(
        fn: () => queryFn(initialPageParam, _filters),
        maxAttempts: _resolvedRetryCount,
        baseDelay: _resolvedRetryDelay,
        shouldAbort: () => _shouldPause,
      );

      if (capturedVersion != _filterVersion) return;

      _pages.clear();
      _pageParams.clear();
      _pages.add(pageData);
      _pageParams.add(initialPageParam);
      _invalidateFlat();
      _saveToCache();
      _registerStaleListener();
      _startRefetchInterval();

      _safeEmit(QueryState<List<T>>(
        status: QueryStatus.success,
        data: _flatData,
      ));
    } catch (e) {
      if (capturedVersion != _filterVersion) return;
      _safeEmit(state.copyWith(
        error: _applyTransformError(e),
        fetchStatus: FetchStatus.idle,
      ));
    }
  }

  // ─── Invalidate & refresh ────────────────────────────────────────

  Future<void> invalidateAndRefresh() async {
    client.invalidate(cacheKey, _serializeFilters(_filters));
    reset();
    await _executeFirstPage();
  }

  /// Reset pagination state to initial.
  void reset() {
    _pages.clear();
    _pageParams.clear();
    _invalidateFlat();
    _safeEmit(const QueryState());
  }

  // ─── Optimistic updates ──────────────────────────────────────────

  void updateItem(bool Function(T item) predicate, T updatedItem) {
    for (var i = 0; i < _pages.length; i++) {
      final idx = _pages[i].indexWhere(predicate);
      if (idx != -1) {
        _pages[i][idx] = updatedItem;
        _invalidateFlat();
        _safeEmit(QueryState<List<T>>(
          status: QueryStatus.success,
          data: _flatData,
        ));
        return;
      }
    }
  }

  void removeItem(bool Function(T item) predicate) {
    for (final page in _pages) {
      page.removeWhere(predicate);
    }
    _invalidateFlat();
    _safeEmit(QueryState<List<T>>(
      status: QueryStatus.success,
      data: _flatData,
    ));
  }

  void prependItem(T item) {
    if (_pages.isEmpty) {
      _pages.add([item]);
      _pageParams.add(initialPageParam);
    } else {
      _pages.first.insert(0, item);
    }
    _invalidateFlat();
    _safeEmit(QueryState<List<T>>(
      status: QueryStatus.success,
      data: _flatData,
    ));
  }

  void appendItem(T item) {
    if (_pages.isEmpty) {
      _pages.add([item]);
      _pageParams.add(initialPageParam);
    } else {
      _pages.last.add(item);
    }
    _invalidateFlat();
    _safeEmit(QueryState<List<T>>(
      status: QueryStatus.success,
      data: _flatData,
    ));
  }

  // ─── Stale listener management ───────────────────────────────────

  void _registerStaleListener() {
    if (isClosed || _resolvedStaleTime == null) return;
    final params = _serializeFilters(_filters);
    _staleHandle.register(params, () {
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
    if (_pages.isEmpty) return true;
    return getNextPageParam(_pages.last, _pages) != null;
  }

  /// Number of pages loaded.
  int get currentPage => _pages.length;

  /// Total number of items across all pages.
  int get totalItems => _flatData.length;

  @override
  Future<void> close() {
    _unregisterConnectivity();
    client.unregisterActiveQuery(
      cacheKey,
      _serializeFilters(_filters),
      onInvalidate: _onInvalidate,
    );
    _staleHandle.unregister();
    _refetchHandle.stop();
    return super.close();
  }
}
