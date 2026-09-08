import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/controller/infinite_query_controller.dart';
import 'package:flutter_query_client/src/enums/network_mode.dart';
import 'package:flutter_query_client/src/enums/refetch_on_app_focus.dart';
import 'package:flutter_query_client/src/enums/refetch_on_mount.dart';
import 'package:flutter_query_client/src/enums/refetch_on_reconnect.dart';
import 'package:flutter_query_client/src/models/query_defaults.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// Observes **many independently-paginated infinite queries at once** — the
/// `useQueries` analogue for infinite lists.
///
/// One instance watches a dynamic set of filter-sets (`F`); its state is a
/// `Map<F, QueryState<List<T>>>`, one flattened list + status per filter-set,
/// each with its own pagination (`loadMore(F)`). No juggling several
/// [InfiniteQueryController] instances by hand.
///
/// Internally it manages one [InfiniteQueryController] per filter-set, so all
/// pagination logic (initial page, `loadMore`, `getNextPageParam`, replay-
/// refetch, keepPreviousData, connectivity, app-lifecycle) is reused, not
/// duplicated. Subclasses implement [queryFn] and [getNextPageParam] once.
///
/// ```dart
/// class ProductsByCategory
///     extends InfiniteQueriesController<Product, int, String> {
///   ProductsByCategory() : super('products');
///   @override
///   Future<List<Product>> queryFn(int page, String category) =>
///       api.products(category: category, page: page);
///   @override
///   int? getNextPageParam(List<Product> last, List<List<Product>> all) =>
///       last.length < limit ? null : all.length;
/// }
///
/// final c = ProductsByCategory()..setFilters(['shoes', 'shirts']);
/// c.loadMore('shoes'); // grows only the shoes list
/// ```
abstract class InfiniteQueriesController<T, PageParam, F>
    extends Cubit<Map<F, QueryState<List<T>>>> {
  InfiniteQueriesController(this.cacheKey, {ErrorTransformer? transformError})
      : _transformError = transformError,
        super(const {});

  final String cacheKey;
  final ErrorTransformer? _transformError;

  final Map<F, InfiniteQueryController<T, PageParam, F>> _subs = {};
  final Map<F, StreamSubscription<QueryState<List<T>>>> _subscriptions = {};

  // ─── Subclass contract (implemented once, shared by every filter-set) ─

  /// Fetch a single page for [filters].
  Future<List<T>> queryFn(PageParam pageParam, F filters);

  /// Derive the next page param, or null for "no more pages".
  PageParam? getNextPageParam(List<T> lastPage, List<List<T>> allPages);

  /// First page param. Defaults to [QueryDefaults.initialPageParam].
  PageParam? get initialPageParam => null;

  /// Items per page. Defaults to [QueryDefaults.limit].
  int? get limit => null;

  // ─── Options (override to customize; forwarded to every sub-controller) ─
  // `null` = not overridden → the sub-controller resolves
  // controller override → global [QueryDefaults] → hardcoded fallback.

  Duration? get staleTime => null;
  Duration? get gcTime => null;
  Duration? get refetchInterval => null;
  int? get retryCount => null;
  Duration? get retryDelay => null;
  NetworkMode? get networkMode => null;
  RefetchOnMount? get refetchOnMount => null;
  RefetchOnReconnect? get refetchOnReconnect => null;
  RefetchOnAppFocus? get refetchOnAppFocus => null;
  bool? get refetchIntervalInBackground => null;
  bool? get keepPreviousData => null;

  // ─── Filters ─────────────────────────────────────────────────────

  List<F> get filters => List.unmodifiable(_subs.keys);

  /// Observe exactly [next] filter-sets — spins up a sub-controller for each new
  /// one, disposes removed ones, and re-emits the state map.
  void setFilters(List<F> next) {
    for (final f in _subs.keys.toList()) {
      if (!next.contains(f)) {
        _subscriptions.remove(f)?.cancel();
        _subs.remove(f)?.close();
      }
    }
    for (final f in next) {
      if (!_subs.containsKey(f)) {
        final sub = _DelegatingInfiniteController<T, PageParam, F>(
          cacheKey,
          this,
          transformError: _transformError,
        );
        _subs[f] = sub;
        _subscriptions[f] = sub.stream.listen((_) => _recompute());
        sub.setParams(f);
      }
    }
    _recompute();
  }

  /// Start observing one more filter-set.
  void addFilter(F filters) {
    if (_subs.containsKey(filters)) return;
    setFilters([..._subs.keys, filters]);
  }

  /// Stop observing [filters].
  void removeFilter(F filters) {
    setFilters(_subs.keys.where((f) => f != filters).toList());
  }

  void _recompute() {
    if (isClosed) return;
    emit({for (final e in _subs.entries) e.key: e.value.state});
  }

  // ─── Per-filter-set operations ───────────────────────────────────

  /// The current state for one filter-set (empty if not observed).
  QueryState<List<T>> stateFor(F filters) =>
      _subs[filters]?.state ?? const QueryState();

  /// Load the next page of one filter-set only.
  Future<void> loadMore(F filters) async => _subs[filters]?.loadMore();

  /// Refetch all loaded pages of one filter-set (keeps data during refetch).
  Future<void> refetch(F filters) async => _subs[filters]?.refetch();

  /// Invalidate + refresh one filter-set from the first page.
  Future<void> invalidate(F filters) async =>
      _subs[filters]?.invalidateAndRefresh();

  /// Whether more pages can be loaded for [filters].
  bool hasMore(F filters) => _subs[filters]?.hasMore ?? true;

  /// Refetch-on-visible: called automatically by the `Query*` builder widgets
  /// when the screen becomes visible again (a tab flip or a `Navigator`
  /// pop-back). Delegates to each filter-set's
  /// [InfiniteQueryController.handleRemount] (respects its `refetchOnMount`
  /// policy).
  void handleRemount() {
    for (final sub in _subs.values) {
      sub.handleRemount();
    }
  }

  /// Optimistically update an item across the pages of one filter-set.
  void updateItem(F filters, bool Function(T item) predicate, T updated) =>
      _subs[filters]?.updateItem(predicate, updated);

  /// Optimistically remove items across the pages of one filter-set.
  void removeItem(F filters, bool Function(T item) predicate) =>
      _subs[filters]?.removeItem(predicate);

  @override
  Future<void> close() {
    for (final s in _subscriptions.values) {
      s.cancel();
    }
    _subscriptions.clear();
    for (final sub in _subs.values) {
      sub.close();
    }
    _subs.clear();
    return super.close();
  }
}

