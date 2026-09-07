import 'package:flutter_query_client/flutter_query_client.dart';

import '../products/product_model.dart';
import '../products/product_service.dart';

/// One controller observing several product searches at once — each search term
/// is an independently-paginated infinite list.
///
/// [T] = Product, [PageParam] = int (page index), [F] = String (search query).
class MultiSearchController
    extends InfiniteQueriesController<Product, int, String> {
  MultiSearchController() : super('multi_search');

  /// Per-query network fetch counts, so a refetch is visible.
  final Map<String, int> fetchCounts = {};
  int fetchCountFor(String query) => fetchCounts[query] ?? 0;

  @override
  NetworkMode get networkMode => NetworkMode.always;

  @override
  int? get limit => 6;

  @override
  int? get initialPageParam => 0;

  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.never;

  @override
  Duration? get refetchInterval => const Duration(seconds: 20);
  

  @override
  int? getNextPageParam(List<Product> last, List<List<Product>> all) {
    if (last.length < limit!) return null; // last page reached
    return all.length; // next page index
  }

  @override
  Future<List<Product>> queryFn(int page, String query) async {
    fetchCounts[query] = (fetchCounts[query] ?? 0) + 1;
    final res = await productService.searchProducts(
      query,
      limit: limit!,
      skip: page * limit!,
    );
    return res.products;
  }
}
