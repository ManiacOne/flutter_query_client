import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/controller/infinite_query_controller.dart';
import 'package:flutter_query_client/src/providers/query_provider_widget.dart';

class InfiniteQueryProvider<
        T extends InfiniteQueryController<dynamic, dynamic, dynamic>>
    extends QueryProviderWidget {
  final T Function(BuildContext context) create;
  final Widget? child;

  const InfiniteQueryProvider({super.key, required this.create, this.child});

  @override
  InfiniteQueryProvider<T> copyWithChild(Widget child) =>
      InfiniteQueryProvider<T>(create: create, child: child);

  @override
  State<InfiniteQueryProvider<T>> createState() =>
      _InfiniteQueryProviderState<T>();
}

class _InfiniteQueryProviderState<
        T extends InfiniteQueryController<dynamic, dynamic, dynamic>>
    extends State<InfiniteQueryProvider<T>> {
  bool? _wasActive;
  T? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.of(context) && Visibility.of(context);

    if (_wasActive != null && !_wasActive! && isActive) {
      final c = _controller;
      if (c != null && !c.isClosed) {
        c.handleRemount();
      }
    }

    _wasActive = isActive;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<T>(
      create: (ctx) {
        final controller = widget.create(ctx);
        _controller = controller;
        return controller;
      },
      child: widget.child,
    );
  }
}
