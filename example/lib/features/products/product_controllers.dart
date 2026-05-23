import 'package:flutter_query_client/flutter_query_client.dart';
import 'product_model.dart';
import 'product_service.dart';

// ── Infinite query controller ─────────────────────────────────────

/// Page-number pagination with search filter.
/// PageParam = int (page number), F = String (search query).
class ProductsInfiniteController
    extends InfiniteQueryController<Product, int, String> {
  ProductsInfiniteController() : super('products');

  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.never;

  @override
  bool get keepPreviousData => true;

  @override
  int? getNextPageParam(List<Product> lastPage, List<List<Product>> allPages) {
    if (lastPage.length < limit) return null;
    return allPages.length;
  }

  @override
  Future<List<Product>> queryFn(int pageParam, String? filters) async {
    final query = filters?.trim() ?? '';
    if (query.isNotEmpty) {
      final result = await productService.searchProducts(
        query,
        limit: limit,
        skip: pageParam * limit,
      );
      return result.products;
    }
    final result = await productService.getProducts(
      limit: limit,
      skip: pageParam * limit,
    );
    return result.products;
  }

  @override
  int get limit => 10;

  // Lifecycle hook: called after every successful fetch/refetch/loadMore.
  @override
  void onSuccess(List<Product> data) {
    QueryLogger.info('[Products] Loaded ${data.length} items');
  }

  // Lifecycle hook: called after a failed fetch — good for analytics/logging.
  @override
  void onQueryError(Object error) {
    QueryLogger.warning('[Products] Fetch failed: $error');
  }
}

// ── Single-item query controller ──────────────────────────────────

/// Demonstrates per-controller staleTime and refetchOnReconnect overrides.
class ProductByIdController extends QueryController<Product, int> {
  ProductByIdController() : super('product');

  // Product detail goes stale after 30 seconds — shorter than the global 5 min.
  @override
  Duration? get staleTime => const Duration(seconds: 30);

  // Always refetch product detail when the device reconnects, even if fresh —
  // price and stock can change frequently.
  @override
  RefetchOnReconnect get refetchOnReconnect => RefetchOnReconnect.always;

  @override
  Future<Product> queryFn(int? id) => productService.getProductById(id!);
}

// ── Mutation param types ──────────────────────────────────────────

typedef CreateProductParams = ({
  String title,
  String description,
  double price,
  String category,
  int stock,
});

typedef UpdateProductParams = ({
  int id,
  Map<String, dynamic> fields,
});

// ── Mutation controllers ───────────────────────────────────────────

class CreateProductMutation
    extends MutationController<Product, CreateProductParams> {
  @override
  Future<Product> mutationFn(CreateProductParams params) {
    return productService.createProduct(
      title: params.title,
      description: params.description,
      price: params.price,
      category: params.category,
      stock: params.stock,
    );
  }
}

class UpdateProductMutation
    extends MutationController<Product, UpdateProductParams> {
  @override
  Future<Product> mutationFn(UpdateProductParams params) {
    return productService.updateProduct(params.id, params.fields);
  }
}

/// DummyJSON returns the deleted product object on DELETE.
class DeleteProductMutation extends MutationController<Product, int> {
  @override
  Future<Product> mutationFn(int params) {
    return productService.deleteProduct(params);
  }
}
