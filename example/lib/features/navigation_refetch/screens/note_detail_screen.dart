import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:go_router/go_router.dart';

import '../../../shared.dart';
import '../controllers/notes_controllers.dart';
import '../models/note.dart';
import '../widgets/fetch_stamp.dart';

/// Nested detail page (level 2), pushed inside a branch so the bottom bar stays
/// visible. Popping it (back button) refetches the tab's list via
/// [QueryNavigatorObserver]. [commentsLocation], when provided, links to a third
/// nested level.
class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({
    required this.noteId,
    this.commentsLocation,
    super.key,
  });

  final int noteId;
  final String? commentsLocation;

  @override
  Widget build(BuildContext context) {
    return MultiQueryProvider(
      providers: [
        QueryProvider<NoteDetailController, Note>(
          create: (_) => NoteDetailController()..setParams(noteId),
        ),
        QueryProvider<ToggleReviewMutation, Note>(
          create: (_) => ToggleReviewMutation(),
        ),
      ],
      child: _NoteDetailView(commentsLocation: commentsLocation),
    );
  }
}

class _NoteDetailView extends StatelessWidget {
  const _NoteDetailView({this.commentsLocation});

  final String? commentsLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note detail')),
      body: QueryBuilder<NoteDetailController, Note>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final note = state.data;
          if (note == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  FetchStamp(fetchSeq: note.fetchSeq, at: note.fetchedAt),
                  const Spacer(),
                  QueryStatusBadge(
                    isPaused: state.isPaused,
                    isRefetching: state.isRefetching,
                    isStale: state.isStale,
                    isSuccess: state.isSuccess,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(note.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(note.body),
              const SizedBox(height: 24),
              _ReviewToggle(note: note),
              if (commentsLocation != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go(commentsLocation!),
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('View comments (3rd level) →'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReviewToggle extends StatelessWidget {
  const _ReviewToggle({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return QueryConsumer<ToggleReviewMutation, Note>(
      listenWhen: (_, next) => next.isSuccess,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content:
              Text(state.data!.reviewed ? 'Marked reviewed' : 'Marked unreviewed'),
          duration: const Duration(milliseconds: 1000),
        )),
      builder: (context, mutation) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MutationPhaseBar(
            isLoading: mutation.isLoading,
            isSuccess: mutation.isSuccess,
            isError: mutation.isError,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: mutation.isLoading
                ? null
                : () => context.query<ToggleReviewMutation>().mutate(
                      (id: note.id, reviewed: !note.reviewed),
                    ),
            icon: Icon(note.reviewed ? Icons.undo : Icons.verified),
            label:
                Text(note.reviewed ? 'Mark as unreviewed' : 'Mark as reviewed'),
          ),
        ],
      ),
    );
  }
}
