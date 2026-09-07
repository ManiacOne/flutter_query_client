import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Test helpers ──────────────────────────────────────────────────

class TestQueryController extends QueryController<List<String>, void> {
  final Future<List<String>> Function() fetchFn;
  final RefetchOnMount _refetchOnMount;

  int fetchCount = 0;

  TestQueryController({
    required this.fetchFn,
    RefetchOnMount refetchOnMount = RefetchOnMount.always,
    String key = 'test',
  }) : _refetchOnMount = refetchOnMount,
       super(key);

  @override
  RefetchOnMount get refetchOnMount => _refetchOnMount;
  @override
  int get retryCount => 1;

  @override
  Future<List<String>> queryFn(void params) {
    fetchCount++;
    return fetchFn();
  }
}

class StaleTestQueryController extends QueryController<String, void> {
  final Future<String> Function() fetchFn;
  final RefetchOnMount _refetchOnMount;
  int fetchCount = 0;
  final Duration _staleTime;

  StaleTestQueryController({
    required this.fetchFn,
    RefetchOnMount refetchOnMount = RefetchOnMount.never,
    Duration staleTime = const Duration(milliseconds: 50),
    String key = 'stale-test',
  }) : _refetchOnMount = refetchOnMount,
       _staleTime = staleTime,
       super(key);

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

class DisabledQueryController extends QueryController<String, int> {
  int fetchCount = 0;

  DisabledQueryController() : super('disabled-test');

  @override
  int get retryCount => 1;

