/// # Refetch-on-visible — how the whole thing works
///
/// This file is the **single home** for "a screen became visible again"
/// detection. Everything that decides *when* to call a controller's
/// `handleRemount()` lives here; the provider and builder widgets only *use* it.
///
/// ## Why this is needed at all
///
/// In React/TanStack, navigating away *unmounts* a component and navigating back
/// *re-mounts* it, so "returned to this screen" is just "mount" — free. Flutter
/// is the opposite: a screen covered by a pushed route, or a tab you switch
/// away from, **stays mounted**. So we have to detect "visible again" ourselves.
///
/// Flutter emits that through **two different, non-overlapping mechanisms**, and
/// there is no single unifying signal — so we watch both:
///
/// 1. **`TickerMode` / `Visibility` flip** — used by kept-alive containers that
///    do *not* touch the route stack: `IndexedStack`, `TabBarView`, and
///    GoRouter's `StatefulShellRoute.indexedStack` (which literally wraps each
///    branch in `TickerMode(enabled: isActive)`). Switching tabs flips this;
///    **no route is pushed or popped**, so a `NavigatorObserver` is blind to it.
///
/// 2. **`Navigator` pop** — used when a page is pushed over another on the same
///    Navigator (a detail screen over a list). The covered route stays mounted
///    and **keeps ticking**, so `TickerMode` never flips; only a
///    `NavigatorObserver` sees the pop.
///
/// | Transition                         | route stack? | TickerMode? | caught by         |
/// |------------------------------------|:-----------:|:-----------:|-------------------|
/// | push detail over list, then back   | yes (pop)   | no          | NavigatorObserver |
/// | switch bottom-nav tab / branch      | no          | yes         | TickerMode        |
/// | scroll a widget off/onto screen     | no          | no          | (neither — n/a)   |
///
/// ## The moving parts (and how they connect)
///
/// ```
///   app installs (one PER Navigator)          each rendering widget wraps its
///   ┌───────────────────────┐                 Bloc* child in ↓
///   │ QueryNavigatorObserver │                 ┌──────────────────────────┐
///   │  (a NavigatorObserver) │                 │ QueryRemountScope<B>      │
///   └───────────┬────────────┘                 │  → RefetchOnRemount       │
///     didPop(popped, revealed)                 │     (State with           │
///               │                              │      RemountDetector)     │
///               ▼                              └───────────┬──────────────┘
///        ┌─────────────────────────────────────────────────┴───────────┐
///        │           RemountRegistry (one shared singleton)             │
///        │             Map<Route, Set<VoidCallback>>                    │
///        └──────────────────────────────────────────────────────────────┘
/// ```
///
/// * **[QueryNavigatorObserver]** — created by the app and added to a Navigator's
///   `observers`. Creates no routes; it is only *told* when routes push/pop. One
///   instance per Navigator (Flutter forbids sharing across Navigators). On a
///   page pop it looks up the revealed route in [RemountRegistry] and fires it.
/// * **[RemountRegistry]** — one process-wide `Map<Route, Set<callback>>`. It
///   decouples the (possibly many) observers from the (many) widgets: a widget
///   registers *once* under its own route, and whichever observer sees that
///   route revealed fires it. Keyed by route identity, so it is exact.
/// * **[RemountDetector]** — a `State` mixin used by [RefetchOnRemount]. In
///   `didChangeDependencies` it (a) registers its own `ModalRoute` in the
///   registry and (b) checks the `TickerMode`/`Visibility` edge. On dispose it
///   unregisters. It owns *no* observer.
/// * **[QueryRemountScope]** — the widget the `Query*` builders wrap around their
///   `Bloc*` child. On the visible edge it resolves the controller `B` (from an
///   explicit bloc or the enclosing provider) and calls
///   [triggerControllerRemount].
///
/// ## Runtime trace — list → detail → back (same branch/Navigator)
///
/// 1. App wires `QueryNavigatorObserver()` into the branch's `observers`; it
///    attaches to that branch's Navigator.
/// 2. The list's `QueryBuilder` mounts → its [QueryRemountScope] registers
///    `{ R_list: {cb_list} }` in [RemountRegistry].
/// 3. Tapping pushes `R_detail`. `observer.didPush(R_detail, R_list)` fires —
///    not handled (no-op). `R_list` is now covered but still mounted & registered.
/// 4. The detail's builder registers `{ R_detail: {cb_detail} }`.
/// 5. Back → the Navigator pops `R_detail`. `observer.didPop(R_detail, R_list)`
///    fires; both are `PageRoute`s → `RemountRegistry.notifyRevealed(R_list)` →
///    `cb_list()` → `handleRemount()` → refetch (per `refetchOnMount`).
/// 6. `R_detail`'s scope disposes → unregisters `R_detail`.
///
/// ## Runtime trace — switch tab and back (no Navigator involved)
///
/// Switching branches flips the inactive branch's `TickerMode` to `false`, then
/// back to `true` on return. No route changes, so no observer fires. Instead,
/// the tab content's [RemountDetector.didChangeDependencies] sees `TickerMode`
/// go `false → true` and calls `onRemount()` directly.
///
/// ## Notes
///
/// * Only full-screen `PageRoute`s count: dismissing a dialog / bottom sheet
///   (a `PopupRoute`) does **not** refetch.
/// * Several builders on one screen register under the *same* route → all fire;
///   `handleRemount()` dedups the concurrent refetch.
/// * If the controller is provided at a global/root level, this still works,
///   because detection is anchored to the *builder's* context (the visible
///   widget), never the provider's.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query_client/src/controller/infinite_queries_controller.dart';
import 'package:flutter_query_client/src/controller/infinite_query_controller.dart';
import 'package:flutter_query_client/src/controller/queries_controller.dart';
import 'package:flutter_query_client/src/controller/query_controller.dart';

