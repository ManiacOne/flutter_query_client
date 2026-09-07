import 'package:flutter/material.dart';

/// A small info card describing which refetch trigger a scenario demonstrates
/// and what the user should do to see it fire.
class TriggerExplainer extends StatelessWidget {
  const TriggerExplainer({
    required this.trigger,
    required this.instruction,
    super.key,
  });

  /// The trigger name, e.g. "Navigator push → pop".
  final String trigger;

  /// What to do to observe it.
  final String instruction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trigger,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.primary)),
                const SizedBox(height: 3),
                Text(instruction,
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
