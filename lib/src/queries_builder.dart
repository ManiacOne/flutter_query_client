import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/visibility/refetch_visibility.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocBuilder] scoped to a [QueriesController]'s `Map<P, QueryState<T>>`
/// state, so builders receive the per-param state map directly. Also the
/// refetch-on-visible boundary (calls `handleRemount()` when visible again).
///
/// [B] — the controller type. [T] — the item type. [P] — the param type.
///
/// ```dart
/// QueriesBuilder<ProductsByIds, Product, int>(
///   builder: (context, states) {
///     return Column(children: [
///       for (final entry in states.entries)
///         Text('#${entry.key}: '
///             '${entry.value.isLoading ? "…" : entry.value.data?.title}'),
///     ]);
///   },
/// )
/// ```
class QueriesBuilder<B extends StateStreamable<Map<P, QueryState<T>>>, T, P>
    extends StatelessWidget {
  const QueriesBuilder({
    super.key,
    this.bloc,
    required this.builder,
    this.buildWhen,
  });

  final B? bloc;
  final BlocWidgetBuilder<Map<P, QueryState<T>>> builder;
  final BlocBuilderCondition<Map<P, QueryState<T>>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return QueryRemountScope<B>(
      bloc: bloc,
      child: BlocBuilder<B, Map<P, QueryState<T>>>(
        bloc: bloc,
        buildWhen: buildWhen,
        builder: builder,
      ),
    );
  }
}
