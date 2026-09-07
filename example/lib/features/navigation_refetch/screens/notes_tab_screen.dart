import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:go_router/go_router.dart';

import '../../../app_navigation.dart';
import '../controllers/notes_controllers.dart';
import '../models/note.dart';
import '../widgets/notes_list_body.dart';
import '../widgets/trigger_explainer.dart';

/// Tab 1 root. `refetchOnMount: always`, so it refetches when you switch back to
/// this tab (TickerMode) or pop back from the nested detail (QueryNavigatorObserver).
class NotesTabScreen extends StatelessWidget {
  const NotesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Notes')),
      body: QueryProvider<NotesAlwaysController, List<Note>>(
        create: (_) => NotesAlwaysController(),
        child: Column(
          children: [
            const TriggerExplainer(
              trigger: 'Tab switch + nested pop-back',
              instruction:
                  'Open a note (→ comments) and come back, or switch tabs and '
                  'return — the "fetch #" bumps each time.',
            ),
            Expanded(
              child: QueryConsumer<NotesAlwaysController, List<Note>>(
                listenWhen: (p, n) =>
                    p.isRefetching && !n.isRefetching && n.isSuccess,
                listener: (context, state) {
                  final seq = state.data?.isNotEmpty == true
                      ? state.data!.first.fetchSeq
                      : 0;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text('Notes refetched — fetch #$seq'),
                      duration: const Duration(milliseconds: 1000),
                    ));
                },
                builder: (context, state) => NotesListBody(
                  state: state,
                  onTap: (note) => context.go('/notes/detail/${note.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
