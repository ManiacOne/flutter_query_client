## 1.1.0

### Features

* **keepPreviousData** — override `keepPreviousData` on `QueryController` or `InfiniteQueryController` to retain previous data while new data is loading, similar to TanStack Query's `placeholderData`. No UI changes required; `QueryState.isPlaceholderData` indicates when stale data is being shown
* **onSuccess / onQueryError hooks** — override `onSuccess` and `onQueryError` directly on `QueryController` and `InfiniteQueryController`, consistent with the existing hooks on `MutationController`
* **transformError getter** — override `transformError` per-controller to map raw exceptions into typed error objects before they reach the state

### Bug Fixes

* Fixed `InfiniteQueryController.setParams()` getting stuck in a loading state when params changed rapidly — new params now immediately reset the query state so the next fetch is never blocked by an in-flight request

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
