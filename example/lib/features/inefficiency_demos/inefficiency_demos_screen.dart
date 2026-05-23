import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

// ═══════════════════════════════════════════════════════════════════════
// Before/After demos for flutter_query_client 2.0.0 optimizations.
//
// Each card runs BEFORE (v1.2.0 behavior, simulated) vs AFTER (v2.0.0,
// actual fixed code), shows visual metrics, then reveals detailed
// documentation explaining what changed, why, and the Dart API
// differences.
// ═══════════════════════════════════════════════════════════════════════

class InefficiencyDemosScreen extends StatelessWidget {
  const InefficiencyDemosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('v2.0.0 Optimizations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader(title: 'CRITICAL: Memory Leak Fixes', color: Colors.red),
          SizedBox(height: 8),
          _Issue1Demo(),
          SizedBox(height: 16),
          _Issue2Demo(),
          SizedBox(height: 16),
          _Issue3Demo(),
          SizedBox(height: 32),
          _SectionHeader(title: 'MEDIUM: Performance Fixes', color: Colors.orange),
          SizedBox(height: 8),
          _Issue4Demo(),
          SizedBox(height: 16),
          _Issue5Demo(),
          SizedBox(height: 16),
          _Issue6Demo(),
          SizedBox(height: 16),
          _Issue7Demo(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final String issueNumber;
  final String title;
  final String subtitle;
  final Color severity;
  final Widget child;

  const _IssueCard({
    required this.issueNumber,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: severity.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#$issueNumber',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: severity,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final String value;
  final double fill;
  final Color color;

  const _MetricBar({
    required this.label,
    required this.value,
    required this.fill,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface)),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fill.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final int leftUs;
  final String rightLabel;
  final String rightValue;
  final int rightUs;

  const _ComparisonRow({
    required this.leftLabel,
    required this.leftValue,
    required this.leftUs,
    required this.rightLabel,
    required this.rightValue,
    required this.rightUs,
  });

  @override
  Widget build(BuildContext context) {
    final maxUs = (leftUs > rightUs ? leftUs : rightUs).toDouble();
    return Row(
      children: [
        Expanded(
          child: _MetricBar(
            label: leftLabel,
            value: leftValue,
            fill: maxUs > 0 ? leftUs / maxUs : 0,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricBar(
            label: rightLabel,
            value: rightValue,
            fill: maxUs > 0 ? rightUs / maxUs : 0,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

// Detailed documentation for all optimizations is in OPTIMIZATIONS.md
// in this same directory.

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #1: StreamController Leak in NetworkConnectivityObserver
// ═══════════════════════════════════════════════════════════════════════

class _Issue1Demo extends StatefulWidget {
  const _Issue1Demo();
  @override
  State<_Issue1Demo> createState() => _Issue1DemoState();
}

class _Issue1DemoState extends State<_Issue1Demo> {
  final _leakedSubs = <StreamSubscription<bool>>[];
  int _navigations = 0;

  void _simulate() {
    final observer = NetworkConnectivityObserver.instance;
    final sub = observer.onStatusChange.listen((_) {});
    _leakedSubs.add(sub);
    setState(() => _navigations++);
  }

  void _cleanup() {
    for (final s in _leakedSubs) {
      s.cancel();
    }
    setState(() {
      _leakedSubs.clear();
      _navigations = 0;
    });
  }

  @override
  void dispose() {
    for (final s in _leakedSubs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final observer = NetworkConnectivityObserver.instance;
    final tracked = observer.listenerCount;
    final leaked = _leakedSubs.length;
    return _IssueCard(
      issueNumber: '1',
      title: 'StreamController Listener Leak',
      subtitle: 'v1.2.0: Broadcast StreamController created eagerly, never '
          'closed. No way to know how many listeners are attached.',
      severity: Colors.red,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '$_navigations',
                  label: 'Navigations\nSimulated',
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _StatTile(
                  value: '$leaked',
                  label: 'Uncancelled\nListeners',
                  color: leaked == 0 ? Colors.green : Colors.red,
                ),
              ),
              Expanded(
                child: _StatTile(
                  value: '$tracked',
                  label: 'v2.0.0\nlistenerCount',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MetricBar(
            label: 'BEFORE: No visibility (leaked listeners invisible)',
            value: '$leaked leaked',
            fill: leaked / 15,
            color: Colors.red,
          ),
          _MetricBar(
            label: 'AFTER: listenerCount tracks via onListen/onCancel',
            value: '$tracked tracked',
            fill: tracked / 15,
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _simulate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Listener'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: leaked == 0 ? null : _cleanup,
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Cleanup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #2: QueryClient Singleton Timer Leak
// ═══════════════════════════════════════════════════════════════════════

class _Issue2Demo extends StatefulWidget {
  const _Issue2Demo();
  @override
  State<_Issue2Demo> createState() => _Issue2DemoState();
}

class _Issue2DemoState extends State<_Issue2Demo> {
  int _entriesCreated = 0;
  void _createEntries() {
    final client = QueryClient.instance;
    for (var i = 0; i < 10; i++) {
      client.set(
        'diag-demo-$_entriesCreated',
        null,
        CachedQueryData(
          data: 'value-$_entriesCreated',
          fetchTime: DateTime.now(),
          staleTime: const Duration(minutes: 30),
          gcTime: const Duration(minutes: 60),
        ),
      );
      _entriesCreated++;
    }
    setState(() {});
  }

  void _cleanup() {
    final client = QueryClient.instance;
    for (var i = 0; i < _entriesCreated; i++) {
      client.invalidate('diag-demo-$i');
    }
    setState(() => _entriesCreated = 0);
  }

  @override
  void dispose() {
    final client = QueryClient.instance;
    for (var i = 0; i < _entriesCreated; i++) {
      client.invalidate('diag-demo-$i');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = QueryClient.instance;
    final staleTimers = client.activeStaleTimerCount;
    final gcTimers = client.activeGcTimerCount;
    final cacheCount = client.cacheEntryCount;
    return _IssueCard(
      issueNumber: '2',
      title: 'Singleton Timer Leak (Now Diagnosable)',
      subtitle: 'v1.2.0: No way to inspect how many timers or cache entries '
          'exist. v2.0.0: Diagnostic getters expose everything.',
      severity: Colors.red,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(value: '$cacheCount', label: 'Cache\nEntries', color: Colors.blue)),
              Expanded(child: _StatTile(value: '$staleTimers', label: 'Stale\nTimers', color: staleTimers == 0 ? Colors.green : Colors.orange)),
              Expanded(child: _StatTile(value: '$gcTimers', label: 'GC\nTimers', color: gcTimers == 0 ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          _MetricBar(
            label: 'BEFORE: Timers hidden inside private maps',
            value: 'invisible',
            fill: _entriesCreated > 0 ? 1.0 : 0.0,
            color: Colors.red,
          ),
          _MetricBar(
            label: 'AFTER: activeStaleTimerCount / activeGcTimerCount',
            value: '$staleTimers / $gcTimers',
            fill: (staleTimers + gcTimers) / 40,
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createEntries,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+10 Entries'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _entriesCreated == 0 ? null : _cleanup,
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Cleanup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #3: Dangling Callback References
// ═══════════════════════════════════════════════════════════════════════

class _LeakyController extends QueryController<String, void> {
  _LeakyController(int id) : super('leaky-ctrl-$id');

  @override
  Future<String> queryFn(void params) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 'data';
  }
}

class _Issue3Demo extends StatefulWidget {
  const _Issue3Demo();
  @override
  State<_Issue3Demo> createState() => _Issue3DemoState();
}

class _Issue3DemoState extends State<_Issue3Demo> {
  final _abandoned = <_LeakyController>[];
  int _created = 0;
  int _closed = 0;
  bool _showDoc = false;

  void _createAndAbandon() {
    for (var i = 0; i < 3; i++) {
      _abandoned.add(_LeakyController(_created + i));
    }
    setState(() {
      _created += 3;
      _showDoc = true;
    });
  }

  void _cleanup() {
    final count = _abandoned.length;
    for (final c in _abandoned) {
      c.close();
    }
    _abandoned.clear();
    setState(() {
      _closed += count;
    });
  }

  void _fullReset() {
    _cleanup();
    setState(() {
      _created = 0;
      _closed = 0;
      _showDoc = false;
    });
  }

  @override
  void dispose() {
    for (final c in _abandoned) {
      c.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = QueryClient.instance;
    final dangling = _abandoned.length;
    final invalidateCbs = client.activeInvalidateCallbackCount;
    final reconnectCbs = client.activeReconnectCallbackCount;
    return _IssueCard(
      issueNumber: '3',
      title: 'Dangling Callbacks (Auto-Pruned)',
      subtitle: 'v1.2.0: Abandoned callbacks lived forever. '
          'v2.0.0: try-catch auto-prunes stale callbacks on next invocation.',
      severity: Colors.red,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(value: '$_created', label: 'Created', color: Colors.blue)),
              Expanded(child: _StatTile(value: '$dangling', label: 'Dangling', color: dangling == 0 ? Colors.green : Colors.red)),
              Expanded(child: _StatTile(value: '$_closed', label: 'Closed', color: Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          _MetricBar(
            label: 'Invalidate callbacks in QueryClient',
            value: '$invalidateCbs',
            fill: invalidateCbs / 20,
            color: invalidateCbs == 0 ? Colors.green : Colors.orange,
          ),
          _MetricBar(
            label: 'Reconnect callbacks in QueryClient',
            value: '$reconnectCbs',
            fill: reconnectCbs / 20,
            color: reconnectCbs == 0 ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createAndAbandon,
                  icon: const Icon(Icons.leak_add, size: 16),
                  label: const Text('+3 Abandoned'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: dangling == 0 ? null : _cleanup,
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('close() All'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showDoc ? _fullReset : null,
                icon: const Icon(Icons.restart_alt, size: 20),
                tooltip: 'Full Reset',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #4: Deep Copy on Every Cache Save
// ═══════════════════════════════════════════════════════════════════════

class _Issue4Demo extends StatefulWidget {
  const _Issue4Demo();
  @override
  State<_Issue4Demo> createState() => _Issue4DemoState();
}

class _CopyResult {
  final String label;
  final int beforeUs;
  final int afterUs;
  const _CopyResult({required this.label, required this.beforeUs, required this.afterUs});
}

class _Issue4DemoState extends State<_Issue4Demo> {
  final _results = <_CopyResult>[];
  bool _running = false;
  bool _showDoc = false;

  void _prevent(Object o) {
    if (o.hashCode == -999999) throw Error();
  }

  Future<void> _run() async {
    setState(() { _results.clear(); _running = true; });

    for (final c in [
      (pages: 3, perPage: 20, label: 'Small: 3 pages x 20'),
      (pages: 5, perPage: 50, label: 'Medium: 5 pages x 50'),
      (pages: 10, perPage: 100, label: 'Large: 10 pages x 100'),
      (pages: 50, perPage: 10000, label: 'Huge: 20 pages x 10000'),
    ]) {
      await Future.delayed(const Duration(milliseconds: 30));
      final pages = List.generate(c.pages, (i) => List.generate(c.perPage, (j) => 'item_${i}_$j'));

      // BEFORE: List.from() deep copy
      final sw1 = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        final r = pages.map((p) => List<String>.from(p)).toList();
        _prevent(r);
      }
      sw1.stop();

      // AFTER: UnmodifiableListView — true O(1) wrapper
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        final r = pages.map((p) => UnmodifiableListView<String>(p)).toList();
        _prevent(r);
      }
      sw2.stop();

      setState(() {
        _results.add(_CopyResult(label: c.label, beforeUs: sw1.elapsedMicroseconds ~/ 500, afterUs: sw2.elapsedMicroseconds ~/ 500));
      });
    }
    setState(() { _running = false; _showDoc = true; });
  }

  void _cleanup() {
    setState(() { _results.clear(); _showDoc = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _IssueCard(
      issueNumber: '4',
      title: 'Deep Copy vs UnmodifiableListView',
      subtitle: 'v1.2.0: List.from() copies every element. '
          'v2.0.0: UnmodifiableListView wraps without copying.',
      severity: Colors.orange,
      child: Column(
        children: [
          if (_results.isEmpty && !_running)
            Container(
              height: 80,
              alignment: Alignment.center,
              child: Text(
                'Benchmarks _saveToCache with 4 dataset sizes (500 iterations each)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          for (final r in _results) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '${r.label} = ${(r.label.split('x').last.trim())} items total',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            _ComparisonRow(
              leftLabel: 'List.from() copy',
              leftValue: '${r.beforeUs} us',
              leftUs: r.beforeUs,
              rightLabel: 'UnmodifiableListView',
              rightValue: '${r.afterUs} us',
              rightUs: r.afterUs,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(r.beforeUs / (r.afterUs == 0 ? 1 : r.afterUs)).toStringAsFixed(1)}x faster',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.withValues(alpha: 0.9)),
              ),
            ),
          ],
          if (_running)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.speed, size: 16),
                  label: const Text('Run Benchmark'),
                ),
              ),
              if (_showDoc) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _cleanup,
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Cleanup'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #5: Flat Cache Thrashing on Optimistic Updates
// ═══════════════════════════════════════════════════════════════════════

class _Issue5Demo extends StatefulWidget {
  const _Issue5Demo();
  @override
  State<_Issue5Demo> createState() => _Issue5DemoState();
}

class _Issue5DemoState extends State<_Issue5Demo> {
  int _totalItems = 0;
  int _updates = 0;
  int _beforeRebuilds = 0;
  int _afterRebuilds = 0;
  int _beforeUs = 0;
  int _afterUs = 0;
  bool _ran = false;

  Future<void> _run() async {
    const pageCount = 5;
    const perPage = 200;
    _totalItems = pageCount * perPage;
    _updates = 50;

    final pages = List.generate(pageCount, (i) => List.generate(perPage, (j) => 'item_${i}_$j'));

    // BEFORE: null _flatCache + rebuild on each update
    List<String>? flatCacheBefore;
    int rebuildsBefore = 0;

    List<String> getFlatBefore() {
      if (flatCacheBefore == null) {
        rebuildsBefore++;
        flatCacheBefore = pages.expand((p) => p).toList();
      }
      return flatCacheBefore!;
    }

    getFlatBefore(); // initial build
    rebuildsBefore = 0;

    await Future.delayed(const Duration(milliseconds: 30));

    final sw1 = Stopwatch()..start();
    for (var i = 0; i < _updates; i++) {
      pages[i % pageCount][i % perPage] = 'updated_$i';
      flatCacheBefore = null; // _invalidateFlat()
      getFlatBefore(); // read in emit
    }
    sw1.stop();

    // AFTER: in-place patch (what v2.0.0 updateItem does)
    final pages2 = List.generate(pageCount, (i) => List.generate(perPage, (j) => 'item_${i}_$j'));
    List<String>? flatCacheAfter = pages2.expand((p) => p).toList();
    int rebuildsAfter = 0;

    int flatIndexOf(int pageIdx, int itemIdx) {
      var offset = 0;
      for (var i = 0; i < pageIdx; i++) {
        offset += pages2[i].length;
      }
      return offset + itemIdx;
    }

    List<String> getFlatAfter() {
      if (flatCacheAfter == null) {
        rebuildsAfter++;
        flatCacheAfter = pages2.expand((p) => p).toList();
      }
      return flatCacheAfter!;
    }

    final sw2 = Stopwatch()..start();
    for (var i = 0; i < _updates; i++) {
      final pi = i % pageCount;
      final ii = i % perPage;
      pages2[pi][ii] = 'updated_$i';
      // In-place patch instead of invalidate
      final fi = flatIndexOf(pi, ii);
      if (flatCacheAfter != null) flatCacheAfter![fi] = 'updated_$i';
      getFlatAfter(); // read in emit — no rebuild needed
    }
    sw2.stop();

    setState(() {
      _beforeRebuilds = rebuildsBefore;
      _afterRebuilds = rebuildsAfter;
      _beforeUs = sw1.elapsedMicroseconds;
      _afterUs = sw2.elapsedMicroseconds;
      _ran = true;
    });
  }

  void _cleanup() {
    setState(() {
      _ran = false;
      _beforeRebuilds = 0;
      _afterRebuilds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _IssueCard(
      issueNumber: '5',
      title: 'Flat Cache Thrashing vs In-Place Patch',
      subtitle: 'v1.2.0: Every mutation nulls + rebuilds the entire flat list. '
          'v2.0.0: Patches the flat cache in-place at O(1).',
      severity: Colors.orange,
      child: Column(
        children: [
          if (_ran) ...[
            Row(
              children: [
                Expanded(child: _StatTile(value: '$_totalItems', label: 'Total\nItems', color: Colors.blue)),
                Expanded(child: _StatTile(value: '$_updates', label: 'Optimistic\nUpdates', color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _StatTile(value: '$_beforeRebuilds', label: 'BEFORE\nRebuilds', color: Colors.red)),
                Expanded(child: _StatTile(value: '$_afterRebuilds', label: 'AFTER\nRebuilds', color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            _ComparisonRow(
              leftLabel: 'BEFORE: null + rebuild',
              leftValue: '$_beforeUs us',
              leftUs: _beforeUs,
              rightLabel: 'AFTER: in-place patch',
              rightValue: '$_afterUs us',
              rightUs: _afterUs,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${(_beforeUs / (_afterUs == 0 ? 1 : _afterUs)).toStringAsFixed(1)}x faster  |  $_beforeRebuilds -> $_afterRebuilds full rebuilds eliminated',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.withValues(alpha: 0.9)),
              ),
            ),
          ] else
            Container(
              height: 80,
              alignment: Alignment.center,
              child: Text(
                '50 optimistic updates on 1,000 items (5 pages x 200)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.speed, size: 16),
                  label: const Text('Run Benchmark'),
                ),
              ),
              if (_ran) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _cleanup,
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Cleanup'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #6: Redundant Stale Listener Re-Registration
// ═══════════════════════════════════════════════════════════════════════

class _Issue6Demo extends StatefulWidget {
  const _Issue6Demo();
  @override
  State<_Issue6Demo> createState() => _Issue6DemoState();
}

class _Issue6DemoState extends State<_Issue6Demo> {
  int _fetches = 0;
  int _beforeCalls = 0;
  int _afterCalls = 0;
  int _paramsChanges = 0;
  bool _ran = false;

  void _run() {
    const totalFetches = 20;
    const paramsChangeAt = 10;

    int beforeCalls = 0;
    int afterCalls = 0;
    int paramsChanges = 0;
    String? currentParams;

    for (var i = 0; i < totalFetches; i++) {
      final newParams = i == paramsChangeAt ? 'search=phone' : currentParams;

      // BEFORE: always unregister + register
      beforeCalls++;

      // AFTER: skip if params unchanged (what v2.0.0 does)
      final isFirstRegister = currentParams == null && i == 0;
      if (newParams != currentParams || isFirstRegister) {
        afterCalls++;
        paramsChanges++;
      }

      currentParams = newParams;
    }

    setState(() {
      _fetches = totalFetches;
      _beforeCalls = beforeCalls;
      _afterCalls = afterCalls;
      _paramsChanges = paramsChanges;
      _ran = true;
    });
  }

  void _cleanup() {
    setState(() { _ran = false; _fetches = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saved = _beforeCalls - _afterCalls;
    return _IssueCard(
      issueNumber: '6',
      title: 'Stale Listener: Skip When Unchanged',
      subtitle: 'v1.2.0: unregister + register on every fetch. '
          'v2.0.0: early-return if params are the same.',
      severity: Colors.orange,
      child: Column(
        children: [
          if (_ran) ...[
            Row(
              children: [
                Expanded(child: _StatTile(value: '$_fetches', label: 'Total\nFetches', color: Colors.blue)),
                Expanded(child: _StatTile(value: '$_beforeCalls', label: 'BEFORE\nRegister Calls', color: Colors.red)),
                Expanded(child: _StatTile(value: '$_afterCalls', label: 'AFTER\nRegister Calls', color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            _MetricBar(
              label: 'BEFORE: register() calls',
              value: '$_beforeCalls',
              fill: 1.0,
              color: Colors.red,
            ),
            _MetricBar(
              label: 'AFTER: register() calls (skipped $saved)',
              value: '$_afterCalls',
              fill: _afterCalls / _beforeCalls,
              color: Colors.green,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$saved unnecessary register/unregister cycles eliminated.\n'
                'Params changed $_paramsChanges time(s) across $_fetches fetches.',
                style: TextStyle(fontSize: 11, color: cs.onSurface),
              ),
            ),
          ] else
            Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                '20 fetches — params change only once at fetch #11',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Simulate 20 Fetches'),
                ),
              ),
              if (_ran) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _cleanup,
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Cleanup'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ISSUE #7: Redundant isStale Cache Lookups
// ═══════════════════════════════════════════════════════════════════════

class _Issue7Demo extends StatefulWidget {
  const _Issue7Demo();
  @override
  State<_Issue7Demo> createState() => _Issue7DemoState();
}

class _Issue7DemoState extends State<_Issue7Demo> {
  int _beforeUs = 0;
  int _afterUs = 0;
  int _controllers = 0;
  bool _ran = false;

  void _run() {
    final client = QueryClient.instance;
    const count = 30;
    const iters = 1000;

    for (var i = 0; i < count; i++) {
      client.set('stale-bench-$i', null, CachedQueryData(
        data: 'data-$i',
        fetchTime: DateTime.now(),
        staleTime: const Duration(minutes: 5),
      ));
    }

    // BEFORE: state.isStale || client.get().isStale
    final sw1 = Stopwatch()..start();
    for (var iter = 0; iter < iters; iter++) {
      for (var i = 0; i < count; i++) {
        final stateStale = false;
        final cacheStale = client.get<String>('stale-bench-$i', null)?.isStale == true;
        final _ = stateStale || cacheStale;
      }
    }
    sw1.stop();

    // AFTER: just state.isStale
    final sw2 = Stopwatch()..start();
    for (var iter = 0; iter < iters; iter++) {
      for (var i = 0; i < count; i++) {
        final stateStale = false;
        final _ = stateStale;
      }
    }
    sw2.stop();

    for (var i = 0; i < count; i++) {
      client.invalidate('stale-bench-$i');
    }

    setState(() {
      _beforeUs = sw1.elapsedMicroseconds;
      _afterUs = sw2.elapsedMicroseconds;
      _controllers = count;
      _ran = true;
    });
  }

  void _cleanup() {
    setState(() { _ran = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _IssueCard(
      issueNumber: '7',
      title: 'Redundant Staleness Check Removed',
      subtitle: 'v1.2.0: Checks state.isStale AND client.get().isStale. '
          'v2.0.0: Just state.isStale (already maintained by timer).',
      severity: Colors.orange,
      child: Column(
        children: [
          if (_ran) ...[
            Row(
              children: [
                Expanded(child: _StatTile(value: '$_controllers', label: 'Controllers', color: Colors.blue)),
                Expanded(child: _StatTile(value: '2', label: 'BEFORE\nChecks', color: Colors.red)),
                Expanded(child: _StatTile(value: '1', label: 'AFTER\nChecks', color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            _ComparisonRow(
              leftLabel: 'BEFORE (1K reconnects)',
              leftValue: '$_beforeUs us',
              leftUs: _beforeUs,
              rightLabel: 'AFTER (1K reconnects)',
              rightValue: '$_afterUs us',
              rightUs: _afterUs,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${(_beforeUs / (_afterUs == 0 ? 1 : _afterUs)).toStringAsFixed(1)}x faster  |  '
                '${_beforeUs - _afterUs} us saved across $_controllers controllers x 1,000 events',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.withValues(alpha: 0.9)),
              ),
            ),
          ] else
            Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                '30 controllers x 1,000 reconnect events',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.speed, size: 16),
                  label: const Text('Run Benchmark'),
                ),
              ),
              if (_ran) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _cleanup,
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Cleanup'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
