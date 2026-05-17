import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

class InfiniteQueryBuilder<B extends StateStreamable<QueryState<List<T>>>, T>
    extends BlocBuilder<B, QueryState<List<T>>> {
  const InfiniteQueryBuilder({
    super.key,
    super.bloc,
    super.buildWhen,
    required super.builder,
  });
}
