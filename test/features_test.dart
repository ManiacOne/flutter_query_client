import 'dart:async';

import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'features_test.mocks.dart';

// ─── Mock API service ──────────────────────────────────────────────

abstract class ApiService {
  Future<String> fetchData(String key);
  Future<List<String>> fetchPage(int page);
}

@GenerateNiceMocks([MockSpec<ApiService>()])

// ─── Test controllers ──────────────────────────────────────────────

class SimpleQueryController extends QueryController<String, void> {
  final Future<String> Function() fetchFn;
  final RefetchOnMount _refetchOnMount;
  int fetchCount = 0;

  SimpleQueryController({
    required this.fetchFn,
    RefetchOnMount refetchOnMount = RefetchOnMount.always,
    Duration? staleTime,
    String key = 'test',
    ErrorTransformer? transformError,
  })  : _refetchOnMount = refetchOnMount,
        _staleTime = staleTime,
        super(key, transformError: transformError);

  final Duration? _staleTime;

  @override
  RefetchOnMount get refetchOnMount => _refetchOnMount;
  @override
  Duration? get staleTime => _staleTime;
  @override
  int get retryCount => 1;

  @override
  Future<String> queryFn(void params) {
    fetchCount++;
    return fetchFn();
  }
}

class RetryQueryController extends QueryController<String, void> {
  int fetchCount = 0;
  final int _retryCount;

  RetryQueryController({
    int retryCount = 3,
    String key = 'retry-test',
  })  : _retryCount = retryCount,
        super(key);

  @override
  int get retryCount => _retryCount;
  @override
  Duration get retryDelay => const Duration(milliseconds: 10);

  @override
  Future<String> queryFn(void params) async {
    fetchCount++;
    throw Exception('always fails');
  }
}

class ParamQueryController extends QueryController<String, int> {
  int fetchCount = 0;

  ParamQueryController({String key = 'param-test'}) : super(key);

  @override
  int get retryCount => 1;

  @override
  Future<String> queryFn(int? params) async {
    fetchCount++;
    return 'result-$params';
  }
}

class SimpleInfiniteController
    extends InfiniteQueryController<String, int, void> {
  final Future<List<String>> Function(int page) fetchFn;
  int fetchCount = 0;

  SimpleInfiniteController({
    required this.fetchFn,
    String key = 'infinite-test',
  }) : super(key);

  @override
  int get limit => 2;
  @override
  int get retryCount => 1;
  @override
  int get initialPageParam => 0;

  @override
  int? getNextPageParam(List<String> lastPage, List<List<String>> allPages) {
    if (lastPage.length < limit) return null;
    return allPages.length;
  }

  @override
  Future<List<String>> queryFn(int pageParam, void filters) {
    fetchCount++;
    return fetchFn(pageParam);
  }
}

class MockedQueryController extends QueryController<String, void> {
  final MockApiService api;
  int fetchCount = 0;

  MockedQueryController({
    required this.api,
    String key = 'mock-test',
  }) : super(key);

  @override
  int get retryCount => 1;

  @override
  Future<String> queryFn(void params) {
    fetchCount++;
    return api.fetchData('data');
  }
}

class SimpleMutation extends MutationController<String, void> {
  final Future<String> Function()? _fn;
  SimpleMutation({Future<String> Function()? fn}) : _fn = fn;

  @override
  Future<String> mutationFn(void params) =>
      _fn?.call() ?? Future.value('done');
}

