import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/visibility/refetch_visibility.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocSelector] scoped to [QueryController] / [MutationController] state.
///
/// Rebuilds **only** when the selected value changes, making it ideal for
/// widgets that depend on a single derived property of the query state. Like
/// [QueryBuilder], it also acts as the refetch-on-visible boundary (it calls
/// the controller's `handleRemount()` when the screen becomes visible again).
///
/// [B] — the controller type (e.g. `PostsController`).
/// [T] — the query data type (e.g. `List<Post>`).
/// [S] — the derived/selected value type (e.g. `int` for item count).
///
/// ```dart
/// // Only rebuilds when the post count changes, not on every refetch.
/// QuerySelector<PostsController, List<Post>, int>(
///   selector: (state) => state.data?.length ?? 0,
///   builder: (context, count) => Text('$count posts'),
/// )
/// ```
class QuerySelector<B extends StateStreamable<QueryState<T>>, T, S>
    extends StatelessWidget {
  const QuerySelector({
    super.key,
    this.bloc,
    required this.selector,
    required this.builder,
  });

  final B? bloc;
  final BlocWidgetSelector<QueryState<T>, S> selector;
  final BlocWidgetBuilder<S> builder;

  @override
  Widget build(BuildContext context) {
    return QueryRemountScope<B>(
      bloc: bloc,
      child: BlocSelector<B, QueryState<T>, S>(
        bloc: bloc,
        selector: selector,
        builder: builder,
      ),
    );
  }
}
