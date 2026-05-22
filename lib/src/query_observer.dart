import 'package:bloc/bloc.dart';
import 'package:flutter_query_client/src/controller/infinite_query_controller.dart';
import 'package:flutter_query_client/src/controller/query_controller.dart';
import 'package:flutter_query_client/src/query_state.dart';

/// A [BlocObserver] specialised for query and mutation controllers.
///
/// Since [QueryController], [InfiniteQueryController], and
/// [MutationController] all extend [Cubit], the standard [BlocObserver]
/// already fires for them automatically. [QueryObserver] filters those
/// events and re-exposes them as typed, cache-key–aware hooks so you
/// don't have to downcast [BlocBase] in your own observer.
///
/// ## Registration
///
/// Register via [QueryClient] — no direct flutter_bloc dependency needed:
///
/// ```dart
/// // main.dart
/// QueryClient.instance.setObserver(AppQueryObserver());
/// ```
///
/// ## Usage
///
/// ```dart
/// class AppQueryObserver extends QueryObserver {
///   @override
///   void onQueryCreate(String cacheKey) =>
///       debugPrint('Controller created: $cacheKey');
///
///   @override
///   void onQueryChange(
///     String cacheKey,
///     QueryState<dynamic> currentState,
///     QueryState<dynamic> nextState,
///   ) {
///     debugPrint('[$cacheKey] ${currentState.status} → ${nextState.status}');
///   }
///
///   @override
///   void onQueryError(String cacheKey, Object error, StackTrace stackTrace) =>
///       FirebaseCrashlytics.instance.recordError(error, stackTrace);
///
///   @override
///   void onQueryClose(String cacheKey) =>
///       debugPrint('Controller closed: $cacheKey');
/// }
/// ```
///
/// ## Non-query cubits
///
/// You can still handle non-query cubits by overriding the raw
/// [BlocObserver] hooks. Always call `super` to preserve query-specific
/// behaviour:
///
/// ```dart
/// @override
/// void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
///   super.onChange(bloc, change); // ← fires onQueryChange for query controllers
///   if (bloc is MyOtherCubit) { ... }
/// }
/// ```
abstract class QueryObserver extends BlocObserver {
  const QueryObserver();

  // ─── Typed hooks (override these) ────────────────────────────────

  /// Called when a [QueryController], [InfiniteQueryController], or
  /// [MutationController] is first created.
  void onQueryCreate(String cacheKey) {}

  /// Called on every state change for a query or mutation controller.
  ///
  /// Provides both [currentState] and [nextState] — equivalent to
  /// [BlocObserver.onChange] but typed to [QueryState] and keyed by
  /// [cacheKey].
  void onQueryChange(
    String cacheKey,
    QueryState<dynamic> currentState,
    QueryState<dynamic> nextState,
  ) {}

  /// Called when a query or mutation controller encounters an unhandled
  /// stream error.
  void onQueryError(
    String cacheKey,
    Object error,
    StackTrace stackTrace,
  ) {}

  /// Called when a [QueryController], [InfiniteQueryController], or
  /// [MutationController] is closed.
  void onQueryClose(String cacheKey) {}

  // ─── BlocObserver bridge (call super when overriding) ─────────────

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    final key = _cacheKey(bloc);
    if (key != null) onQueryCreate(key);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final key = _cacheKey(bloc);
    if (key != null) {
      onQueryChange(
        key,
        change.currentState as QueryState<dynamic>,
        change.nextState as QueryState<dynamic>,
      );
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    final key = _cacheKey(bloc);
    if (key != null) onQueryError(key, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    final key = _cacheKey(bloc);
    if (key != null) onQueryClose(key);
  }

  // ─── Internal ────────────────────────────────────────────────────

  static String? _cacheKey(BlocBase<dynamic> bloc) {
    if (bloc is QueryController<dynamic, dynamic>) return bloc.cacheKey;
    if (bloc is InfiniteQueryController<dynamic, dynamic, dynamic>) {
      return bloc.cacheKey;
    }
    return null;
  }
}
