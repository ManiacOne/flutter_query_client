import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/visibility/refetch_visibility.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocBuilder] scoped to an [InfiniteQueriesController]'s
/// `Map<F, QueryState<List<T>>>` state — one flattened list + status per
/// observed filter-set. Also the refetch-on-visible boundary (calls
/// `handleRemount()` when the screen becomes visible again).
///
/// [B] — the controller type. [T] — the item type. [F] — the filters type.
class InfiniteQueriesBuilder<
    B extends StateStreamable<Map<F, QueryState<List<T>>>>,
    T,
    F> extends StatelessWidget {
  const InfiniteQueriesBuilder({
    super.key,
    this.bloc,
    required this.builder,
    this.buildWhen,
  });

  final B? bloc;
  final BlocWidgetBuilder<Map<F, QueryState<List<T>>>> builder;
  final BlocBuilderCondition<Map<F, QueryState<List<T>>>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return QueryRemountScope<B>(
      bloc: bloc,
      child: BlocBuilder<B, Map<F, QueryState<List<T>>>>(
        bloc: bloc,
        buildWhen: buildWhen,
        builder: builder,
      ),
    );
  }
}
