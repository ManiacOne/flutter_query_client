import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'package:query_client_example/app_observer.dart';
import 'home_screen.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: QueryClient.instance,
      // Register a global QueryObserver — extends BlocObserver, so it receives
      // lifecycle events from every QueryController, InfiniteQueryController,
      // and MutationController automatically. No manual instrumentation needed.
      observer: AppQueryObserver(),
      defaults: QueryDefaults(
        staleTime: Duration(minutes: 5),
        gcTime: Duration(minutes: 10),
        retryCount: 3,
        enableLogging: true,
        initialPageParam: 0,
        connectivityEndpoints: [
          InternetCheckOption(
            uri: Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
          ),
        ],
        transformError: (error) {
          if (error is QueryException) {
            return Exception(
              'Query failed with status code ${error.toString()}: ${error.message}',
            );
          }
          return error;
        },
      ),
      child: MaterialApp(
        title: 'Query Client',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
