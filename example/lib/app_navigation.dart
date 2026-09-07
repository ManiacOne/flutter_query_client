import 'package:flutter/material.dart';

import 'features/cache_playground/cache_playground_screen.dart';
import 'features/inefficiency_demos/inefficiency_demos_screen.dart';
import 'features/infinite_queries/infinite_queries_screen.dart';
import 'features/navigation_refetch/navigation_refetch_app.dart';
import 'features/posts/posts_list_screen.dart';
import 'features/products/products_paginated_screen.dart';
import 'features/showcase/widgets_showcase_screen.dart';

/// Which drawer section is currently shown. A tiny app-wide notifier so any
/// screen's [AppDrawer] can switch sections without threading callbacks.
final ValueNotifier<int> selectedSection = ValueNotifier<int>(0);

class AppSection {
  const AppSection(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

final List<AppSection> appSections = [
  AppSection('Posts', Icons.article_outlined, (_) => const PostsListScreen()),
  AppSection('Products', Icons.storefront_outlined,
      (_) => const ProductsPaginatedScreen()),
  AppSection('Infinite Queries', Icons.dynamic_feed_outlined,
      (_) => const InfiniteQueriesScreen()),
  AppSection('Navigation Refetch', Icons.route_outlined,
      (_) => const NavigationRefetchApp()),
  AppSection('Cache Lab', Icons.science_outlined,
      (_) => const CachePlaygroundScreen()),
  AppSection('Widgets', Icons.widgets_outlined,
      (_) => const WidgetsShowcaseScreen()),
  AppSection('Issues', Icons.bug_report_outlined,
      (_) => const InefficiencyDemosScreen()),
];

/// Shared navigation drawer used by every section's `Scaffold`.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: selectedSection,
          builder: (context, current, _) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('flutter_query_client',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Examples',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (var i = 0; i < appSections.length; i++)
                  ListTile(
                    leading: Icon(appSections[i].icon),
                    title: Text(appSections[i].label),
                    selected: current == i,
                    onTap: () {
                      selectedSection.value = i;
                      Navigator.pop(context);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
