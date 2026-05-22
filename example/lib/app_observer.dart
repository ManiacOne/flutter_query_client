import 'package:flutter/foundation.dart';
import 'package:flutter_query_client/flutter_query_client.dart';

/// Example observer that logs all query lifecycle events.
///
/// In production you would send these to Sentry, Firebase, etc.
class AppQueryObserver extends QueryObserver {
  @override
  void onQueryCreate(String cacheKey) {
    QueryLogger.fine('[Observer] created: $cacheKey');
  }

  /// Receives both the previous and next state — same as BlocObserver.onChange.
  @override
  void onQueryChange(
    String cacheKey,
    QueryState<dynamic> currentState,
    QueryState<dynamic> nextState,
  ) {
    if (kDebugMode) {
      QueryLogger.fine(
        '[Observer] $cacheKey — '
        '${currentState.status.name} → ${nextState.status.name}',
      );
    }
  }

  @override
  void onQueryError(String cacheKey, Object error, StackTrace stackTrace) {
    QueryLogger.warning('[Observer] $cacheKey error: $error');
    // e.g. FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  @override
  void onQueryClose(String cacheKey) {
    QueryLogger.fine('[Observer] closed: $cacheKey');
  }
}
