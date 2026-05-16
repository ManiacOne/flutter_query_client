import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

class QueryBuilder<B extends StateStreamable<QueryState<T>>, T>
    extends BlocBuilder<B, QueryState<T>> {
  const QueryBuilder({
    super.key,
    super.bloc,
    super.buildWhen,
    required super.builder,
  });
}
