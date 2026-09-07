import 'package:flutter_query_client/flutter_query_client.dart';

import '../products/product_model.dart';
import '../products/product_service.dart';

/// `useQueries` analogue: ONE controller observing many product ids at once,
/// each with its own per-param loading state.
class DemoProductsQueries extends QueriesController<Product, int> {
  DemoProductsQueries() : super('demo_lab');

  /// Per-id network fetch counts, so a refetch is *visible* even though the API
  /// returns identical data every time.
  final Map<int, int> fetchCounts = {};

  int fetchCountFor(int id) => fetchCounts[id] ?? 0;

  // Cache-semantics demo — never gate on connectivity (the native probe can
  // report "offline" on simulators, which would pause refetches).
  @override
  NetworkMode get networkMode => NetworkMode.always;

  // Short staleTime so the "stale" badge is easy to observe.
  @override
  Duration? get staleTime => const Duration(seconds: 15);

  @override
  Future<Product> queryFn(int id) {
    fetchCounts[id] = (fetchCounts[id] ?? 0) + 1;
    return productService.getProductById(id);
  }
}
