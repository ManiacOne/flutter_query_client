import 'package:flutter/widgets.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

class ResumeQuery extends QueryController<String, void> {
  int fetchCount = 0;
  ResumeQuery(String key) : super(key);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.never;
  @override
  RefetchOnAppFocus get refetchOnAppFocus => RefetchOnAppFocus.always;
  @override
  Future<String> queryFn(void _) async {
    fetchCount++;
    return 'v';
  }
}

/// Interval polling with focus-refetch disabled, so a refetch on resume can
/// only come from the wall-clock interval being past-due.
class IntervalQuery extends QueryController<String, void> {
  int fetchCount = 0;
  IntervalQuery(String key) : super(key);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.never;
  @override
  RefetchOnAppFocus get refetchOnAppFocus => RefetchOnAppFocus.never;
  @override
  Duration? get refetchInterval => const Duration(milliseconds: 100);
  @override
  Future<String> queryFn(void _) async {
    fetchCount++;
    return 'v';
  }
}

class ResumeQueries extends QueriesController<String, int> {
  final Map<int, int> counts = {};
  ResumeQueries(String key) : super(key);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  RefetchOnAppFocus get refetchOnAppFocus => RefetchOnAppFocus.always;
  @override
  Future<String> queryFn(int p) async {
    counts[p] = (counts[p] ?? 0) + 1;
    return 'v-$p';
  }
}

class ProductsByCat extends InfiniteQueriesController<String, int, String> {
  final Map<String, int> fetchCounts = {};
  ProductsByCat(String key) : super(key);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  int? get limit => 2;
  @override
  int? get initialPageParam => 0;
  @override
  int? getNextPageParam(List<String> last, List<List<String>> all) {
    if (last.length < limit!) return null;
    return all.length;
  }

  @override
  Future<List<String>> queryFn(int page, String cat) async {
    fetchCounts[cat] = (fetchCounts[cat] ?? 0) + 1;
    return ['$cat-p$page-a', '$cat-p$page-b'];
  }
}

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  group('App lifecycle', () {
    test('QueryController refetches on resume (refetchOnAppFocus.always)',
        () async {
      final c = ResumeQuery('lc');
      await Future.delayed(const Duration(milliseconds: 50));
      final before = c.fetchCount;

      QueryClient.instance.emitAppLifecycle(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(c.fetchCount, greaterThan(before));
      await c.close();
    });

    test('past-due refetchInterval fires immediately on resume', () async {
      final c = IntervalQuery('iv');
      await Future.delayed(const Duration(milliseconds: 40));
      final before = c.fetchCount; // 1 (initial), interval (100ms) armed

      // Background before the interval fires, then stay away longer than a
      // full interval so the poll becomes overdue.
      QueryClient.instance.emitAppLifecycle(AppLifecycleState.paused);
      await Future.delayed(const Duration(milliseconds: 130));
      // refetchOnAppFocus is never, so any refetch here is from the past-due
      // interval, not focus.
      QueryClient.instance.emitAppLifecycle(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 30));

      expect(c.fetchCount, greaterThan(before),
          reason: 'overdue poll should fire immediately on resume');
      await c.close();
    });

    test('non-overdue resume does NOT immediately refetch', () async {
      final c = IntervalQuery('iv2');
      await Future.delayed(const Duration(milliseconds: 40));
      final before = c.fetchCount;

      QueryClient.instance.emitAppLifecycle(AppLifecycleState.paused);
      await Future.delayed(const Duration(milliseconds: 20)); // < interval
      QueryClient.instance.emitAppLifecycle(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 10));

      // Not past-due and focus refetch is off → no immediate refetch.
      expect(c.fetchCount, before);
      await c.close();
    });

    test('QueriesController refetches every observed param on resume', () async {
      final c = ResumeQueries('lq');
      c.setParams([1, 2]);
      await Future.delayed(const Duration(milliseconds: 50));
      final b1 = c.counts[1]!;
      final b2 = c.counts[2]!;

      QueryClient.instance.emitAppLifecycle(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(c.counts[1], greaterThan(b1));
      expect(c.counts[2], greaterThan(b2));
      await c.close();
    });
  });

  group('InfiniteQueriesController', () {
    test('independent pagination per filter-set', () async {
      final c = ProductsByCat('inf_multi');
      c.setFilters(['shoes', 'shirts']);
      await Future.delayed(const Duration(milliseconds: 60));

      expect(c.stateFor('shoes').data, ['shoes-p0-a', 'shoes-p0-b']);
      expect(c.stateFor('shirts').data, ['shirts-p0-a', 'shirts-p0-b']);

      await c.loadMore('shoes');
      await Future.delayed(const Duration(milliseconds: 60));

      // Only shoes grew.
      expect(c.stateFor('shoes').data!.length, 4);
      expect(c.stateFor('shirts').data!.length, 2);

      await c.close();
    });

    test('invalidate(F) refetches only that filter-set', () async {
      final c = ProductsByCat('inf_multi2');
      c.setFilters(['a', 'b']);
      await Future.delayed(const Duration(milliseconds: 60));
      final bBefore = c.fetchCounts['b'];

      await c.invalidate('a');
      await Future.delayed(const Duration(milliseconds: 60));

      expect(c.fetchCounts['a'], greaterThan(1));
      expect(c.fetchCounts['b'], bBefore, reason: 'b untouched');
      await c.close();
    });

    test('removeFilter drops that filter-set from state', () async {
      final c = ProductsByCat('inf_multi3');
      c.setFilters(['x', 'y']);
      await Future.delayed(const Duration(milliseconds: 60));
      expect(c.state.length, 2);

      c.removeFilter('y');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(c.state.containsKey('y'), isFalse);
      expect(c.state.containsKey('x'), isTrue);
      await c.close();
    });
  });
}
