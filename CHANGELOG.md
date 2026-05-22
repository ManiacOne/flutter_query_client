## 1.2.0

### Breaking changes

* None — all changes are backwards-compatible. Existing subclasses that already override `initialPageParam` and `limit` continue to work unchanged.

### New Features

* **`MultiQueryProvider`** — provide multiple query and infinite-query controllers without deep widget nesting; each entry is a builder function `Widget Function(Widget child)`, applied top-to-bottom
* **`QueryConsumer<C, T>`** — combines `QueryBuilder` + `QueryListener` in a single widget, eliminating the need to nest them; works with `QueryController` and `MutationController`
* **`InfiniteQueryConsumer<C, T>`** — same as `QueryConsumer` for infinite queries; the `List<T>` wrapper is baked into the type so only the item type is required
* **`QuerySelector<C, T, S>`** — a `BlocSelector` scoped to `QueryState<T>`; rebuilds only when the selected derived value `S` changes, ideal for counters, flags, and other narrow slices of state
* **`InfiniteQuerySelector<C, T, S>`** — same as `QuerySelector` for infinite queries; `List<T>` is baked in
* **`InfiniteQueryListener<C, T>`** — mirrors `InfiniteQueryBuilder` for the listener side; eliminates the verbose `QueryListener<C, List<T>>` type annotation
* **`QueryObserver`** — a `BlocObserver` subclass that filters events to query and mutation controllers and re-exposes them as typed, cache-key–aware hooks (`onQueryCreate`, `onQueryChange`, `onQueryError`, `onQueryClose`); `onQueryChange` receives both `currentState` and `nextState` matching standard `BlocObserver.onChange` semantics
* **`QueryDefaults.initialPageParam`** — global default first-page parameter for every `InfiniteQueryController`; defaults to `0` so zero-indexed integer pagination requires no per-controller override. Set to `1` for one-indexed APIs or any custom value for cursor-based APIs
* **`QueryDefaults.limit`** — global default page size for every `InfiniteQueryController`; defaults to `20`. Set once in `QueryClientProvider` instead of repeating `@override int get limit => N` in every subclass
* **`InfiniteQueryController.initialPageParam`** — no longer abstract; falls back to `QueryDefaults.initialPageParam` cast to `PageParam`. Override in a subclass only when that controller's starting param differs from the global default
* **`InfiniteQueryController.limit`** — now falls back to `QueryDefaults.limit` instead of a hardcoded `20`. Override per-controller when needed
* **`QueryClientProvider(observer:)`** — register a `QueryObserver` directly in `QueryClientProvider` alongside defaults and logging, keeping all global setup in one place; the constructor calls `QueryClient.setObserver` internally
* **`QueryClient.setObserver(BlocObserver)`** — lower-level escape hatch for registering an observer outside the widget tree; `QueryClientProvider(observer:)` is preferred at startup
* **Mutation widgets** — `MutationController<T>` already emits `QueryState<T>`, so `QueryBuilder`, `QueryListener`, `QueryConsumer`, and `QuerySelector` all work with mutations out of the box; no separate `MutationBuilder` or `MutationListener` needed

### Example

* Added a **Widgets tab** to the example app showcasing every widget in the package with live interactive demos: `MultiQueryProvider`, `QueryConsumer`, `QuerySelector`, `InfiniteQueryListener`, `InfiniteQuerySelector`, `InfiniteQueryConsumer`, `MultiQueryListener`, and `QueryObserver` (including mutations via `QueryBuilder`/`QueryListener`/`QueryConsumer`/`QuerySelector`)
* Registered `_AppQueryObserver` in `main()` demonstrating the observer pattern end-to-end

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
