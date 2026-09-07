import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the "dashboard shows stale top item" report:
///   • a dashboard screen mounts controller instance D (key 'shared-list'),
///     rendered via a QueryBuilder, and shows data.first;
///   • we navigate to a list screen that mounts a SEPARATE instance L of the
///     SAME controller class / SAME key, which refetches newer data;
///   • we pop back to the dashboard.
///
/// Expectation (pure cache propagation, no refetch on the dashboard): the
/// dashboard reflects L's fresh data via the cache-change subscription — even
/// though D never refetched (refetchOnMount: never) and no navigator observer is
/// installed.
List<String> serverData = ['old'];

class SharedListController extends QueryController<List<String>, void> {
  final RefetchOnMount _rom;
  int fetchCount = 0;
  SharedListController({RefetchOnMount rom = RefetchOnMount.never})
      : _rom = rom,
        super('shared-list');

  @override
  RefetchOnMount get refetchOnMount => _rom;
  @override
  int get retryCount => 1;
  @override
  Future<List<String>> queryFn(void _) async {
    fetchCount++;
    return List<String>.of(serverData);
  }
}

void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
    serverData = ['old'];
  });

  testWidgets(
      'dashboard (instance D) reflects list (instance L) refetch via cache — '
      'no refetch on D, no navigator observer', (tester) async {
    // Dashboard: instance D, refetchOnMount: never, rendered via QueryBuilder.
    final dashboard = SharedListController(rom: RefetchOnMount.never);
    late BuildContext dashCtx;

    await tester.pumpWidget(
      MaterialApp(
        home: QueryProvider<SharedListController, List<String>>(
          create: (_) => dashboard,
          child: Builder(builder: (ctx) {
            dashCtx = ctx;
            return Scaffold(
              body: QueryBuilder<SharedListController, List<String>>(
                builder: (_, s) => Text('top: ${s.data?.first ?? "-"}'),
              ),
            );
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('top: old'), findsOneWidget);

    // The "server" now returns newer data.
    serverData = ['new'];

    // Navigate to the list screen: a SEPARATE instance L of the same key that
    // refetches (refetchOnMount: always) → writes 'new' to the shared cache.
    Navigator.of(dashCtx).push(
      MaterialPageRoute<void>(
        builder: (_) => QueryProvider<SharedListController, List<String>>(
          create: (_) => SharedListController(rom: RefetchOnMount.always),
          child: Scaffold(
            body: QueryBuilder<SharedListController, List<String>>(
              builder: (_, s) => Text('list: ${s.data?.join(",") ?? "-"}'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('list: new'), findsOneWidget);

    // Pop back to the dashboard.
    Navigator.of(dashCtx).pop();
    await tester.pumpAndSettle();

    // Dashboard should now show the refreshed top item, propagated via cache.
    expect(find.text('top: new'), findsOneWidget,
        reason: 'dashboard should reflect the shared-cache update');
    expect(dashboard.fetchCount, 1,
        reason: 'dashboard itself never refetched — pure cache propagation');
  });
}
