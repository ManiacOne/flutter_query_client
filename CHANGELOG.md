## 2.0.0

### Breaking changes

* **`MultiQueryProvider.providers`** type changed from `List<Widget Function(Widget child)>` to `List<QueryProviderWidget>` — callers must replace builder functions with plain provider instances:

  ```dart
  // Before (1.2.0)
  MultiQueryProvider(
    providers: [
      (child) => QueryProvider<PostsController, List<Post>>(
        create: (_) => PostsController(), child: child,
      ),
    ],
    child: HomeScreen(),
  )

  // After (2.0.0)
  MultiQueryProvider(
    providers: [
      QueryProvider<PostsController, List<Post>>(
        create: (_) => PostsController(),
      ),
    ],
    child: HomeScreen(),
  )
  ```

* **`MutationController<T>` → `MutationController<T, P>`** — mutations now take a typed params generic `P`, matching the `QueryController<T, P>` pattern. Subclasses must override `mutationFn(P params)` instead of passing a closure to `mutate()`. For mutations that don't need params, use `void` as the second type argument.

  ```dart
  // Before (1.2.0)
  class CreatePostMutation extends MutationController<Post> {
    Future<void> create(String title) async {
      await mutate(() => postService.createPost(title: title));
    }
  }

  // After (2.0.0)
  class CreatePostMutation
      extends MutationController<Post, ({String title})> {
    @override
    Future<Post> mutationFn(({String title}) params) {
      return postService.createPost(title: params.title);
    }
  }

  // Usage: context.query<CreatePostMutation>().mutate((title: 'Hello'))
  ```

### New features

* **`QueryProviderWidget`** — new public abstract base class that both `QueryProvider` and `InfiniteQueryProvider` extend, enabling `MultiQueryProvider` composition; custom provider wrappers can also extend it to participate in `MultiQueryProvider`
* **`QueryClientProvider(observer:)`** — register a `QueryObserver` directly in `QueryClientProvider` alongside defaults and logging, keeping all global setup in one place; the constructor calls `QueryClient.setObserver` internally. `QueryClient.setObserver` remains available as a lower-level escape hatch for registering outside the widget tree
* **`QueryDefaults.initialPageParam`** — global default first-page parameter for every `InfiniteQueryController`; defaults to `0`. Set to `1` for one-indexed APIs or any custom value for cursor-based APIs — no per-controller override needed unless that controller differs from the global default
* **`QueryDefaults.limit`** — global default page size for every `InfiniteQueryController`; defaults to `20`. Set once in `QueryClientProvider` instead of repeating `@override int get limit => N` in every subclass
* **`InfiniteQueryController.initialPageParam`** — no longer abstract; falls back to `QueryDefaults.initialPageParam` cast to `PageParam`. Must still be overridden when the controller's `PageParam` type or starting value differs from the global default
* **`InfiniteQueryController.limit`** — now falls back to `QueryDefaults.limit` rather than a hardcoded `20`; override per-controller when needed

### Performance & memory optimizations

* **Fixed: `NetworkConnectivityObserver` StreamController leak** — the broadcast `StreamController` was eagerly allocated and never closed (singleton lifetime). It is now created lazily and tracks active listeners via `onListen`/`onCancel` callbacks. Added `listenerCount` getter for diagnostics
* **Fixed: `QueryClient` singleton had no diagnostic visibility** — added `activeStaleTimerCount`, `activeGcTimerCount`, `activeInvalidateCallbackCount`, `activeReconnectCallbackCount`, and `cacheEntryCount` getters for debugging timer and callback leaks
* **Fixed: dangling callback references in `QueryClient`** — if a controller was garbage-collected without `close()`, its `_onInvalidate` and `_onReconnect` callbacks persisted forever. `_notifyInvalidateCallbacks` and `_onConnectivityChange` now catch exceptions from stale callbacks and auto-prune them
* **Fixed: unnecessary deep copies in `InfiniteQueryController._saveToCache`** — replaced `List<T>.from(p)` (O(n) element-by-element copy) with `UnmodifiableListView<T>(p)` from `dart:collection` (O(1) zero-copy wrapper). `_restoreFromCache` and `handleRemount` use `List<T>.of()` instead of `List<T>.from()` to skip per-element type checks. `handleRemount` no longer allocates a flat list just to compare lengths
* **Fixed: flat-cache thrashing on optimistic updates** — `updateItem` now patches `_flatCache` in-place via `_flatIndexOf()` instead of nulling and rebuilding the entire flat list. `prependItem` and `appendItem` insert/add directly into `_flatCache`. Only `removeItem` (which changes list length) invalidates the cache
* **Fixed: redundant stale-listener re-registration** — `StaleListenerHandle.register()` now returns early when params are unchanged, avoiding unnecessary `Set.remove()` + closure allocation + `Set.add()` on every fetch. Added `isRegistered` and `registeredParams` getters
* **Fixed: redundant `isStale` cache lookups on reconnect** — `_handleReconnect()` in both `QueryController` and `InfiniteQueryController` no longer performs a redundant `client.get(key)?.isStale` lookup; `state.isStale` (maintained by the stale-timer callback) is sufficient

### Notes

* **`QueryClient.updateInfiniteQuery<T>`** — 
  1. **Preferred (controller reachable via `BuildContext`)** — call the controller's own helpers directly: `prependItem`, `appendItem`, `updateItem`, or `removeItem`. These patch `_flatCache` in O(1) and emit a new state immediately. `updateInfiniteQuery` is then optional (use it when provider access is not present in the context - and you will see changes when navigated to desired page).

