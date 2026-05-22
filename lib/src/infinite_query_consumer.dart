import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// Combines [InfiniteQueryBuilder] and [InfiniteQueryListener] in a single
/// widget — the [List] wrapper is baked in so you only specify the item type.
///
/// ```dart
/// InfiniteQueryConsumer<ProductsController, Product>(
///   listenWhen: (prev, next) => prev.isLoadingMore && !next.isLoadingMore,
///   listener: (context, state) {
///     if (state.isError) showSnackBar('Failed to load more');
///   },
///   builder: (context, state) {
///     final products = state.data ?? [];
///     if (state.isLoading) return const CircularProgressIndicator();
///     return ProductListView(products: products);
///   },
/// )
/// ```
class InfiniteQueryConsumer<
    B extends BlocBase<QueryState<List<T>>>,
    T> extends StatelessWidget {
  const InfiniteQueryConsumer({
    super.key,
    required this.builder,
    required this.listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
  });

  final BlocWidgetBuilder<QueryState<List<T>>> builder;
  final BlocWidgetListener<QueryState<List<T>>> listener;
  final B? bloc;
  final BlocBuilderCondition<QueryState<List<T>>>? buildWhen;
  final BlocListenerCondition<QueryState<List<T>>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, QueryState<List<T>>>(
      bloc: bloc,
      builder: builder,
      listener: listener,
      buildWhen: buildWhen,
      listenWhen: listenWhen,
    );
  }
}
