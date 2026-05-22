import 'package:flutter/widgets.dart';

/// Nests multiple query providers without deep indentation.
///
/// Each entry in [providers] is a function that wraps a child widget — pass
/// a [QueryProvider] or [InfiniteQueryProvider] that receives the [child]:
///
/// ```dart
/// MultiQueryProvider(
///   providers: [
///     (child) => QueryProvider<UsersController, List<User>>(
///       create: (_) => UsersController(),
///       child: child,
///     ),
///     (child) => InfiniteQueryProvider<ProductsController>(
///       create: (_) => ProductsController(),
///       child: child,
///     ),
///   ],
///   child: const HomeScreen(),
/// )
/// ```
///
/// Providers are applied top-to-bottom, meaning the first entry in the list
/// is the outermost ancestor in the widget tree.
class MultiQueryProvider extends StatelessWidget {
  const MultiQueryProvider({
    required this.providers,
    required this.child,
    super.key,
  });

  final List<Widget Function(Widget child)> providers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    for (final provider in providers.reversed) {
      result = provider(result);
    }
    return result;
  }
}
