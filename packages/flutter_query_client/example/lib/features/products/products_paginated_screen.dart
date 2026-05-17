import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'product_controllers.dart';
import 'product_model.dart';
import 'product_service.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

// Features demonstrated on this screen:
//  • InfiniteQueryController — cursor/page-based pagination
//  • setParams()             — live search triggers new page sequence
//  • loadMore()              — triggered on scroll near bottom
//  • removeItem()            — optimistic item removal from all pages
//  • refetchOnMount: never   — manual load, no auto-fetch on navigate back

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
  Timer? _searchDebounce;

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
    // setParams() resets the page sequence and re-runs queryFn with new filters.
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.query<ProductsInfiniteController>().setParams(query.trim());
    });
  }

  void _clearSearch() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchCtrl.clear();
    context.query<ProductsInfiniteController>().setParams('');
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete product?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${product.title}"'),
                const SizedBox(height: 8),
                const Text(
                  'Uses removeItem() to optimistically remove this product '
                  'from all pages in the infinite cache.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
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
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      // removeItem() scans all pages and removes the matching item.
      context.query<ProductsInfiniteController>().removeItem(
        (p) => p.id == product.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text('"${product.title}" removed from infinite cache'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
        ),
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
          content: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text('Created: ${created.title} (id: ${created.id})'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                hintText: 'setParams() live search…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) {
                setState(() {});
                _onSearch(v);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_products',
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: Column(
        children: [
          // ── Feature banner ────────────────────────────────────
          FeatureBanner(
            features: [
              FeatureItem(
                Icons.all_inclusive,
                'InfiniteQueryController',
                Colors.purple,
              ),
              FeatureItem(Icons.tune, 'setParams() search', Colors.blue),
              FeatureItem(
                Icons.expand_more,
                'loadMore() on scroll',
                Colors.green,
              ),
              FeatureItem(
                Icons.remove_circle_outline,
                'removeItem() optimistic',
                Colors.red,
              ),
              FeatureItem(
                Icons.replay_outlined,
                'refetchOnMount: never',
                Colors.orange,
              ),
              FeatureItem(
                Icons.layers_outlined,
                'keepPreviousData',
                Colors.cyan,
              ),
            ],
          ),

          // ── Query content ─────────────────────────────────────
          Expanded(
            child: InfiniteQueryBuilder<ProductsInfiniteController, Product>(
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
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load products',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              () =>
                                  context
                                      .query<ProductsInfiniteController>()
                                      .invalidateAndRefresh(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final products = state.data ?? [];
                final ctrl = context.query<ProductsInfiniteController>();

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        const Text('No products found'),
                        if (_searchCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'setParams("${_searchCtrl.text}") returned 0 results',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // ── Thin progress bar on background refetch ──
                    if (state.isRefetching || state.isPlaceholderData)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: cs.primary,
                        backgroundColor: cs.primary.withValues(alpha: 0.15),
                      ),

                    // ── Placeholder data banner ──
                    if (state.isPlaceholderData)
                      Container(
                        width: double.infinity,
                        color: Colors.cyan.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 14,
                              color: Colors.cyan,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'keepPreviousData — showing old results while fetching',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.cyan,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Stats row ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            'Showing ${products.length} of ${ctrl.totalItems}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (state.isRefetching || state.isPlaceholderData)
                            QueryStatusBadge(
                              isPaused: false,
                              isRefetching: true,
                              isStale: false,
                              isSuccess: false,
                            ),
                          const Spacer(),
                          if (ctrl.hasMore)
                            Text(
                              'Scroll to load more',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.35),
                              ),
                            )
                          else
                            Text(
                              'All pages loaded',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Product list (dimmed when isPlaceholderData) ──
                    Expanded(
                      child: Opacity(
                        opacity: state.isPlaceholderData ? 0.5 : 1.0,
                        child: ListView.separated(
                          controller: _scrollCtrl,
                          itemCount:
                              products.length + (state.isLoadingMore ? 1 : 0),
                          separatorBuilder:
                              (_, __) => Divider(
                                height: 1,
                                color: cs.outline.withValues(alpha: 0.2),
                              ),
                          itemBuilder: (context, i) {
                            // Load more spinner at end
                            if (i >= products.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 8),
                                      Text(
                                        'loadMore() — fetching page ${ctrl.currentPage + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final product = products[i];
                            return _ProductTile(
                              product: product,
                              onDelete: () => _delete(product),
                              onTap: () async {
                                final infCtrl =
                                    context.query<ProductsInfiniteController>();
                                final updated = await Navigator.push<Product>(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => ProductDetailScreen(
                                          productId: product.id,
                                        ),
                                  ),
                                );
                                if (updated != null) {
                                  // updateItem() scans all pages and replaces the
                                  // matching item — no refetch needed.
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
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.onDelete,
    required this.onTap,
  });

  Color _ratingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.amber;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratingColor = _ratingColor(product.rating);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product.thumbnail,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 24,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 12),

            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.star_rounded, size: 14, color: ratingColor),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12, color: ratingColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stock chip + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        product.stock > 10
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.stock > 10
                        ? '${product.stock} in stock'
                        : 'Low: ${product.stock}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: product.stock > 10 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: cs.error.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
