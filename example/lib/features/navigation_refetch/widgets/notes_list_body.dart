import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

import '../../../shared.dart';
import '../models/note.dart';
import 'fetch_stamp.dart';
import 'note_card.dart';

/// Presentational body for a notes query: a header with the live fetch stamp +
/// status badge, then the list. Reused by every scenario so each screen only
/// wires up its own controller/builder.
class NotesListBody extends StatelessWidget {
  const NotesListBody({required this.state, this.onTap, super.key});

  final QueryState<List<Note>> state;
  final void Function(Note note)? onTap;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isError && !state.hasData) {
      return Center(child: Text('Error: ${state.error}'));
    }
    final notes = state.data ?? const <Note>[];
    final seq = notes.isNotEmpty ? notes.first.fetchSeq : 0;
    final at = notes.isNotEmpty ? notes.first.fetchedAt : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              FetchStamp(fetchSeq: seq, at: at),
              const Spacer(),
              QueryStatusBadge(
                isPaused: state.isPaused,
                isRefetching: state.isRefetching,
                isStale: state.isStale,
                isSuccess: state.isSuccess,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: notes.length,
            itemBuilder: (_, i) => NoteCard(
              note: notes[i],
              onTap: onTap == null ? () {} : () => onTap!(notes[i]),
            ),
          ),
        ),
      ],
    );
  }
}
