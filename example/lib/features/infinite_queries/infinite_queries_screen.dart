import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

import '../../app_navigation.dart';
import '../products/product_model.dart';
import 'infinite_queries_controllers.dart';

/// Demonstrates [InfiniteQueriesController]: ONE controller observing several
/// independently-paginated product searches. `loadMore(query)` grows only that
/// list; `invalidate(query)` refetches only that list.
class InfiniteQueriesScreen extends StatelessWidget {
  const InfiniteQueriesScreen({super.key});

  static const List<String> _available = [
    'phone',
    'watch',
    'laptop',
    'shirt',
    'perfume',
  ];

  @override
  Widget build(BuildContext context) {
    return InfiniteQueriesProvider<MultiSearchController, Product, String>(
      create: (_) => MultiSearchController()..setFilters(['phone', 'watch']),
      child: Scaffold(
        appBar: AppBar(title: const Text('Infinite Queries')),
        drawer: const AppDrawer(),
        body: InfiniteQueriesBuilder<MultiSearchController, Product, String>(
          builder: (context, states) {
            final c = context.query<MultiSearchController>();
            final active = c.filters;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'One InfiniteQueriesController, many searches. Toggle a chip to '
                  'add/remove a paginated list; each has its own Load more and '
                  'Invalidate.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final q in _available)
                      FilterChip(
                        label: Text(q),
                        selected: active.contains(q),
                        onSelected: (sel) =>
                            sel ? c.addFilter(q) : c.removeFilter(q),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final q in active)
                  _SearchSection(
                    query: q,
                    state: states[q] ?? const QueryState<List<Product>>(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({required this.query, required this.state});

  final String query;
  final QueryState<List<Product>> state;

  @override
  Widget build(BuildContext context) {
    final c = context.query<MultiSearchController>();
    final items = state.data ?? const [];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('"$query"',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _badge(context, state),
                const Spacer(),
                Text('${items.length} items · ${c.fetchCountFor(query)}× fetched',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Invalidate "$query"',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => c.invalidate(query),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: state.isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _ProductTile(items[i]),
                    ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: (!c.hasMore(query) || state.isLoadingMore)
                    ? null
                    : () => c.loadMore(query),
                icon: state.isLoadingMore
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more, size: 18),
                label: Text(c.hasMore(query) ? 'Load more' : 'No more pages'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, QueryState<List<Product>> s) {
    late final String label;
    late final Color color;
    if (s.isLoading) {
      (label, color) = ('LOADING', Colors.amber);
    } else if (s.isRefetching) {
      (label, color) = ('REFETCH', Colors.blue);
    } else if (s.isSuccess) {
      (label, color) = ('OK', Colors.green);
    } else {
      (label, color) = ('IDLE', Colors.grey);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile(this.product);
  final Product product;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.thumbnail.isEmpty
                ? const SizedBox(height: 90, width: 110)
                : Image.network(product.thumbnail,
                    height: 90,
                    width: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(height: 90, width: 110)),
          ),
          const SizedBox(height: 4),
          Text(product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
          Text('\$${product.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
