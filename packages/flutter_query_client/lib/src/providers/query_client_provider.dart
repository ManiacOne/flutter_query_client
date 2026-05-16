import 'package:flutter/widgets.dart';
import '../client/query_client.dart';
import '../models/query_defaults.dart';
import '../utils/query_logger.dart';

/// Provides a [QueryClient] to the widget tree and configures global defaults.
///
/// All configuration (defaults, logging, connectivity endpoints) is passed
/// here in one place rather than scattered across multiple setup calls:
///
/// ```dart
/// QueryClientProvider(
///   defaults: QueryDefaults(
///     staleTime: Duration(minutes: 5),
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
    required super.child,
  }) : client = client ?? QueryClient.instance {
    final resolvedClient = this.client;
    resolvedClient.setDefaults(defaults);

    // Configure logging from defaults.
    if (defaults.enableLogging) {
      QueryLogger.enable(
        level: defaults.logLevel,
        onLog: defaults.onLog,
      );
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
