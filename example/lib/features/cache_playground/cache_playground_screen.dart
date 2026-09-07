import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

import '../../app_navigation.dart';
import '../products/product_model.dart';
import 'cache_playground_controllers.dart';

/// Cache Lab — one [DemoProductsQueries] controller, provided via
/// [QueriesProvider], observing a growing set of product ids.
///
/// Demonstrates: adding params one-by-one to the same controller, independent
/// per-param loading, and per-param invalidate that keeps the previous data
/// visible until fresh data arrives.
class CachePlaygroundScreen extends StatelessWidget {
  const CachePlaygroundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QueriesProvider<DemoProductsQueries, Product, int>(
      create: (_) => DemoProductsQueries(),
      child: const _CacheLabView(),
    );
  }
}

class _CacheLabView extends StatelessWidget {
  const _CacheLabView();

  static const List<int> _ids = [1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cache Lab')),
      drawer: const AppDrawer(),
      // One builder rebuilds on any per-param state change. The controller is
      // resolved from the provider — no bloc: needed, no instance to manage.
      body: QueriesBuilder<DemoProductsQueries, Product, int>(
        builder: (context, states) {
          final controller = context.query<DemoProductsQueries>();
          final active = controller.params;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Tap "Fetch #N" to add a param to the same controller. Each card '
                'loads on its own. "Invalidate" refetches one card while keeping '
                'its old data visible (REFETCH badge) until new data arrives.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              // Add params one after another.
              Wrap(
                spacing: 8,
                children: [
                  for (final id in _ids)
                    FilledButton.tonal(
                      onPressed: active.contains(id)
                          ? null
                          : () => controller.addParam(id),
                      child: Text('Fetch #$id'),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Global actions.
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: active.isEmpty ? null : controller.invalidate,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Invalidate all'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: () => context.queryClient.clear(),
                    child: const Text('clear()'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (active.isEmpty)
                Text(
                  'No params observed yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    for (final id in active)
                      _QueryCard(
                        id: id,
                        state: states[id] ?? const QueryState<Product>(),
                        fetchCount: controller.fetchCountFor(id),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QueryCard extends StatelessWidget {
  const _QueryCard({
    required this.id,
    required this.state,
    required this.fetchCount,
  });

  final int id;
  final QueryState<Product> state;
  final int fetchCount;

  @override
  Widget build(BuildContext context) {
    final controller = context.query<DemoProductsQueries>();
    final product = state.data;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#$id',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _StatusBadge(state: state),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _body(context, product),
            ),
            const Divider(height: 12),
            Row(
              children: [
                Text('$fetchCount× fetched',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Optimistic +25 (typed, no network)',
                  icon: const Icon(Icons.bolt, size: 18),
                  onPressed: product == null
                      ? null
                      : () => controller.setData(
                          id, _bump(product, 25)),
                ),
                const SizedBox(width: 10),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Invalidate #$id (keeps data until refetch)',
                  icon: const Icon(Icons.refresh, size: 18),
                  // Typed — the controller serializes params internally.
                  onPressed: () => controller.invalidate(id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Product? product) {
    if (state.isLoading && product == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isError) {
      return const Text('error', style: TextStyle(color: Colors.redAccent));
    }
    if (product == null) {
      return const Text('empty');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text('\$${product.price.toStringAsFixed(2)}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  static Product _bump(Product p, double d) => Product(
        id: p.id,
        title: p.title,
        description: p.description,
        price: p.price + d,
        category: p.category,
        thumbnail: p.thumbnail,
        rating: p.rating,
        stock: p.stock,
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});
  final QueryState<Product> state;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (state.isLoading) {
      (label, color) = ('LOADING', Colors.amber);
    } else if (state.isRefetching) {
      (label, color) = ('REFETCH', Colors.blue);
    } else if (state.isError) {
      (label, color) = ('ERROR', Colors.red);
    } else if (state.isSuccess) {
      (label, color) = ('OK', Colors.green);
    } else {
      (label, color) = ('IDLE', Colors.grey);
    }
    return Wrap(spacing: 4, children: [
      _pill(label, color),
      if (state.isStale) _pill('STALE', Colors.orange),
    ]);
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4)),
      );
}
