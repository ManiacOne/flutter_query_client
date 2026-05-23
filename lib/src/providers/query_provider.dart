import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/controller/query_controller.dart';
import 'package:flutter_query_client/src/providers/query_provider_widget.dart';
import 'package:flutter_query_client/src/query_state.dart';

class QueryProvider<C extends Cubit<QueryState<T>>, T>
    extends QueryProviderWidget {
  final C Function(BuildContext context) create;
  final Widget? child;

  const QueryProvider({super.key, required this.create, this.child});

  @override
  QueryProvider<C, T> copyWithChild(Widget child) =>
      QueryProvider<C, T>(create: create, child: child);

  @override
  State<QueryProvider<C, T>> createState() => _QueryProviderState<C, T>();
}

class _QueryProviderState<C extends Cubit<QueryState<T>>, T>
    extends State<QueryProvider<C, T>> {
  bool? _wasActive;
  C? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.of(context) && Visibility.of(context);

    if (_wasActive != null && !_wasActive! && isActive) {
      final c = _controller;
      if (c != null && c is QueryController<dynamic, dynamic> && !c.isClosed) {
        (c as QueryController<dynamic, dynamic>).handleRemount();
      }
    }

    _wasActive = isActive;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<C>(
      create: (ctx) {
        final controller = widget.create(ctx);
        _controller = controller;
        return controller;
      },
      child: widget.child,
    );
  }
}
