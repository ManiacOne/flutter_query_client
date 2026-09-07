import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// Provides a [QueriesController] (state `Map<P, QueryState<T>>`) to the widget
/// tree, mirroring `QueryProvider` but for the multi-param `useQueries` analogue.
///
/// The provider owns the controller's lifecycle (closes it on dispose). Refetch-
/// on-visible is driven by the rendering widgets (`QueriesBuilder`), not the
/// provider — so it works even if this provider sits at a global level. Reach
/// the controller with `context.query<C>()`.
///
/// ```dart
/// QueriesProvider<ProductsByIds, Product, int>(
///   create: (_) => ProductsByIds()..setParams([1, 2, 3]),
///   child: const ProductsScreen(),
/// )
/// ```
class QueriesProvider<C extends Cubit<Map<P, QueryState<T>>>, T, P>
    extends StatefulWidget {
  const QueriesProvider({
    super.key,
    required this.create,
    required this.child,
  });

  final C Function(BuildContext context) create;
  final Widget child;

  @override
  State<QueriesProvider<C, T, P>> createState() =>
      _QueriesProviderState<C, T, P>();
}

class _QueriesProviderState<C extends Cubit<Map<P, QueryState<T>>>, T, P>
    extends State<QueriesProvider<C, T, P>> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<C>(create: widget.create, child: widget.child);
  }
}
