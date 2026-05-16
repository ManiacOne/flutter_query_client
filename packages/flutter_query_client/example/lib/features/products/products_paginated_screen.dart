import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'product_controllers.dart';
import 'product_model.dart';
import 'product_service.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsPaginatedScreen extends StatelessWidget {
  const ProductsPaginatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfiniteQueryProvider<ProductsInfiniteController>(
      create: (_) => ProductsInfiniteController(),
      child: const _ProductsView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _ProductsView extends StatefulWidget {
  const _ProductsView();

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  late final DeleteProductMutation _deleteMutation;

  @override
  void initState() {
    super.initState();
    _deleteMutation = DeleteProductMutation();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _deleteMutation.close();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      final ctrl = context.query<ProductsInfiniteController>();
      if (ctrl.hasMore && !ctrl.state.isLoadingMore && !ctrl.state.isLoading) {
        ctrl.loadMore();
      }
    }
  }

  void _onSearch(String query) {
    context.query<ProductsInfiniteController>().setParams(query.trim());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    context.query<ProductsInfiniteController>().setParams('');
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete product?'),
            content: Text('"${product.title}"'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    await _deleteMutation.mutate(
      () => productService.deleteProduct(product.id),
    );

    if (!mounted) return;
    if (_deleteMutation.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${_deleteMutation.state.error}'),
        ),
      );
    } else {
      // Optimistically remove from the aggregated list
      context.query<ProductsInfiniteController>().removeItem(
        (p) => p.id == product.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.title}" deleted (mock)')),
      );
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created: ${created.title} (id: ${created.id})'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() {}), // rebuild suffix icon
              onSubmitted: _onSearch,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_products',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: InfiniteQueryBuilder<ProductsInfiniteController, Product>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null &&
              (state.data == null || state.data!.isEmpty)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${state.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        () =>
                            context
                                .query<ProductsInfiniteController>()
                                .invalidateAndRefresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final products = state.data ?? [];
          final ctrl = context.query<ProductsInfiniteController>();

          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      'Showing ${products.length} of ${ctrl.totalItems}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (state.isRefetching) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollCtrl,
                  itemCount: products.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i >= products.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final product = products[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.thumbnail,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.image_not_supported,
                                size: 50,
                              ),
                        ),
                      ),
                      title: Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '\$${product.price.toStringAsFixed(2)} • ${product.category}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _delete(product),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final infCtrl =
                            context.query<ProductsInfiniteController>();
                        final updated = await Navigator.push<Product>(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    ProductDetailScreen(productId: product.id),
                          ),
                        );
                        if (updated != null) {
                          infCtrl.updateItem(
                            (p) => p.id == updated.id,
                            updated,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
