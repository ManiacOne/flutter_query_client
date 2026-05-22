import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocSelector] scoped to [InfiniteQueryController] state.
///
/// Rebuilds **only** when the selected value changes. The [List] wrapper is
/// baked in — specify only the item type [T] and the selected value type [S].
///
/// [B] — the controller type (e.g. `ProductsController`).
/// [T] — the item type (e.g. `Product`).
/// [S] — the derived/selected value type (e.g. `int` for total item count).
///
/// ```dart
/// // Only rebuilds when total item count changes.
/// InfiniteQuerySelector<ProductsController, Product, int>(
///   selector: (state) => state.data?.length ?? 0,
///   builder: (context, count) => Text('$count items loaded'),
/// )
///
/// // Select whether more pages are available.
/// InfiniteQuerySelector<ProductsController, Product, bool>(
///   selector: (state) => state.isLoadingMore,
///   builder: (context, isLoadingMore) => isLoadingMore
///       ? const CircularProgressIndicator()
///       : const SizedBox.shrink(),
/// )
/// ```
class InfiniteQuerySelector<
    B extends StateStreamable<QueryState<List<T>>>,
    T,
    S> extends BlocSelector<B, QueryState<List<T>>, S> {
  const InfiniteQuerySelector({
    super.key,
    super.bloc,
    required super.selector,
    required super.builder,
  });
}
