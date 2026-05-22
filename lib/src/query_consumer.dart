import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// Combines [QueryBuilder] and [QueryListener] in a single widget.
///
/// Equivalent to wrapping a [QueryBuilder] inside a [QueryListener] — use
/// this when you need both a reactive UI and a side-effect listener on the
/// same controller.
///
/// Works with [QueryController] **and** [MutationController] because both
/// emit [QueryState]:
///
/// ```dart
/// // Regular query
/// QueryConsumer<PostsController, List<Post>>(
///   listener: (context, state) {
///     if (state.isError) showSnackBar(state.error.toString());
///   },
///   builder: (context, state) {
///     if (state.isLoading) return const CircularProgressIndicator();
///     return PostListView(posts: state.data ?? []);
///   },
/// )
///
/// // Mutation
/// QueryConsumer<CreatePostMutation, Post>(
///   listenWhen: (_, next) => next.isSuccess || next.isError,
///   listener: (context, state) {
///     if (state.isSuccess) Navigator.pop(context, state.data);
///     if (state.isError) showError(state.error);
///   },
///   builder: (context, state) {
///     return FilledButton(
///       onPressed: state.isLoading ? null : _submit,
///       child: state.isLoading
///           ? const CircularProgressIndicator()
///           : const Text('Create'),
///     );
///   },
/// )
/// ```
class QueryConsumer<B extends BlocBase<QueryState<T>>, T>
    extends StatelessWidget {
  const QueryConsumer({
    super.key,
    required this.builder,
    required this.listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
  });

  final BlocWidgetBuilder<QueryState<T>> builder;
  final BlocWidgetListener<QueryState<T>> listener;
  final B? bloc;
  final BlocBuilderCondition<QueryState<T>>? buildWhen;
  final BlocListenerCondition<QueryState<T>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, QueryState<T>>(
      bloc: bloc,
      builder: builder,
      listener: listener,
      buildWhen: buildWhen,
      listenWhen: listenWhen,
    );
  }
}
