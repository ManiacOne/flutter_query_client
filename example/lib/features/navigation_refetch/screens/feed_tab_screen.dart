import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:go_router/go_router.dart';

import '../../../app_navigation.dart';
import '../controllers/notes_controllers.dart';
import '../models/note.dart';
import '../widgets/notes_list_body.dart';
import '../widgets/trigger_explainer.dart';

/// Tab 2 root. `refetchInterval: 3s` — polls on its own while visible, pauses
/// when the tab is backgrounded (TickerMode off), and resumes on return.
class FeedTabScreen extends StatelessWidget {
  const FeedTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Feed (polling)')),
      body: QueryProvider<NotesIntervalController, List<Note>>(
        create: (_) => NotesIntervalController(),
        child: Column(
          children: [
            const TriggerExplainer(
              trigger: 'refetchInterval: 3s',
              instruction:
                  'The list refreshes by itself every 3s. Switch to another tab '
                  'and back — polling paused while away, then resumes.',
            ),
            Expanded(
              child: QueryBuilder<NotesIntervalController, List<Note>>(
                builder: (context, state) => NotesListBody(
                  state: state,
                  onTap: (note) => context.go('/feed/detail/${note.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
