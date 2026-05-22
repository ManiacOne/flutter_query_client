import 'package:flutter/widgets.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

/// Provides a [QueryClient] to the widget tree and configures global defaults.
///
/// All configuration — caching, retries, network behaviour, infinite-query
/// pagination, logging, connectivity endpoints, and the lifecycle observer —
/// is passed here in one place rather than scattered across multiple setup
/// calls or repeated in every controller subclass:
///
/// ```dart
/// QueryClientProvider(
///   observer: AppQueryObserver(),
///   defaults: QueryDefaults(
///     staleTime: Duration(minutes: 5),
///     // Shared across every InfiniteQueryController that doesn't override:
///     initialPageParam: 0,  // first page parameter (default: 0)
///     limit: 20,            // items per page (default: 20)
///     enableLogging: true,
///     connectivityEndpoints: [
///       InternetCheckOption(uri: Uri.parse('https://my-api.com/health')),
///     ],
///   ),
///   child: MyApp(),
/// )
/// ```
class QueryClientProvider extends InheritedWidget {
  final QueryClient client;

  QueryClientProvider({
    super.key,
    QueryClient? client,
    QueryDefaults defaults = const QueryDefaults(),
    QueryObserver? observer,
    required super.child,
  }) : client = client ?? QueryClient.instance {
    final resolvedClient = this.client;
    resolvedClient.setDefaults(defaults);
    if (observer != null) {
      resolvedClient.setObserver(observer);
    }

    // Configure logging from defaults.
    if (defaults.enableLogging) {
      QueryLogger.enable(level: defaults.logLevel, onLog: defaults.onLog);
    }
  }

  static QueryClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<QueryClientProvider>();
    assert(provider != null, 'QueryClientProvider not found in context');
    return provider!.client;
  }

  @override
  bool updateShouldNotify(QueryClientProvider oldWidget) => false;
}
