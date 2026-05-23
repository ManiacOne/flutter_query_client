import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/client/query_client.dart';
import 'package:flutter_query_client/src/models/cached_query_data.dart';
import 'package:flutter_query_client/src/providers/query_client_provider.dart';

extension QueryContextExtension on BuildContext {
  T query<T extends Cubit<Object>>() => BlocProvider.of<T>(this);
  T queryWatch<T extends Cubit<Object>>() =>
      BlocProvider.of<T>(this, listen: true);
  QueryClient get queryClient => QueryClientProvider.of(this);
  CachedQueryData<T>? cachedQuery<T>(String key) {
    return queryClient.get<T>(key);
  }

  CachedQueryData<T>? cachedQueryWithParams<T>(
    String key,
    String serializedParams,
  ) {
    return queryClient.get<T>(key, serializedParams);
  }
}
