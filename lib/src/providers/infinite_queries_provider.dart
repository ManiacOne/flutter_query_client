import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// Provides an [InfiniteQueriesController] (state `Map<F, QueryState<List<T>>>`)
/// to the widget tree and owns its lifecycle (closes on dispose). Refetch-on-
/// visible is driven by the rendering widgets (`InfiniteQueriesBuilder`), not
/// the provider — so it works even if this provider sits at a global level.
/// Reach the controller with `context.query<C>()`.
class InfiniteQueriesProvider<C extends Cubit<Map<F, QueryState<List<T>>>>, T, F>
    extends StatefulWidget {
  const InfiniteQueriesProvider({
    super.key,
    required this.create,
    required this.child,
  });

  final C Function(BuildContext context) create;
  final Widget child;

  @override
  State<InfiniteQueriesProvider<C, T, F>> createState() =>
      _InfiniteQueriesProviderState<C, T, F>();
}

class _InfiniteQueriesProviderState<C extends Cubit<Map<F, QueryState<List<T>>>>,
    T, F> extends State<InfiniteQueriesProvider<C, T, F>> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<C>(create: widget.create, child: widget.child);
  }
}
