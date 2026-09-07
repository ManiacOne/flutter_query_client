import '../models/note.dart';

/// A fake in-memory backend for the navigation-refetch demos — no HTTP, fully
/// deterministic, so the examples stay simple and run offline.
///
/// Every read bumps a global fetch sequence and stamps the returned notes with
/// it, which is what lets each screen show "fetch #N at HH:MM:SS" and makes the
/// refetch-on-visible behaviour visible.
class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  int _fetchSeq = 0;

  /// Total reads so far — surfaced by the "global controller" scenario.
  int get fetchSeq => _fetchSeq;

  final Map<int, Note> _db = {
    for (var i = 1; i <= 8; i++)
      i: Note(
        id: i,
        title: 'Note #$i',
        body: 'Body of note $i. Navigate into it and pop back — the previous '
            'screen refetches automatically (QueryNavigatorObserver).',
      ),
  };

  int get reviewedCount => _db.values.where((n) => n.reviewed).length;

  /// Simulated latency so loading/refetching states are observable.
  static const _latency = Duration(milliseconds: 500);

  Future<List<Note>> fetchNotes() async {
    await Future<void>.delayed(_latency);
    _fetchSeq++;
    final now = DateTime.now();
    return _db.values
        .map((n) => n.copyWith(fetchSeq: _fetchSeq, fetchedAt: now))
        .toList();
  }

  Future<Note> fetchNote(int id) async {
    await Future<void>.delayed(_latency);
    _fetchSeq++;
    return _db[id]!.copyWith(fetchSeq: _fetchSeq, fetchedAt: DateTime.now());
  }

  /// Third navigation level (list → detail → comments) for the deep push/pop
  /// demo.
  Future<List<String>> fetchComments(int id) async {
    await Future<void>.delayed(_latency);
    _fetchSeq++;
    return List.generate(3, (i) => 'Comment ${i + 1} on note #$id (fetch #$_fetchSeq)');
  }

  Future<Note> setReviewed(int id, bool reviewed) async {
    await Future<void>.delayed(_latency);
    _db[id] = _db[id]!.copyWith(reviewed: reviewed);
    return _db[id]!;
  }
}