// ─── 1. Registry: route → remount callbacks (shared by all observers) ───

/// Maps a screen's [PageRoute] to the remount callbacks that should fire when
/// that screen is revealed by a pop. Shared so that several
/// [QueryNavigatorObserver]s (one per navigator in a `StatefulShellRoute`) can
/// all feed one place, while each widget registers exactly once, by route.
class RemountRegistry {
  RemountRegistry._();
  static final RemountRegistry instance = RemountRegistry._();

  final Map<Route<dynamic>, Set<VoidCallback>> _callbacks = {};

  void register(Route<dynamic> route, VoidCallback cb) =>
      _callbacks.putIfAbsent(route, () => {}).add(cb);

  void unregister(Route<dynamic> route, VoidCallback cb) {
    final set = _callbacks[route];
    if (set == null) return;
    set.remove(cb);
    if (set.isEmpty) _callbacks.remove(route);
  }

  /// Fire the callbacks for [route] — it was just revealed by a pop.
  void notifyRevealed(Route<dynamic> route) {
    final set = _callbacks[route];
    if (set == null) return;
    for (final cb in set.toList()) {
      cb();
    }
  }
}

// ─── 2. The observer the app attaches to each Navigator ───

/// A [NavigatorObserver] you add to a navigator's `observers` so query widgets
/// can detect when their screen is uncovered by a `Navigator` pop — the
/// visibility signal that `TickerMode` cannot see. Universal across routing
/// packages: GoRouter, `auto_route`, Navigator 2.0 and plain `Navigator` all
/// drive the same `Route` machinery.
///
/// **Create one per navigator.** A `NavigatorObserver` may belong to only one
/// Navigator, so:
///
/// ```dart
/// // Plain MaterialApp — one navigator, use the shared instance:
/// MaterialApp(navigatorObservers: [QueryNavigatorObserver.instance], ...);
///
/// // GoRouter StatefulShellRoute — a fresh one for the root and each branch:
/// GoRouter(
///   observers: [QueryNavigatorObserver()],
///   routes: [StatefulShellRoute.indexedStack(branches: [
///     StatefulShellBranch(observers: [QueryNavigatorObserver()], routes: [...]),
///     StatefulShellBranch(observers: [QueryNavigatorObserver()], routes: [...]),
///   ], ...)],
/// );
/// ```
class QueryNavigatorObserver extends NavigatorObserver {
  QueryNavigatorObserver();