  @override
  Future<String> queryFn(int? params) async {
    fetchCount++;
    return 'result-$params';
  }
}

class TestInfiniteQueryController
    extends InfiniteQueryController<String, int, void> {
  final Future<List<String>> Function(int page) fetchFn;
  final RefetchOnMount _refetchOnMount;
  int fetchCount = 0;

  TestInfiniteQueryController({
    required this.fetchFn,
    RefetchOnMount refetchOnMount = RefetchOnMount.always,
    String key = 'infinite-test',
  }) : _refetchOnMount = refetchOnMount,
       super(key);

  @override
  RefetchOnMount get refetchOnMount => _refetchOnMount;
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

Widget buildTickerModeHarness({
  required ValueNotifier<bool> tickerEnabled,
  required Widget child,
}) {
  return MaterialApp(
    home: ValueListenableBuilder<bool>(
      valueListenable: tickerEnabled,
      builder: (_, enabled, __) {
        return TickerMode(enabled: enabled, child: child);
      },
    ),
  );
}

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  // ═══════════════════════════════════════════════════════════════════
  // QueryController.handleRemount() tests
  // ═══════════════════════════════════════════════════════════════════

  group('QueryProvider remount (TickerMode)', () {
    testWidgets('refetchOnMount=always triggers refetch on hidden→visible', (
      tester,
    ) async {
      final controller = TestQueryController(
        fetchFn: () async => ['a', 'b', 'c'],
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: QueryBuilder<TestQueryController, List<String>>(
              builder: (_, state) => Text(state.data?.join(',') ?? 'loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialFetchCount = controller.fetchCount;
      expect(initialFetchCount, greaterThanOrEqualTo(1));

      tickerEnabled.value = false;
      await tester.pumpAndSettle();
      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(controller.fetchCount, greaterThan(initialFetchCount));
    });

    testWidgets('refetchOnMount=never does NOT refetch on remount', (
      tester,
    ) async {
      final controller = TestQueryController(
        fetchFn: () async => ['a', 'b'],
        refetchOnMount: RefetchOnMount.never,
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: QueryBuilder<TestQueryController, List<String>>(
              builder: (_, state) => Text(state.data?.join(',') ?? 'loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final countAfterInit = controller.fetchCount;

      tickerEnabled.value = false;
      await tester.pumpAndSettle();
      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(controller.fetchCount, countAfterInit);
    });

    testWidgets('external cache update is synced on remount without refetch', (
      tester,
    ) async {
      final controller = TestQueryController(
        key: 'sync-test',
        fetchFn: () async => ['post1', 'post2', 'post3'],
        refetchOnMount: RefetchOnMount.never,
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: QueryBuilder<TestQueryController, List<String>>(
              builder: (_, state) => Text(state.data?.join(',') ?? 'loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('post1,post2,post3'), findsOneWidget);
      final countAfterInit = controller.fetchCount;

      tickerEnabled.value = false;
      await tester.pumpAndSettle();

      QueryClient.instance.update<List<String>>(
        'sync-test',
        (posts) => posts.where((p) => p != 'post2').toList(),
      );

      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(find.text('post1,post3'), findsOneWidget);
      expect(controller.fetchCount, countAfterInit);
    });

    testWidgets('dialog does NOT trigger false-positive remount', (
      tester,
    ) async {
      final controller = TestQueryController(fetchFn: () async => ['data']);

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      late BuildContext capturedContext;

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: QueryBuilder<TestQueryController, List<String>>(
              builder: (ctx, state) {
                capturedContext = ctx;
                return Text(state.data?.join(',') ?? 'loading');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final countAfterInit = controller.fetchCount;

      showDialog(
        context: capturedContext,
        builder: (_) => const AlertDialog(title: Text('Confirm?')),
      );
      await tester.pumpAndSettle();

      Navigator.of(capturedContext).pop();
      await tester.pumpAndSettle();

      expect(controller.fetchCount, countAfterInit);
    });

    testWidgets('disabled controller skips handleRemount', (tester) async {
      final controller = DisabledQueryController();

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<DisabledQueryController, String>(
            create: (_) => controller,
            child: QueryBuilder<DisabledQueryController, String>(
              builder: (_, state) => Text(state.data ?? 'no-data'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.fetchCount, 0);

      tickerEnabled.value = false;
      await tester.pumpAndSettle();
      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(controller.fetchCount, 0);
    });

    testWidgets('stale data triggers refetch even with refetchOnMount=stale', (
      tester,
    ) async {
      int callCount = 0;
      final controller = StaleTestQueryController(
        key: 'stale-remount-test',
        fetchFn: () async {
          callCount++;
          return 'result-$callCount';
        },
        refetchOnMount: RefetchOnMount.stale,
        staleTime: const Duration(milliseconds: 50),
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<StaleTestQueryController, String>(
            create: (_) => controller,
            child: QueryBuilder<StaleTestQueryController, String>(
              builder: (_, state) => Text(state.data ?? 'loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final countAfterInit = controller.fetchCount;

      tickerEnabled.value = false;
      await tester.pumpAndSettle();

      QueryClient.instance.set<String>(
        'stale-remount-test',
        null,
        CachedQueryData<String>(
          data: 'stale-data',
          fetchTime: DateTime.now().subtract(const Duration(seconds: 1)),
          staleTime: const Duration(milliseconds: 50),
        ),
      );

      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(controller.fetchCount, greaterThan(countAfterInit));
    });

    testWidgets('context.query<T>() still works after provider conversion', (
      tester,
    ) async {
      final controller = TestQueryController(fetchFn: () async => ['works']);

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      TestQueryController? foundController;

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: Builder(
              builder: (ctx) {
                foundController = ctx.query<TestQueryController>();
                return const Text('check');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(foundController, isNotNull);
      expect(foundController, same(controller));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // InfiniteQueryController remount tests
  // ═══════════════════════════════════════════════════════════════════

  group('InfiniteQueryProvider remount (TickerMode)', () {
    testWidgets('refetchOnMount=always triggers refetch on hidden→visible', (
      tester,
    ) async {
      final controller = TestInfiniteQueryController(
        key: 'inf-remount-test',
        fetchFn: (page) async => ['item${page}_0', 'item${page}_1'],
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: InfiniteQueryProvider<TestInfiniteQueryController>(
            create: (_) => controller,
            child: InfiniteQueryBuilder<TestInfiniteQueryController, String>(builder: (_, state) => Text(state.data?.join(',') ?? 'loading')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialFetchCount = controller.fetchCount;

      tickerEnabled.value = false;
      await tester.pumpAndSettle();
      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(controller.fetchCount, greaterThan(initialFetchCount));
    });

    testWidgets('refetchOnMount=never does NOT refetch on remount', (
      tester,
    ) async {
      final controller = TestInfiniteQueryController(
        key: 'inf-no-remount',
        fetchFn: (page) async => ['a', 'b'],
        refetchOnMount: RefetchOnMount.never,
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: InfiniteQueryProvider<TestInfiniteQueryController>(
            create: (_) => controller,
            child: InfiniteQueryBuilder<TestInfiniteQueryController, String>(builder: (_, state) => Text(state.data?.join(',') ?? 'loading')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final countAfterInit = controller.fetchCount;

      tickerEnabled.value = false;
      await tester.pumpAndSettle();
      tickerEnabled.value = true;
      await tester.pumpAndSettle();

      expect(controller.fetchCount, countAfterInit);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // IndexedStack (Visibility.of detection)
  // ═══════════════════════════════════════════════════════════════════

  group('IndexedStack (Visibility.of detection)', () {
    testWidgets('refetchOnMount triggers refetch on tab switch', (
      tester,
    ) async {
      final postsController = TestQueryController(
        key: 'idx-posts',
        fetchFn: () async => ['post1', 'post2'],
      );
      final productsController = TestQueryController(
        key: 'idx-products',
        fetchFn: () async => ['product1'],
      );

      int currentIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return Scaffold(
                body: IndexedStack(
                  index: currentIndex,
                  children: [
                    QueryProvider<TestQueryController, List<String>>(
                      create: (_) => postsController,
                      child: QueryBuilder<TestQueryController, List<String>>(
                        builder:
                            (_, state) =>
                                Text(state.data?.join(',') ?? 'loading-posts'),
                      ),
                    ),
                    QueryProvider<TestQueryController, List<String>>(
                      create: (_) => productsController,
                      child: QueryBuilder<TestQueryController, List<String>>(
                        builder:
                            (_, state) => Text(
                              state.data?.join(',') ?? 'loading-products',
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final productsInitCount = productsController.fetchCount;

      outerSetState(() => currentIndex = 1);
      await tester.pumpAndSettle();

      expect(productsController.fetchCount, greaterThan(productsInitCount));

      final postsCountBeforeReturn = postsController.fetchCount;

      outerSetState(() => currentIndex = 0);
      await tester.pumpAndSettle();

      expect(postsController.fetchCount, greaterThan(postsCountBeforeReturn));
    });

    testWidgets('InfiniteQuery works with IndexedStack', (tester) async {
      final controller = TestInfiniteQueryController(
        key: 'idx-infinite',
        fetchFn: (page) async => ['a', 'b'],
      );

      int currentIndex = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (ctx, setState) {
              outerSetState = setState;
              return Scaffold(
                body: IndexedStack(
                  index: currentIndex,
                  children: [
                    InfiniteQueryProvider<TestInfiniteQueryController>(
                      create: (_) => controller,
                      child: InfiniteQueryBuilder<TestInfiniteQueryController, String>(
                        builder:
                            (_, state) =>
                                Text(state.data?.join(',') ?? 'loading'),
                      ),
                    ),
                    const Text('tab2'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialCount = controller.fetchCount;

      outerSetState(() => currentIndex = 1);
      await tester.pumpAndSettle();
      outerSetState(() => currentIndex = 0);
      await tester.pumpAndSettle();

      expect(controller.fetchCount, greaterThan(initialCount));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // QueryNavigatorObserver (Navigator push/pop detection) — new in 4.0
  // ═══════════════════════════════════════════════════════════════════

  group('QueryNavigatorObserver (push/pop detection)', () {
    testWidgets('popping a pushed page refetches the revealed screen', (
      tester,
    ) async {
      final controller = TestQueryController(
        key: 'nav-pop-test',
        fetchFn: () async => ['a', 'b'],
      );

      late BuildContext listContext;

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [QueryNavigatorObserver.instance],
          home: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: Builder(
              builder: (ctx) {
                listContext = ctx;
                return QueryBuilder<TestQueryController, List<String>>(builder: (_, state) => Text(state.data?.join(',') ?? 'loading'));
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final countBeforePush = controller.fetchCount;
      expect(countBeforePush, greaterThanOrEqualTo(1));

      // Push a full-screen page over the list, then pop back.
      Navigator.of(listContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      final countWhileCovered = controller.fetchCount;
      Navigator.of(listContext).pop();
      await tester.pumpAndSettle();

      // didPopNext → handleRemount → refetch (refetchOnMount defaults to always).
      expect(controller.fetchCount, greaterThan(countWhileCovered));
    });

    testWidgets('dismissing a dialog does NOT refetch (PopupRoute ignored)', (
      tester,
    ) async {
      final controller = TestQueryController(
        key: 'nav-dialog-test',
        fetchFn: () async => ['a', 'b'],
      );

      late BuildContext listContext;

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [QueryNavigatorObserver.instance],
          home: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: Builder(
              builder: (ctx) {
                listContext = ctx;
                return const Text('list');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final countBeforeDialog = controller.fetchCount;

      showDialog<void>(
        context: listContext,
        builder: (_) => const AlertDialog(title: Text('Confirm?')),
      );
      await tester.pumpAndSettle();
      Navigator.of(listContext).pop();
      await tester.pumpAndSettle();

      expect(controller.fetchCount, countBeforeDialog);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Edge cases
  // ═══════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    testWidgets('closed controller is not called on remount', (tester) async {
      late TestQueryController controller;
      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) {
              controller = TestQueryController(
                key: 'close-test',
                fetchFn: () async => ['data'],
              );
              return controller;
            },
            child: QueryBuilder<TestQueryController, List<String>>(
              builder: (_, state) => Text(state.data?.join(',') ?? 'loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await controller.close();

      tickerEnabled.value = false;
      await tester.pump();
      tickerEnabled.value = true;
      await tester.pump();
      // No crash = pass.
    });

    testWidgets('multiple false→true transitions are handled correctly', (
      tester,
    ) async {
      final controller = TestQueryController(
        key: 'multi-transition',
        fetchFn: () async => ['data'],
      );

      final tickerEnabled = ValueNotifier(true);
      addTearDown(() => tickerEnabled.dispose());

      await tester.pumpWidget(
        buildTickerModeHarness(
          tickerEnabled: tickerEnabled,
          child: QueryProvider<TestQueryController, List<String>>(
            create: (_) => controller,
            child: QueryBuilder<TestQueryController, List<String>>(
              builder: (_, state) => Text(state.data?.join(',') ?? 'loading'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        tickerEnabled.value = false;
        await tester.pumpAndSettle();
        tickerEnabled.value = true;
        await tester.pumpAndSettle();
      }

      expect(find.text('data'), findsOneWidget);
    });
  });
}
