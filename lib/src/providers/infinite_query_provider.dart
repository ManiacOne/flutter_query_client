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
  @override
  Widget build(BuildContext context) {
    return BlocProvider<T>(create: widget.create, child: widget.child);
  }
}
