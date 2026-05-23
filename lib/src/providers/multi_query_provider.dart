import 'package:flutter/widgets.dart';
import 'package:flutter_query_client/src/providers/query_provider_widget.dart';

/// Nests multiple [QueryProvider] and [InfiniteQueryProvider] widgets without
/// deep indentation.
///
/// Equivalent to [MultiBlocProvider] — pass each provider without a `child`
/// and [MultiQueryProvider] injects it automatically:
///
/// ```dart
/// MultiQueryProvider(
///   providers: [
///     QueryProvider<PostsController, List<Post>>(
///       create: (_) => PostsController(),
///     ),
///     QueryProvider<CreatePostMutation, Post>(
///       create: (_) => CreatePostMutation(),
///     ),
///     InfiniteQueryProvider<ProductsController>(
///       create: (_) => ProductsController(),
///     ),
///   ],
///   child: const HomeScreen(),
/// )
/// ```
///
/// Providers are applied top-to-bottom — the first entry becomes the
/// outermost ancestor in the widget tree.
class MultiQueryProvider extends StatelessWidget {
  const MultiQueryProvider({
    required this.providers,
    required this.child,
    super.key,
  });

  final List<QueryProviderWidget> providers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    for (final provider in providers.reversed) {
      result = provider.copyWithChild(result);
    }
    return result;
  }
}