// ═══════════════════════════════════════════════════════════════════

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  // ═══════════════════════════════════════════════════════════════════
  // QueryState (freezed) tests
  // ═══════════════════════════════════════════════════════════════════

  group('QueryState (freezed)', () {
    test('default state is idle', () {
      const state = QueryState<String>();
      expect(state.isIdle, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
      expect(state.hasData, isFalse);
      expect(state.hasError, isFalse);
    });

    test('success state with data', () {
      const state = QueryState<String>(
        status: QueryStatus.success,
        data: 'hello',
      );
      expect(state.isSuccess, isTrue);
      expect(state.hasData, isTrue);
    });

    test('refetching state preserves data', () {
      const state = QueryState<String>(
        status: QueryStatus.success,
        data: 'data',
        fetchStatus: FetchStatus.refetching,
      );
      expect(state.isSuccess, isTrue);
      expect(state.isRefetching, isTrue);
      expect(state.hasData, isTrue);
    });

    test('errorAs<T>() returns typed error', () {
      final state = QueryState<String>(
        status: QueryStatus.error,
        error: QueryException('test error'),
      );
      expect(state.errorAs<QueryException>(), isNotNull);
      expect(state.errorAs<QueryException>()!.message, 'test error');
      expect(state.errorAs<FormatException>(), isNull);
    });

    test('equality works correctly (freezed)', () {
      const state1 = QueryState<String>(
        status: QueryStatus.success,
        data: 'hello',
      );
      const state2 = QueryState<String>(
        status: QueryStatus.success,
        data: 'hello',
      );
      expect(state1, equals(state2));
    });

    test('copyWith preserves error when not overridden', () {
      const state = QueryState<String>(
        status: QueryStatus.error,
        error: 'some error',
      );
      final updated = state.copyWith(status: QueryStatus.loading);
      expect(updated.error, 'some error');
    });

    test('copyWith can explicitly clear error', () {
      const state = QueryState<String>(
        status: QueryStatus.error,
        error: 'some error',
      );
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });

    test('mutation emits correct enum states', () async {
      final states = <QueryState<String>>[];
      final mutation = SimpleMutation();
      mutation.stream.listen(states.add);

      await mutation.mutate();
      await mutation.close();

      expect(states.length, 2);
      expect(states[0].isLoading, isTrue);
      expect(states[1].isSuccess, isTrue);
      expect(states[1].data, 'done');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Mockito integration tests
  // ═══════════════════════════════════════════════════════════════════

  group('Mockito integration', () {
    late MockApiService mockApi;

    setUp(() {
      mockApi = MockApiService();
    });

    test('controller uses mocked API service', () async {
      when(mockApi.fetchData('data'))
          .thenAnswer((_) async => 'mocked-result');

      final controller = MockedQueryController(api: mockApi, key: 'mockito-1');

      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.data, 'mocked-result');
      verify(mockApi.fetchData('data')).called(greaterThanOrEqualTo(1));

      await controller.close();
    });

    test('controller handles mocked API failure', () async {
      when(mockApi.fetchData('data'))
          .thenThrow(Exception('network error'));

      final controller = MockedQueryController(api: mockApi, key: 'mockito-2');

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.state.isError, isTrue);

      await controller.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // _safeEmit guard
  // ═══════════════════════════════════════════════════════════════════

  group('_safeEmit (closed controller safety)', () {
    test('QueryController: no crash when closed during fetch', () async {
      final completer = Completer<String>();
      final controller = SimpleQueryController(
        key: 'safe-emit-test',
        fetchFn: () => completer.future,
      );

      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await controller.close();

      completer.complete('late result');
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('MutationController: no crash when closed during mutate', () async {
      final completer = Completer<String>();
      final mutation = SimpleMutation(fn: () => completer.future);

      unawaited(mutation.mutate());
      await Future.delayed(Duration.zero);
      await mutation.close();

      completer.complete('late');
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('InfiniteQueryController: no crash when closed during fetch',
        () async {
      final completer = Completer<List<String>>();
      final controller = SimpleInfiniteController(
        key: 'safe-inf-test',
        fetchFn: (_) => completer.future,
      );

      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await controller.close();

      completer.complete(['late']);
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // QueryException (typed package errors)
  // ═══════════════════════════════════════════════════════════════════

  group('QueryException (retry exhaustion)', () {
    test('wraps error as QueryException after retries exhausted', () async {
      final controller = RetryQueryController(retryCount: 2);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(controller.state.isError, isTrue);
      final error = controller.state.errorAs<QueryException>();
      expect(error, isNotNull);
      expect(error!.message, contains('attempt'));
      expect(error.originalError, isA<Exception>());

      await controller.close();
    });

    test('single attempt (retryCount=1) still wraps as QueryException',
        () async {
      final controller = RetryQueryController(retryCount: 1);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.state.isError, isTrue);
      expect(controller.state.errorAs<QueryException>(), isNotNull);

      await controller.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // transformError
  // ═══════════════════════════════════════════════════════════════════

  group('transformError', () {
    test('per-controller transformError normalizes errors', () async {
      final controller = SimpleQueryController(
        key: 'transform-test',
        fetchFn: () async => throw Exception('api error'),
        transformError: (e) => 'transformed: $e',
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.state.isError, isTrue);
      expect(controller.state.error, isA<String>());
      expect((controller.state.error as String), contains('transformed'));

      await controller.close();
    });

    test('global transformError applies when per-controller is not set',
        () async {
      QueryClient.instance.setDefaults(QueryDefaults(
        transformError: (e) => 'global: $e',
      ));

      final controller = SimpleQueryController(
        key: 'global-transform-test',
        fetchFn: () async => throw Exception('fail'),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.state.error, isA<String>());
      expect((controller.state.error as String), contains('global'));

      await controller.close();
    });

    test('per-controller transformError overrides global', () async {
      QueryClient.instance.setDefaults(QueryDefaults(
        transformError: (e) => 'global: $e',
      ));

      final controller = SimpleQueryController(
        key: 'override-transform-test',
        fetchFn: () async => throw Exception('fail'),
        transformError: (e) => 'local: $e',
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect((controller.state.error as String), contains('local'));

      await controller.close();
    });

    test('broken transformError falls back to original error', () async {
      final controller = SimpleQueryController(
        key: 'broken-transform-test',
        fetchFn: () async => throw Exception('original'),
        transformError: (e) => throw Exception('transform broke'),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.state.isError, isTrue);
      expect(controller.state.error, isNotNull);

      await controller.close();
    });

    test('mutation transformError works', () async {
      final mutation = SimpleMutation(fn: () async => throw Exception('mut fail'));

      QueryClient.instance.setDefaults(QueryDefaults(
        transformError: (e) => 'mut-transformed: $e',
      ));

      await mutation.mutate();

      expect(mutation.state.isError, isTrue);
      expect((mutation.state.error as String), contains('mut-transformed'));

      await mutation.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // RefetchOnMount enum
  // ═══════════════════════════════════════════════════════════════════

  group('RefetchOnMount enum', () {
    test('RefetchOnMount.stale only refetches when data is stale', () async {
      QueryClient.instance.set<String>(
        'rom-stale-test',
        null,
        CachedQueryData(data: 'cached', fetchTime: DateTime.now()),
      );

      final controller = SimpleQueryController(
        key: 'rom-stale-test',
        fetchFn: () async => 'fresh',
        refetchOnMount: RefetchOnMount.stale,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.fetchCount, 0);

      await controller.close();
    });

    test('RefetchOnMount.always refetches even with fresh data', () async {
      QueryClient.instance.set<String>(
        'rom-always-test',
        null,
        CachedQueryData(data: 'cached', fetchTime: DateTime.now()),
      );

      final controller = SimpleQueryController(
        key: 'rom-always-test',
        fetchFn: () async => 'fresh',
        refetchOnMount: RefetchOnMount.always,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.fetchCount, greaterThan(0));

      await controller.close();
    });

    test('global RefetchOnMount.never prevents refetch', () async {
      QueryClient.instance.setDefaults(const QueryDefaults(
        refetchOnMount: RefetchOnMount.never,
      ));

      QueryClient.instance.set<String>(
        'rom-global-test',
        null,
        CachedQueryData(data: 'cached', fetchTime: DateTime.now()),
      );

      final controller = SimpleQueryController(
        key: 'rom-global-test',
        fetchFn: () async => 'fresh',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.fetchCount, 0);

      await controller.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Garbage Collection
  // ═══════════════════════════════════════════════════════════════════

  group('Garbage Collection', () {
    test('cache entry removed after gcTime when no observers', () async {
      QueryClient.instance.setDefaults(const QueryDefaults(
        gcTime: Duration(milliseconds: 50),
      ));

      final controller = SimpleQueryController(
        key: 'gc-test',
        fetchFn: () async => 'data',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(QueryClient.instance.get<String>('gc-test', null), isNotNull);

      await controller.close();

      expect(QueryClient.instance.get<String>('gc-test', null), isNotNull);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(QueryClient.instance.get<String>('gc-test', null), isNull);
    });

    test('GC cancelled when new controller registers before timer fires',
        () async {
      QueryClient.instance.setDefaults(const QueryDefaults(
        gcTime: Duration(milliseconds: 100),
      ));

      final controller1 = SimpleQueryController(
        key: 'gc-cancel-test',
        fetchFn: () async => 'data',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await controller1.close();

      await Future.delayed(const Duration(milliseconds: 30));
      final controller2 = SimpleQueryController(
        key: 'gc-cancel-test',
        fetchFn: () async => 'data2',
      );

      await Future.delayed(const Duration(milliseconds: 150));

      expect(
          QueryClient.instance.get<String>('gc-cancel-test', null), isNotNull);

      await controller2.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // invalidateQueries
  // ═══════════════════════════════════════════════════════════════════

  group('invalidateQueries', () {
    test('invalidates cache for specified keys', () async {
      QueryClient.instance.set<String>(
        'key1',
        null,
        CachedQueryData(data: 'data1', fetchTime: DateTime.now()),
      );
      QueryClient.instance.set<String>(
        'key2',
        null,
        CachedQueryData(data: 'data2', fetchTime: DateTime.now()),
      );
      QueryClient.instance.set<String>(
        'key3',
        null,
        CachedQueryData(data: 'data3', fetchTime: DateTime.now()),
      );

      QueryClient.instance.invalidateQueries(['key1', 'key2']);

      expect(QueryClient.instance.get<String>('key1', null), isNull);
      expect(QueryClient.instance.get<String>('key2', null), isNull);
      expect(QueryClient.instance.get<String>('key3', null), isNotNull);
    });

    test('triggers refetch on active controllers', () async {
      final controller = SimpleQueryController(
        key: 'inv-refetch-test',
        fetchFn: () async => 'data-${DateTime.now().millisecondsSinceEpoch}',
        refetchOnMount: RefetchOnMount.never,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = controller.fetchCount;

      QueryClient.instance.invalidateQueries(['inv-refetch-test']);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.fetchCount, greaterThan(initialCount));

      await controller.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // updateInfiniteQuery (pages array)
  // ═══════════════════════════════════════════════════════════════════

  group('updateInfiniteQuery', () {
    test('updates pages array with type-safe API', () async {
      QueryClient.instance.set<List<List<String>>>(
        'items',
        null,
        CachedQueryData(
          data: [
            ['a', 'b'],
            ['c', 'd']
          ],
          fetchTime: DateTime.now(),
        ),
      );

      QueryClient.instance.updateInfiniteQuery<String>(
        'items',
        (pages) => pages
            .map(
              (page) => page.where((i) => i != 'b').toList(),
            )
            .toList(),
      );

      final cached =
          QueryClient.instance.get<List<List<String>>>('items', null);
      expect(cached, isNotNull);
      expect(cached!.data, [
        ['a'],
        ['c', 'd']
      ]);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Cursor-based InfiniteQueryController
  // ═══════════════════════════════════════════════════════════════════

  group('InfiniteQueryController (cursor-based)', () {
    test('fetches initial page with initialPageParam', () async {
      final controller = SimpleInfiniteController(
        key: 'cursor-init-test',
        fetchFn: (page) async => ['item${page}_0', 'item${page}_1'],
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.data, ['item0_0', 'item0_1']);
      expect(controller.currentPage, 1);

      await controller.close();
    });

    test('loadMore uses getNextPageParam', () async {
      final controller = SimpleInfiniteController(
        key: 'cursor-load-more',
        fetchFn: (page) async => ['p${page}_a', 'p${page}_b'],
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.data, ['p0_a', 'p0_b', 'p1_a', 'p1_b']);
      expect(controller.currentPage, 2);
      expect(controller.totalItems, 4);

      await controller.close();
    });

    test('hasMore returns false when getNextPageParam returns null', () async {
      final controller = SimpleInfiniteController(
        key: 'cursor-no-more',
        fetchFn: (page) async => ['only'],
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.hasMore, isFalse);

      await controller.close();
    });

    test('optimistic updateItem works across pages', () async {
      final controller = SimpleInfiniteController(
        key: 'cursor-update-item',
        fetchFn: (page) async => ['p${page}_a', 'p${page}_b'],
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await controller.loadMore();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.updateItem((item) => item == 'p1_a', 'UPDATED');

      expect(controller.state.data, ['p0_a', 'p0_b', 'UPDATED', 'p1_b']);

      await controller.close();
    });

    test('optimistic removeItem works across pages', () async {
      final controller = SimpleInfiniteController(
        key: 'cursor-remove-item',
        fetchFn: (page) async => ['p${page}_a', 'p${page}_b'],
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await controller.loadMore();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.removeItem((item) => item == 'p0_b');

      expect(controller.state.data, ['p0_a', 'p1_a', 'p1_b']);

      await controller.close();
    });

    test('refetch resets to initial page', () async {
      final controller = SimpleInfiniteController(
        key: 'cursor-refetch',
        fetchFn: (page) async => ['p${page}_a', 'p${page}_b'],
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await controller.loadMore();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.currentPage, 2);

      await controller.refetch();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.currentPage, 1);
      expect(controller.state.data, ['p0_a', 'p0_b']);

      await controller.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Active observer registry
  // ═══════════════════════════════════════════════════════════════════

  group('Active observer registry', () {
    test('controller registers on creation, unregisters on close', () async {
      final controller = SimpleQueryController(
        key: 'register-test',
        fetchFn: () async => 'data',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final countBefore = controller.fetchCount;
      QueryClient.instance.invalidateQueries(['register-test']);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.fetchCount, greaterThan(countBefore));

      await controller.close();

      final countAfterClose = controller.fetchCount;
      QueryClient.instance.invalidateQueries(['register-test']);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.fetchCount, countAfterClose);
    });
  });
}
