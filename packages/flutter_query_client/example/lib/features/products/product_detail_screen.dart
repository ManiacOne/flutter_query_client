import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'product_controllers.dart';
import 'product_model.dart';
import 'product_form_screen.dart';

// Features demonstrated on this screen:
//  • staleTime: 30s override      — per-controller, shorter than global 5 min
//  • refetchOnReconnect: always   — always re-fetches when network restores
//  • updateCache() + Navigator.pop(updated) — propagates edits back to list

class ProductDetailScreen extends StatelessWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return QueryProvider<ProductByIdController, Product>(
      create: (_) => ProductByIdController()..setParams(productId),
      child: _ProductDetailView(productId: productId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _ProductDetailView extends StatelessWidget {
  final int productId;
  const _ProductDetailView({required this.productId});

  Future<void> _edit(BuildContext context, Product product) async {
    final controller = context.query<ProductByIdController>();
    final navigator = Navigator.of(context);
    final updated = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (updated != null) {
      controller.updateCache((_) => updated);
      navigator.pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Product #$productId'),
        actions: [
          // Live status badge inside AppBar — uses QueryBuilder in actions
          QueryBuilder<ProductByIdController, Product>(
            builder: (context, state) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: QueryStatusBadge(
                  isPaused: state.isPaused,
                  isRefetching: state.isRefetching,
                  isStale: state.isStale,
                  isSuccess: state.isSuccess,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Manual refetch',
            onPressed: () => context.query<ProductByIdController>().refetch(),
          ),
        ],
      ),
      body: QueryBuilder<ProductByIdController, Product>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 12),
                  Text('${state.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        context.query<ProductByIdController>().refetch(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final p = state.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Feature banner ──────────────────────────────
                FeatureBanner(
                  features: [
                    FeatureItem(
                      Icons.timelapse,
                      'staleTime: 30s (override)',
                      Colors.blue,
                    ),
                    FeatureItem(
                      Icons.cell_tower,
                      'refetchOnReconnect: always',
                      Colors.teal,
                    ),
                    FeatureItem(
                      Icons.edit_note,
                      'updateCache() + pop(result)',
                      Colors.orange,
                    ),
                  ],
                ),

                // ── Hero image ──────────────────────────────────
                Stack(
                  children: [
                    Image.network(
                      p.thumbnail,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            height: 220,
                            color: cs.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 64,
                                color: cs.onSurface.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                    ),
                    // Price badge over image
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          '\$${p.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title + edit ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              p.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _edit(context, p),
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Category + rating + stock ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(
                            label: p.category,
                            color: cs.secondaryContainer,
                            textColor: cs.onSecondaryContainer,
                          ),
                          _Chip(
                            icon: Icons.star_rounded,
                            label: p.rating.toStringAsFixed(1),
                            color: Colors.amber.withValues(alpha: 0.2),
                            textColor: Colors.amber,
                          ),
                          _Chip(
                            icon: Icons.inventory_2_outlined,
                            label: p.stock > 0
                                ? '${p.stock} in stock'
                                : 'Out of stock',
                            color: p.stock > 10
                                ? Colors.green.withValues(alpha: 0.15)
                                : p.stock > 0
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : cs.errorContainer,
                            textColor: p.stock > 10
                                ? Colors.green
                                : p.stock > 0
                                    ? Colors.orange
                                    : cs.onErrorContainer,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Description ──
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.description,
                        style: TextStyle(
                          height: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Staleness info card ──
                      if (state.isStale)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.timelapse,
                                  size: 16, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cache is stale (>30s old). Next mount will '
                                  'trigger a background refetch.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
