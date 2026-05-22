import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocSelector] scoped to [QueryController] / [MutationController] state.
///
/// Rebuilds **only** when the selected value changes, making it ideal for
/// widgets that depend on a single derived property of the query state.
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
///
/// // Select the loading flag from a mutation controller.
/// QuerySelector<CreatePostMutation, Post, bool>(
///   selector: (state) => state.isLoading,
///   builder: (context, isLoading) => FilledButton(
///     onPressed: isLoading ? null : _submit,
///     child: const Text('Submit'),
///   ),
/// )
/// ```
class QuerySelector<B extends StateStreamable<QueryState<T>>, T, S>
    extends BlocSelector<B, QueryState<T>, S> {
  const QuerySelector({
    super.key,
    super.bloc,
    required super.selector,
    required super.builder,
  });
}
