/// A tiny domain model for the navigation-refetch demo.
///
/// [fetchSeq] and [fetchedAt] are stamped by [NotesRepository] on every read, so
/// the UI can *see* when a fresh fetch happened — that's how the demo proves the
/// list refetched after you navigated back to it.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.reviewed = false,
    this.fetchSeq = 0,
    this.fetchedAt,
  });

  final int id;
  final String title;
  final String body;
  final bool reviewed;

  /// Which repository fetch produced this snapshot (monotonic, app-wide).
  final int fetchSeq;

  /// When this snapshot was produced.
  final DateTime? fetchedAt;

  Note copyWith({
    String? title,
    String? body,
    bool? reviewed,
    int? fetchSeq,
    DateTime? fetchedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      reviewed: reviewed ?? this.reviewed,
      fetchSeq: fetchSeq ?? this.fetchSeq,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
