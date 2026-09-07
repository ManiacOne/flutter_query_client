import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_query_client/src/visibility/refetch_visibility.dart';

/// A [BlocBuilder] scoped to [InfiniteQueryController] state. Also the refetch-
/// on-visible boundary: it calls the controller's `handleRemount()` when the
/// screen becomes visible again (tab flip or `Navigator` push→pop).
class InfiniteQueryBuilder<B extends StateStreamable<QueryState<List<T>>>, T>
    extends StatelessWidget {
  const InfiniteQueryBuilder({
    super.key,
    this.bloc,
    this.buildWhen,
    required this.builder,
  });

  final B? bloc;
  final BlocBuilderCondition<QueryState<List<T>>>? buildWhen;
  final BlocWidgetBuilder<QueryState<List<T>>> builder;

  @override
  Widget build(BuildContext context) {
    return QueryRemountScope<B>(
      bloc: bloc,
      child: BlocBuilder<B, QueryState<List<T>>>(
        bloc: bloc,
        buildWhen: buildWhen,
        builder: builder,
      ),
    );
  }
}