/// A concrete [InfiniteQueryController] that delegates its fetch/pagination
/// contract and options to a parent [InfiniteQueriesController], so the parent's
/// single `queryFn`/`getNextPageParam` (and option overrides) drive every
/// filter-set's sub-controller.
class _DelegatingInfiniteController<T, PageParam, F>
    extends InfiniteQueryController<T, PageParam, F> {
  _DelegatingInfiniteController(
    super.cacheKey,
    this._parent, {
    super.transformError,
  });

  final InfiniteQueriesController<T, PageParam, F> _parent;

  @override
  Future<List<T>> queryFn(PageParam pageParam, F? filters) =>
      _parent.queryFn(pageParam, filters as F);

  @override
  PageParam? getNextPageParam(List<T> lastPage, List<List<T>> allPages) =>
      _parent.getNextPageParam(lastPage, allPages);

  @override
  PageParam get initialPageParam =>
      _parent.initialPageParam ?? super.initialPageParam;

  @override
  int get limit => _parent.limit ?? super.limit;

  @override
  Duration? get staleTime => _parent.staleTime;
  @override
  Duration? get gcTime => _parent.gcTime;
  @override
  Duration? get refetchInterval => _parent.refetchInterval;
  @override
  int? get retryCount => _parent.retryCount;
  @override
  Duration? get retryDelay => _parent.retryDelay;
  @override
  NetworkMode? get networkMode => _parent.networkMode;
  @override
  RefetchOnMount? get refetchOnMount => _parent.refetchOnMount;
  @override
  RefetchOnReconnect? get refetchOnReconnect => _parent.refetchOnReconnect;
  @override
  RefetchOnAppFocus? get refetchOnAppFocus => _parent.refetchOnAppFocus;
  @override
  bool? get refetchIntervalInBackground => _parent.refetchIntervalInBackground;
  @override
  bool? get keepPreviousData => _parent.keepPreviousData;
}
