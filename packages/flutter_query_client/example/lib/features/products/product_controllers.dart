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
  int get initialPageParam => 0;

  @override
  int? getNextPageParam(
      List<Product> lastPage, List<List<Product>> allPages) {
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
}

// ── Single-item query controller ──────────────────────────────────

class ProductByIdController extends QueryController<Product, int> {
  ProductByIdController() : super('product');

  @override
  Future<Product> queryFn(int? id) => productService.getProductById(id!);
}

// ── Mutation controllers ───────────────────────────────────────────

class CreateProductMutation extends MutationController<Product> {}

class UpdateProductMutation extends MutationController<Product> {}

/// DummyJSON returns the deleted product object on DELETE.
class DeleteProductMutation extends MutationController<Product> {}