### Example

* Added **Issues** tab to the example app with interactive before/after benchmarks for every optimization above; full documentation extracted to `example/lib/features/inefficiency_demos/OPTIMIZATIONS.md`
* Updated **Posts** form screen to use `MutationController<T, P>` typed params, `MultiQueryListener`, and `QueryClient.instance.update` to patch the flat `'posts'` cache from within mutation listeners — no `flutter_bloc` import required
* Updated **Products** form screen to use `MutationController<T, P>` typed params and `MultiQueryProvider` / `MultiQueryListener`; the paginated list screen demonstrates `updateInfiniteQuery` + `prependItem` to sync both the cache and the live controller after a create
* Updated **Posts** list screen to sync the live `PostsQueryController` from the already-patched cache via `updateCache((posts) => posts)` after a create, avoiding a double-prepend

---

## 1.2.0

### New features

* **`MultiQueryProvider`** — nest multiple `QueryProvider` and `InfiniteQueryProvider` widgets without deep indentation; providers are applied top-to-bottom
* **`QueryConsumer<C, T>`** — combines `QueryBuilder` + `QueryListener` in a single widget, eliminating the need to nest them; works with both `QueryController` and `MutationController`
* **`InfiniteQueryConsumer<C, T>`** — same as `QueryConsumer` for infinite queries; the `List<T>` wrapper is baked into the type so only the item type is required
* **`QuerySelector<C, T, S>`** — a `BlocSelector` scoped to `QueryState<T>`; rebuilds only when the selected derived value `S` changes, ideal for counters, flags, and other narrow slices of state
* **`InfiniteQuerySelector<C, T, S>`** — same as `QuerySelector` for infinite queries; `List<T>` is baked in
* **`InfiniteQueryListener<C, T>`** — mirrors `InfiniteQueryBuilder` for the listener side; eliminates the verbose `QueryListener<C, List<T>>` type annotation
* **`QueryObserver`** — a `BlocObserver` subclass that filters events to query and mutation controllers and re-exposes them as typed, cache-key–aware hooks (`onQueryCreate`, `onQueryChange`, `onQueryError`, `onQueryClose`); `onQueryChange` receives both `currentState` and `nextState`, matching standard `BlocObserver.onChange` semantics
* **Mutation widgets** — `MutationController<T>` emits `QueryState<T>`, so `QueryBuilder`, `QueryListener`, `QueryConsumer`, and `QuerySelector` all work with mutations out of the box; no separate `MutationBuilder` or `MutationListener` needed

### Example

* Added a **Widgets** tab to the example app with live interactive demos of every widget in the package, including all mutation-controller combinations

---

## 1.1.0

### Fixes

* Fixed race condition in `InfiniteQueryController._executeFirstPage` cache-hit branch — missing `_filterVersion` check after `await Future.delayed(Duration.zero)` could cause stale filter data to be emitted if `setParams` was called concurrently
* Fixed race condition in `InfiniteQueryController._executeFirstPage` pause branch — same missing version check allowed a `paused` state emit to overwrite state set by a concurrent `setParams` call
* Fixed `InfiniteQueryController.loadMore` not calling `_startRefetchInterval()` on success — polling would never start if `loadMore` was the first successful fetch operation

---

## 1.0.1

### Fixes

* Removed unnecessary `package:meta/meta.dart` import from `QueryController` and `InfiniteQueryController` — elements are already available via `package:flutter/foundation.dart`
* Removed `@internal` annotation from `handleRemount()` in both controllers
* Fixed unresolved dartdoc references in `QueryLogger` and `RefetchOnMount` — replaced `[Logger.root.onRecord]` and `[staleTime]` with backtick code spans

---

## 1.0.0

Initial stable release.

### Features

* **QueryController** — fetch and cache server data with automatic stale-while-revalidate, retry with exponential backoff, refetch on mount, and refetch on reconnect
* **MutationController** — user-triggered mutations with lifecycle hooks (`onSuccess`, `onMutationError`, `onSettled`) and optimistic cache update support
* **InfiniteQueryController** — paginated / infinite-scroll queries with `loadMore()`, `hasMore`, cursor or page-number pagination, and item-level cache helpers (`updateItem`, `removeItem`, `appendItem`, `prependItem`)
* **QueryClient** — singleton two-level cache (`baseKey` + serialized params) with stale-time tracking, garbage collection, and active observer registry
* **QueryClientProvider** — `InheritedWidget` for injecting `QueryClient` and global `QueryDefaults` into the widget tree
* **QueryProvider / InfiniteQueryProvider** — `StatefulWidget` wrappers with remount detection via `TickerMode` for `IndexedStack` and `Visibility` support
* **QueryBuilder / InfiniteQueryBuilder** — reactive builders that rebuild on state changes
* **QueryListener / MultiQueryListener** — side-effect widgets that respond to success and error without rebuilding the tree
* **QueryState** — Freezed-based immutable state with `status`, `fetchStatus`, `isStale`, and convenience getters
* **NetworkConnectivityObserver** — true L7 connectivity verification (HTTP HEAD), debounced events (500ms), lazy initialization
* **QueryDefaults** — global configuration for stale time, gc time, retry count, retry delay, refetch interval, network mode, error transform, and logging
* **QueryLogger** — opt-in structured logging with customizable handlers
