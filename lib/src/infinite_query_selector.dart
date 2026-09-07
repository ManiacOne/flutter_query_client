import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/visibility/refetch_visibility.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocSelector] scoped to [InfiniteQueryController] state. Rebuilds **only**
/// when the selected value changes; the [List] wrapper is baked in. Also the
/// refetch-on-visible boundary (calls `handleRemount()` when visible again).
///
/// [B] — the controller type. [T] — the item type. [S] — the selected value.
///
/// ```dart
/// InfiniteQuerySelector<ProductsController, Product, int>(
///   selector: (state) => state.data?.length ?? 0,
///   builder: (context, count) => Text('$count items loaded'),
/// )
/// ```
class InfiniteQuerySelector<B extends StateStreamable<QueryState<List<T>>>, T, S>
    extends StatelessWidget {
  const InfiniteQuerySelector({
    super.key,
    this.bloc,
    required this.selector,
    required this.builder,
  });

  final B? bloc;
  final BlocWidgetSelector<QueryState<List<T>>, S> selector;
  final BlocWidgetBuilder<S> builder;

  @override
  Widget build(BuildContext context) {
    return QueryRemountScope<B>(
      bloc: bloc,
      child: BlocSelector<B, QueryState<List<T>>, S>(
        bloc: bloc,
        selector: selector,
        builder: builder,
      ),
    );
  }
}
