import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

import '../controllers/notes_controllers.dart';
import '../widgets/trigger_explainer.dart';

/// Third navigation level. Popping this refetches the detail (level 2); popping
/// that refetches the list (level 1) — refetch-on-visible at every depth.
class NoteCommentsScreen extends StatelessWidget {
  const NoteCommentsScreen({required this.noteId, super.key});

  final int noteId;

  @override
  Widget build(BuildContext context) {
    return QueryProvider<NoteCommentsController, List<String>>(
      create: (_) => NoteCommentsController()..setParams(noteId),
      child: Scaffold(
        appBar: AppBar(title: Text('Comments · note #$noteId')),
        body: Column(
          children: [
            const TriggerExplainer(
              trigger: 'Deep pop (level 3 → 2 → 1)',
              instruction:
                  'Pop back twice. The detail refetches, then the list refetches.',
            ),
            Expanded(
              child: QueryBuilder<NoteCommentsController, List<String>>(
                builder: (context, state) {
                  if (state.isLoading && !state.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = state.data ?? const <String>[];
                  return ListView(
                    children: [
                      for (final c in comments)
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(c),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
