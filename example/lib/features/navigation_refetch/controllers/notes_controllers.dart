import 'package:flutter_query_client/flutter_query_client.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';

// ─── Tab 1 "Notes": refetchOnMount always ─────────────────────────

/// `refetchOnMount: always` — refetches every time the Notes tab becomes visible
/// again (tab switch via TickerMode, or popping back from a nested page).
class NotesAlwaysController extends QueryController<List<Note>, void> {
  NotesAlwaysController() : super('nav-notes-always');
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.stale;
  @override
  Duration? get staleTime => const Duration(seconds: 10);
  @override
  Future<List<Note>> queryFn(void _) => NotesRepository.instance.fetchNotes();
}

// ─── Tab 2 "Feed": interval polling ────────────────────────────────

/// Polls every 3s (and also refetches on re-visit).
class NotesIntervalController extends QueryController<List<Note>, void> {
  NotesIntervalController() : super('nav-notes-interval');
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;
  @override
  Duration? get refetchInterval => const Duration(seconds: 3);
  @override
  Future<List<Note>> queryFn(void _) => NotesRepository.instance.fetchNotes();
}

// ─── Detail + comments (nested inside a tab) ───────────────────────

class NoteDetailController extends QueryController<Note, int> {
  NoteDetailController() : super('nav-note');
  @override
  int get retryCount => 1;
  @override
  Future<Note> queryFn(int? id) => NotesRepository.instance.fetchNote(id!);
}

class NoteCommentsController extends QueryController<List<String>, int> {
  NoteCommentsController() : super('nav-note-comments');
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;
  @override
  Future<List<String>> queryFn(int? id) =>
      NotesRepository.instance.fetchComments(id!);
}

// ─── Tab 3 "Stats": a GLOBAL controller (provided at app root) ─────

/// Provided once in `main.dart`'s root `MultiQueryProvider`, so it never
/// unmounts and has no screen route of its own. The Stats tab still refetches it
/// on re-visit — because the builder there detects visibility, not the provider.
class GlobalStatsController extends QueryController<String, void> {
  GlobalStatsController() : super('nav-global-stats');
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;
  @override
  Future<String> queryFn(void _) async {
    final notes = await NotesRepository.instance.fetchNotes();
    return '${notes.length} notes · ${NotesRepository.instance.reviewedCount} '
        'reviewed · fetch #${NotesRepository.instance.fetchSeq}';
  }
}

// ─── Mutation: toggle "reviewed" and invalidate the lists ──────────

typedef ToggleReviewParams = ({int id, bool reviewed});

class ToggleReviewMutation
    extends MutationController<Note, ToggleReviewParams> {
  @override
  Future<Note> mutationFn(ToggleReviewParams params) =>
      NotesRepository.instance.setReviewed(params.id, params.reviewed);

  @override
  void onSuccess(Note data) {
    // Update the detail cache immediately, then invalidate the lists so any
    // mounted tab refetches — even while it's covered by this detail page.
    QueryClient.instance.set<Note>(
      'nav-note',
      serializeParams(data.id),
      CachedQueryData<Note>(data: data, fetchTime: DateTime.now()),
    );
    QueryClient.instance.invalidateQueries(const [
      'nav-notes-always',
      'nav-notes-interval',
      'nav-global-stats',
    ]);
  }
}
