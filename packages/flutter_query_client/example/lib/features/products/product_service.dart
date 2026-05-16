import '../../core/api_client.dart';
import '../../core/endpoints.dart';
import 'product_model.dart';

class ProductService {
  final ApiClient _api;
  ProductService({ApiClient? api}) : _api = api ?? apiClient;

  Future<PaginatedProducts> getProducts({int limit = 10, int skip = 0}) async {
    final data = await _api.get(
      Endpoints.products(),
      queryParams: {'limit': '$limit', 'skip': '$skip'},
    );
    return PaginatedProducts.fromJson(data as Map<String, dynamic>);
  }

  Future<Product> getProductById(int id) async {
    final data = await _api.get(Endpoints.productById(id));
    return Product.fromJson(data as Map<String, dynamic>);
  }

  Future<PaginatedProducts> searchProducts(
    String query, {
    int limit = 10,
    int skip = 0,
  }) async {
    final data = await _api.get(
      Endpoints.searchProducts(),
      queryParams: {'q': query, 'limit': '$limit', 'skip': '$skip'},
    );
    return PaginatedProducts.fromJson(data as Map<String, dynamic>);
  }

  Future<Product> createProduct({
    required String title,
    required String description,
    required double price,
    required String category,
    int stock = 0,
  }) async {
    final data = await _api.post(Endpoints.addProduct(), {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'stock': stock,
    });
    return Product.fromJson(data as Map<String, dynamic>);
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> fields) async {
    final data = await _api.put(Endpoints.updateProduct(id), fields);
    return Product.fromJson(data as Map<String, dynamic>);
  }

  Future<Product> deleteProduct(int id) async {
    final data = await _api.delete(Endpoints.deleteProduct(id));
    return Product.fromJson(data as Map<String, dynamic>);
  }
}

final productService = ProductService();
