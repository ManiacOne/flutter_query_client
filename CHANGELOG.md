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