  /// A shared instance for the common single-navigator case (one `MaterialApp`).
  static final QueryNavigatorObserver instance = QueryNavigatorObserver();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Only full-screen page transitions count (dialogs/sheets are PopupRoutes).
    if (route is PageRoute && previousRoute is PageRoute) {
      RemountRegistry.instance.notifyRevealed(previousRoute);
    }
  }
}

// ─── 3. The detector mixin (both signals live here) ───

/// Fires [onRemount] on a hidden→visible edge, from either universal signal:
/// a `TickerMode`/`Visibility` flip, or a `Navigator` pop that reveals this
/// screen's route (via [QueryNavigatorObserver] → [RemountRegistry]).
mixin RemountDetector<W extends StatefulWidget> on State<W> {
  bool? _wasActive;
  PageRoute<dynamic>? _registeredRoute;

  /// Stable tear-off so register/unregister use the same callback identity.
  late final VoidCallback _remountCb = onRemount;

  /// Invoked on each hidden→visible edge.
  void onRemount();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // (1) Navigator pop signal: register this screen's PageRoute so the observer
    // can fire it on pop-back. (PopupRoutes like dialogs are ignored.)
    final route = ModalRoute.of(context);
    final pageRoute = route is PageRoute<dynamic> ? route : null;
    if (pageRoute != _registeredRoute) {
      if (_registeredRoute != null) {
        RemountRegistry.instance.unregister(_registeredRoute!, _remountCb);
      }
      if (pageRoute != null) {
        RemountRegistry.instance.register(pageRoute, _remountCb);
      }
      _registeredRoute = pageRoute;
    }

    // (2) TickerMode/Visibility edge: a kept-alive branch/tab turning back on.
    final isActive = TickerMode.of(context) && Visibility.of(context);
    if (_wasActive != null && !_wasActive! && isActive) {
      onRemount();
    }
    _wasActive = isActive;
  }

  @override
  void dispose() {
    if (_registeredRoute != null) {
      RemountRegistry.instance.unregister(_registeredRoute!, _remountCb);
      _registeredRoute = null;
    }
    super.dispose();
  }
}

// ─── 4. A concrete widget carrying the detector ───

/// Wraps [child] and calls [onRemount] whenever the subtree becomes visible
/// again. Used internally by the `Query*` rendering widgets.
class RefetchOnRemount extends StatefulWidget {
  const RefetchOnRemount({
    required this.onRemount,
    required this.child,
    super.key,
  });

  final VoidCallback onRemount;
  final Widget child;

  @override
  State<RefetchOnRemount> createState() => _RefetchOnRemountState();
}

class _RefetchOnRemountState extends State<RefetchOnRemount>
    with RemountDetector {
  @override
  void onRemount() => widget.onRemount();

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── 5. The scope the builders place around their Bloc* child ───

/// A [RefetchOnRemount] that resolves controller [B] (from [bloc] or the
/// enclosing provider) and calls its `handleRemount()` on the visible edge.
class QueryRemountScope<B extends Object> extends StatelessWidget {
  const QueryRemountScope({required this.bloc, required this.child, super.key});

  final B? bloc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefetchOnRemount(
      onRemount: () {
        var resolved = bloc;
        if (resolved == null) {
          // Resolve from the enclosing provider only when needed (on the visible
          // edge), so lazy providers stay lazy until actually rendered.
          try {
            resolved = context.read<B>();
          } catch (_) {
            // No provider for B (e.g. an explicit bloc that left the tree).
          }
        }
        triggerControllerRemount(resolved);
      },
      child: child,
    );
  }
}

// ─── 6. Dispatch to the right controller ───

/// Calls `handleRemount()` on [bloc] when it is a query-type controller.
/// No-op for mutations, other cubits, closed controllers, or null.
void triggerControllerRemount(Object? bloc) {
  if (bloc is QueryController<dynamic, dynamic>) {
    if (!bloc.isClosed) bloc.handleRemount();
  } else if (bloc is InfiniteQueryController<dynamic, dynamic, dynamic>) {
    if (!bloc.isClosed) bloc.handleRemount();
  } else if (bloc is QueriesController<dynamic, dynamic>) {
    if (!bloc.isClosed) bloc.handleRemount();
  } else if (bloc is InfiniteQueriesController<dynamic, dynamic, dynamic>) {
    if (!bloc.isClosed) bloc.handleRemount();
  }
}
