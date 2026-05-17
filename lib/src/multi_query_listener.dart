import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

class MultiQueryListener extends StatelessWidget {
  const MultiQueryListener({
    required List<QueryListener> listeners,
    required Widget child,
    super.key,
  }) : _listeners = listeners,
       _child = child;

  final List<QueryListener> _listeners;
  final Widget _child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(listeners: _listeners, child: _child);
  }
}
