import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// FeatureBanner
// Horizontally scrollable row of chips that document the package
// features active on the current screen. Helps developers understand
// what they are looking at without reading source code.
// ═══════════════════════════════════════════════════════════════════

class FeatureBanner extends StatelessWidget {
  final List<FeatureItem> features;
  const FeatureBanner({required this.features, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: features
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FeatureChip(f),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class FeatureItem {
  final IconData icon;
  final String label;
  final Color color;
  const FeatureItem(this.icon, this.label, this.color);
}

class _FeatureChip extends StatelessWidget {
  final FeatureItem item;
  const _FeatureChip(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 12, color: item.color),
          const SizedBox(width: 5),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              color: item.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// QueryStatusBadge
// Compact badge showing the live fetch status of a query controller.
// Renders nothing during initial loading (spinner handles that).
// ═══════════════════════════════════════════════════════════════════

class QueryStatusBadge extends StatelessWidget {
  final bool isPaused;
  final bool isRefetching;
  final bool isStale;
  final bool isSuccess;

  const QueryStatusBadge({
    required this.isPaused,
    required this.isRefetching,
    required this.isStale,
    required this.isSuccess,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color color;
    IconData? icon;
    String label;
    bool spinning;

    if (isPaused) {
      color = Colors.orange;
      icon = Icons.wifi_off;
      label = 'Paused';
      spinning = false;
    } else if (isRefetching) {
      color = cs.primary;
      icon = null;
      label = 'Refetching';
      spinning = true;
    } else if (isStale) {
      color = Colors.amber;
      icon = Icons.timelapse;
      label = 'Stale';
      spinning = false;
    } else if (isSuccess) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      label = 'Fresh';
      spinning = false;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinning)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MutationPhaseBar
// Visualises the lifecycle of a MutationController in real-time.
// Shows which controller hook (onSuccess / onMutationError / onSettled)
// was called after the mutation completes.
// ═══════════════════════════════════════════════════════════════════

class MutationPhaseBar extends StatelessWidget {
  final bool isLoading;
  final bool isSuccess;
  final bool isError;

  const MutationPhaseBar({
    required this.isLoading,
    required this.isSuccess,
    required this.isError,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color color;
    IconData? icon;
    String phase;
    String detail;

    if (isLoading) {
      color = Colors.amber;
      icon = null;
      phase = 'Submitting…';
      detail = 'mutate() called — awaiting server response';
    } else if (isSuccess) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      phase = 'Success';
      detail = 'onSuccess(data)  •  onSettled(data, null)  ← fired in controller';
    } else if (isError) {
      color = cs.error;
      icon = Icons.error_outline;
      phase = 'Error';
      detail = 'onMutationError(error)  •  onSettled(null, error)  ← fired in controller';
    } else {
      color = cs.onSurface.withValues(alpha: 0.35);
      icon = Icons.radio_button_unchecked;
      phase = 'Idle';
      detail = 'Waiting for mutate() to be called';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
