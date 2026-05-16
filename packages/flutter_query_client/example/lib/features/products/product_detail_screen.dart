import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'product_controllers.dart';
import 'product_model.dart';
import 'product_form_screen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Product #$productId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.query<ProductByIdController>().refetch(),
          ),
        ],
      ),
      body: QueryBuilder<ProductByIdController, Product>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text('Error: ${state.error}'));
          }
          final p = state.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    p.thumbnail,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, size: 64),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(p.title,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _edit(context, p),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Badge(p.category),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text(' ${p.rating.toStringAsFixed(1)}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.inventory_2_outlined, size: 16),
                    Text(' ${p.stock} in stock'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '\$${p.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text('Description',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(p.description),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 12)),
    );
  }
}
