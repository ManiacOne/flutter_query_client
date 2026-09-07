import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

class RemountQueries extends QueriesController<String, int> {
  final Map<int, int> counts = {};
  RemountQueries(String key) : super(key);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;
  @override
  Future<String> queryFn(int p) async {
    counts[p] = (counts[p] ?? 0) + 1;
    return 'v-$p';
  }
}

class RemountInfinite extends InfiniteQueriesController<String, int, String> {
  final Map<String, int> counts = {};
  RemountInfinite(String key) : super(key);
  @override
  NetworkMode get networkMode => NetworkMode.always;
  @override
  int? get limit => 2;
  @override
  int? get initialPageParam => 0;
  @override
  int? getNextPageParam(List<String> last, List<List<String>> all) =>
      last.length < limit! ? null : all.length;
  @override
  Future<List<String>> queryFn(int page, String f) async {
    counts[f] = (counts[f] ?? 0) + 1;
    return ['$f-$page-a', '$f-$page-b'];
  }
}

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  testWidgets('QueriesProvider auto-refetches on TickerMode hidden→visible',
      (tester) async {
    final controller = RemountQueries('provider-remount')..setParams([1]);
    final tickerEnabled = ValueNotifier(true);
    addTearDown(tickerEnabled.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: tickerEnabled,
          builder: (_, enabled, __) => TickerMode(
            enabled: enabled,
            child: QueriesProvider<RemountQueries, String, int>(
              create: (_) => controller,
              child: QueriesBuilder<RemountQueries, String, int>(
                builder: (_, states) => Text('${states.length}'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = controller.counts[1] ?? 0;

    tickerEnabled.value = false;
    await tester.pumpAndSettle();
    tickerEnabled.value = true;
    await tester.pumpAndSettle();

    expect(controller.counts[1], greaterThan(before),
        reason: 'provider called handleRemount on becoming visible again');
  });

  test('QueriesController.handleRemount refetches observed params', () async {
    final c = RemountQueries('rq');
    c.setParams([1, 2]);
    await Future.delayed(const Duration(milliseconds: 50));
    final b1 = c.counts[1]!;
    final b2 = c.counts[2]!;

    c.handleRemount();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(c.counts[1], greaterThan(b1));
    expect(c.counts[2], greaterThan(b2));
    await c.close();
  });

  test('InfiniteQueriesController.handleRemount refetches each filter-set',
      () async {
    final c = RemountInfinite('ri');
    c.setFilters(['a', 'b']);
    await Future.delayed(const Duration(milliseconds: 60));
    final a = c.counts['a']!;
    final b = c.counts['b']!;

    c.handleRemount();
    await Future.delayed(const Duration(milliseconds: 60));

    expect(c.counts['a'], greaterThan(a));
    expect(c.counts['b'], greaterThan(b));
    await c.close();
  });
}
