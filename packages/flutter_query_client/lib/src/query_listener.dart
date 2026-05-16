import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

class QueryListener<B extends StateStreamable<QueryState<T>>, T>
    extends BlocListener<B, QueryState<T>> {
  const QueryListener({
    super.key,
    required super.listener,
    super.listenWhen,
    super.bloc,
    super.child,
  });
}
