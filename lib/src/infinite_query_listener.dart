import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

/// A [BlocListener] scoped to [InfiniteQueryController] state.
///
/// Eliminates the need to spell out `QueryListener<MyController, List<T>>` —
/// the [List] wrapper is baked in, so you only provide the item type [T]:
///
/// ```dart
/// InfiniteQueryListener<ProductsController, Product>(
///   listener: (context, state) {
///     if (state.isError) showSnackBar(state.error.toString());
///   },
///   child: const ProductListView(),
/// )
/// ```
class InfiniteQueryListener<B extends StateStreamable<QueryState<List<T>>>, T>
    extends BlocListener<B, QueryState<List<T>>> {
  const InfiniteQueryListener({
    super.key,
    super.bloc,
    super.listenWhen,
    required super.listener,
    super.child,
  });
}
