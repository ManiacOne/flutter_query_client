import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

import '../../../app_navigation.dart';
import '../controllers/notes_controllers.dart';
import '../widgets/trigger_explainer.dart';

/// Tab 3 root. Renders [GlobalStatsController], which is provided at the app
/// ROOT (see `main.dart`) — it never unmounts. Switching back to this tab still
/// refetches it, because the `QueryBuilder` here detects visibility, not the
/// root provider. That's the architecture point of 4.0.
class StatsTabScreen extends StatelessWidget {
  const StatsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Stats (global)'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Manual refetch()',
              onPressed: () => context.query<GlobalStatsController>().refetch(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const TriggerExplainer(
            trigger: 'Root-provided controller + manual refetch',
            instruction:
                'Switch away and back, or tap refresh. The global stats refetch '
                'though their provider is at the app root — the builder detects it.',
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: QueryBuilder<GlobalStatsController, String>(
                builder: (context, state) {
                  return Row(
                    children: [
                      const Icon(Icons.public, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.data ?? 'loading…',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (state.isRefetching)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (state.isSuccess)
                        const Icon(Icons.check_circle_outline,
                            color: Colors.green),
                    ],
                  );
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'The controller lives in main.dart\'s root MultiQueryProvider. '
              'Provider-level detection could never fire here (the root never '
              'becomes invisible); builder-level detection does.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
