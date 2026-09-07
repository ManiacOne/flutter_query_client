import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:go_router/go_router.dart';

import 'router/shell_scaffold.dart';
import 'screens/feed_tab_screen.dart';
import 'screens/note_comments_screen.dart';
import 'screens/note_detail_screen.dart';
import 'screens/notes_tab_screen.dart';
import 'screens/stats_tab_screen.dart';

/// The "Navigation Refetch" drawer section — a self-contained GoRouter app with
/// a bottom navigation bar and three `StatefulShellBranch` tabs (kept alive via
/// `indexedStack`, so a tab never remounts when you switch away and back).
///
/// Both refetch-on-visible signals are exercised here:
///  • **Tab switch** flips the inactive branch's `TickerMode` → on return the
///    tab's `QueryBuilder` refetches (per its `refetchOnMount`).
///  • **Nested push/pop** inside a branch is observed by
///    [QueryNavigatorObserver] (added to each branch's `observers`) → popping
///    back to a list refetches it.
class NavigationRefetchApp extends StatefulWidget {
  const NavigationRefetchApp({super.key});

  @override
  State<NavigationRefetchApp> createState() => _NavigationRefetchAppState();
}

class _NavigationRefetchAppState extends State<NavigationRefetchApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/notes',
    // One observer PER navigator (a NavigatorObserver belongs to a single
    // Navigator). They all feed the shared RemountRegistry, so a fresh instance
    // per branch is correct — not the shared singleton.
    observers: [QueryNavigatorObserver()],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          // ── Tab 1: Notes (list → detail → comments) ──
          StatefulShellBranch(
            observers: [QueryNavigatorObserver()],
            routes: [
              GoRoute(
                path: '/notes',
                builder: (_, __) => const NotesTabScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (_, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return NoteDetailScreen(
                        noteId: id,
                        commentsLocation: '/notes/detail/$id/comments',
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'comments',
                        builder: (_, state) => NoteCommentsScreen(
                          noteId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // ── Tab 2: Feed (interval polling list → detail) ──
          StatefulShellBranch(
            observers: [QueryNavigatorObserver()],
            routes: [
              GoRoute(
                path: '/feed',
                builder: (_, __) => const FeedTabScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (_, state) => NoteDetailScreen(
                      noteId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ── Tab 3: Stats (root-provided global controller) ──
          StatefulShellBranch(
            observers: [QueryNavigatorObserver()],
            routes: [
              GoRoute(path: '/stats', builder: (_, __) => const StatsTabScreen()),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nested router app for this section. Inherits the outer theme and stays
    // below the root QueryClientProvider, so global controllers still resolve.
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      routerConfig: _router,
    );
  }
}
