import 'package:flutter/material.dart';

/// A small pill showing which fetch produced the data on screen and when.
///
/// Watch this while you navigate: pop back from the detail screen and the
/// number bumps + the time updates — visible proof the list refetched on
/// becoming visible again.
class FetchStamp extends StatelessWidget {
  const FetchStamp({required this.fetchSeq, required this.at, super.key});

  final int fetchSeq;
  final DateTime? at;

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 13, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            at == null ? 'fetch #$fetchSeq' : 'fetch #$fetchSeq · ${_time(at!)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
