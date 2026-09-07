import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:flutter_query_client/src/visibility/refetch_visibility.dart';

/// A [BlocBuilder] scoped to [QueryController] / [MutationController] state.
///
/// Also the **refetch-on-visible boundary**: because it renders the query at the
/// point it's actually shown, it (not the provider) detects when this screen
/// becomes visible again — a `TickerMode`/tab flip or a `Navigator` push→pop via
/// [QueryNavigatorObserver] — and calls the controller's `handleRemount()`. This
/// works even when the controller is provided at a global level. (No-op for
/// mutations.)
class QueryBuilder<B extends StateStreamable<QueryState<T>>, T>
    extends StatelessWidget {
  const QueryBuilder({
    super.key,
    this.bloc,
    this.buildWhen,
    required this.builder,
  });

  final B? bloc;
  final BlocBuilderCondition<QueryState<T>>? buildWhen;
  final BlocWidgetBuilder<QueryState<T>> builder;

  @override
  Widget build(BuildContext context) {
    return QueryRemountScope<B>(
      bloc: bloc,
      child: BlocBuilder<B, QueryState<T>>(
        bloc: bloc,
        buildWhen: buildWhen,
        builder: builder,
      ),
    );
  }
}
