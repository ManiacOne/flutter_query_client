import 'package:flutter/material.dart';

import '../models/note.dart';

/// A single note row in the list. Presentational only — tapping is delegated to
/// [onTap] so the screen owns navigation.
class NoteCard extends StatelessWidget {
  const NoteCard({required this.note, required this.onTap, super.key});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Text('${note.id}'),
        ),
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          note.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: note.reviewed
            ? const Icon(Icons.verified, color: Colors.green, size: 20)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
