import 'package:flutter/widgets.dart';

/// Base class for provider widgets that can be composed inside
/// [MultiQueryProvider].
///
/// Mirrors the pattern used by `MultiBlocProvider` — each provider widget
/// carries only its `create` function; [MultiQueryProvider] injects the
/// child automatically, so callers never need to pass one manually.
abstract class QueryProviderWidget extends StatefulWidget {
  const QueryProviderWidget({super.key});

  /// Returns a copy of this widget with [child] set.
  /// Used internally by [MultiQueryProvider] — not part of the public API.
  QueryProviderWidget copyWithChild(Widget child);
}
