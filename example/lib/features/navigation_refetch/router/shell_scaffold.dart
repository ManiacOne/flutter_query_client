import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent shell for the Navigation Refetch section: a bottom navigation
/// bar over the [StatefulNavigationShell]. The branches live in an
/// `IndexedStack`, so switching tabs keeps each tab's state (and controllers)
/// alive — a tab is never rebuilt from scratch when you return to it. Nested
/// pages (detail/comments) are pushed inside a branch and stay under this bar.
///
/// Each tab root carries the app `AppDrawer` (so you can switch example
/// sections); this shell owns only the bottom bar.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab again pops it back to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
