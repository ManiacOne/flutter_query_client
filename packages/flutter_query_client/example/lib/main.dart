import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
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
      defaults: QueryDefaults(
        staleTime: Duration(minutes: 5),
        gcTime: Duration(minutes: 10),
        retryCount: 3,
        enableLogging: true,
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
        title: 'Query Tester',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}
