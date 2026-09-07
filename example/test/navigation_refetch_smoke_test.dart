import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:query_client_example/features/navigation_refetch/controllers/notes_controllers.dart';
import 'package:query_client_example/features/navigation_refetch/navigation_refetch_app.dart';

/// Boot smoke test for the GoRouter section: nested `MaterialApp.router` +
/// `StatefulShellRoute` mounts without throwing, shows the bottom nav and the
/// initial Notes tab.
void main() {
  setUp(() {
    NetworkConnectivityObserver.testMode = true;
    QueryClient.instance.clear();
    QueryClient.instance.setDefaults(const QueryDefaults());
  });

  testWidgets('Navigation Refetch section boots with bottom nav + Notes tab',
      (tester) async {
    await tester.pumpWidget(
      QueryClientProvider(
        client: QueryClient.instance,
        // The global controller is provided at the root in the real app; supply
        // it here because the Stats branch is built eagerly by the IndexedStack.
        child: QueryProvider<GlobalStatsController, String>(
          create: (_) => GlobalStatsController(),
          child: const NavigationRefetchApp(),
        ),
      ),
    );

    // A few bounded pumps (the Feed tab polls on a 3s interval, so we can't
    // pumpAndSettle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget); // bottom-nav destination label
    expect(find.text('Stats'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Notes'), findsOneWidget); // initial tab

    // Unmount (closes controllers → cancels interval timers) and clear the
    // client (cancels stale-time timers) so no timers are pending at teardown.
    await tester.pumpWidget(const SizedBox());
    QueryClient.instance.clear();
  });
}
