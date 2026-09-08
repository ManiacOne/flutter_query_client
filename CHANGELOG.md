## 4.1.0

### Fixed: controller options now correctly override global defaults

Controller-level option overrides now **always** take precedence over
`QueryDefaults`, matching the documented contract and TanStack Query. Previously
several options resolved as `global ?? controller`, so a non-null global default
silently **overrode** an explicit controller override (e.g. global
`refetchOnMount: never` suppressed a controller's `refetchOnMount: always`).

* **Precedence is now `controller override → global default → hardcoded fallback`**
  for every option, across `QueryController`, `InfiniteQueryController`,
  `QueriesController`, `InfiniteQueriesController` (and mutation `retryDelay`).
  Affected options: `refetchOnMount`, `retryCount`, `retryDelay`, `networkMode`,
  `refetchOnReconnect`, `refetchOnAppFocus`, `refetchIntervalInBackground`,
  `keepPreviousData`. (`staleTime` and `refetchInterval` were already correct.)
* These option getters now default to **`null`** = "not overridden, defer to the
  global/hardcoded default." Existing subclass overrides that return a non-null
  value keep compiling (covariant) and now correctly win over the global.
* **New: per-controller `gcTime` override** — previously `gcTime` could only be
  set globally; controllers can now override it like any other option.

**Behaviour change / upgrading:** if you set a global default *and* also overrode
the same option in a controller, the **controller value now wins** (previously the
global did). This only affects code that relied on the old inverted precedence;
review any place you set both a global default and a controller override for the
options above.

---

## 4.0.0

### Universal refetch-on-visible across all navigation (no per-package hacks)

Refetch-on-visible now works for **every** navigation pattern from **two universal,
navigation-package-agnostic signals** — no `active` flag to wire up, no GoRouter-specific
code — resolving the gap where returning to a screen via `Navigator` push→pop (and nested
paths) never refetched.

* **Detection moved from the providers to the rendering widgets** (`QueryBuilder`,
  `QueryConsumer`, `QuerySelector`, `QueriesBuilder`, `InfiniteQueryBuilder`,
  `InfiniteQueryConsumer`, `InfiniteQuerySelector`, `InfiniteQueriesBuilder`). Visibility is a
  property of the widget that *renders* the query, not of the provider — which may sit at a
  global/root level and never become invisible. Each rendering widget now detects its own
  visibility and calls `handleRemount()`, so refetch-on-visible works even when the controller
  is provided globally, and composes across multiple consumption sites (`handleRemount` dedups
  concurrent refetches). This is the **breaking change**: if you render a query with a raw
  `BlocBuilder` instead of a `Query*` widget, switch to the matching `Query*` widget to keep
  auto-refetch.

* **New: `QueryNavigatorObserver`** — a `NavigatorObserver` you add to your navigator's
  `observers`. Returning from a pushed route (plain `Navigator`, GoRouter, `auto_route`,
  Navigator 2.0 — they all drive the same `Route` machinery) refetches the revealed screen per
  its `refetchOnMount` policy. A covered route keeps ticking, so `TickerMode` cannot see
  push/pop — a `NavigatorObserver` is the only universal signal for it. **Create one per
  navigator** (a `NavigatorObserver` belongs to a single Navigator): the shared `.instance` for
  a single `MaterialApp`, and a fresh instance for the root and each branch of a
  `StatefulShellRoute`. All instances feed one shared route-keyed registry, so widgets register
  once.

  ```dart
  // Plain MaterialApp — one navigator:
  MaterialApp(navigatorObservers: [QueryNavigatorObserver.instance], home: HomeScreen());

  // GoRouter StatefulShellRoute — fresh instance per navigator:
  GoRouter(observers: [QueryNavigatorObserver()], routes: [
    StatefulShellRoute.indexedStack(branches: [
      StatefulShellBranch(observers: [QueryNavigatorObserver()], routes: [...]),
      StatefulShellBranch(observers: [QueryNavigatorObserver()], routes: [...]),
    ], builder: ...),
  ]);
  ```

* **Only full-screen `PageRoute`s count.** Dismissing a **dialog**, bottom sheet, or popup
  menu (all `PopupRoute`s) does **not** refetch — dismissing a dialog is not a screen re-entry.
* **`TickerMode`/`Visibility` detection is unchanged** — tab/branch switches (GoRouter
  `StatefulShellRoute`, `IndexedStack`) keep working. The two signals compose: whichever fires
  first triggers the remount.
* **Providers are now pure lifecycle owners** (create + close the controller); they no longer
  do remount detection.
* **All visibility detection lives in one file** — `lib/src/visibility/refetch_visibility.dart`
  (registry + observer + detector mixin + the builder scope), with a full "how it works" doc.
* **Removed `RefetchOnVisible`.** The `Query*` builder widgets now detect visibility
  automatically (both signals), so the manual `active:`-flag widget is redundant. If you were
  rendering a query with a raw `BlocBuilder`, switch to the matching `Query*` widget.
* **Upgrading from 3.0.0:** add `QueryNavigatorObserver.instance` to your navigator
  `observers` (or a fresh `QueryNavigatorObserver()` per navigator for GoRouter
  `StatefulShellRoute`) to opt into push/pop refetch, and render queries with the `Query*`
  widgets (not raw `BlocBuilder`) so they detect visibility. Dialog-dismiss does not refetch.

> **Note on versioning:** 4.0.0 is the first release published since **3.0.0**. Versions
> 3.1.0–3.4.0 (below) were developed but **never published to pub.dev**; their features ship
> as part of 4.0.0. The entries are kept below for a complete history.

---

## 3.4.0

### Refetch-on-visible for screens that never unmount

* **`QueriesProvider` and `InfiniteQueriesProvider` now do remount detection** like `QueryProvider` /
  `InfiniteQueryProvider` — they call the controller's `handleRemount()` when their subtree's
  `TickerMode` flips back on. Since GoRouter's `StatefulShellRoute.indexedStack` wraps branches in
  `TickerMode(enabled: isActive)`, **returning to a kept-alive branch refetches automatically**
  (per `refetchOnMount`), with no extra widget. This is the recommended approach.
* **New: `handleRemount()` on `QueriesController` and `InfiniteQueriesController`** (it already existed
  on `QueryController` / `InfiniteQueryController`), refetching per the `refetchOnMount` policy
  (`always` / `stale` / `never`).
* **New: `RefetchOnVisible` widget** — the escape hatch for navigation that does **not** toggle
  `TickerMode` (a raw Flutter `IndexedStack`, a custom container): `RefetchOnVisible(active: …,
  onVisible: () => context.query<C>().handleRemount(), child: …)` fires `onVisible` on the
  hidden→visible edge using an `active` flag you supply. Refetch-on-mount itself is unchanged.
* Example: `example/lib/gorouter_example.dart` — a standalone `StatefulShellRoute` app showing the
  provider-level auto-refetch (run with `flutter run -t lib/gorouter_example.dart`).

## 3.3.0

### `InfiniteQueriesController` + app-lifecycle handling for polling

* **New: `InfiniteQueriesController<T, PageParam, F>`** — the `useQueries` analogue for infinite
  lists. One instance observes many filter-sets at once (state `Map<F, QueryState<List<T>>>`), each
  with independent pagination: `setFilters` / `addFilter` / `removeFilter`, `loadMore(F)`,
  `refetch(F)`, `invalidate(F)`, `hasMore(F)`, `stateFor(F)`, `updateItem(F, …)` / `removeItem(F, …)`.
  Internally it manages one `InfiniteQueryController` per filter-set, reusing all pagination logic.
  Ships with `InfiniteQueriesBuilder` and `InfiniteQueriesProvider`.
* **New: app-lifecycle handling for `refetchInterval`.** `Timer.periodic` is suspended while the app
  is backgrounded, so polling stops and data can go stale. A single `AppLifecycleCoordinator` (one
  `WidgetsBindingObserver` for the whole app, like the connectivity coordinator) now drives every
  controller: on background the interval pauses; on foreground it resumes **and** refetches per a new
  `refetchOnAppFocus` option (`always` / `ifStale` (default) / `never`) — the mobile analogue of
  TanStack's `refetchOnWindowFocus`. `refetchIntervalInBackground` (default `false`) keeps polling in
  the background. Applies to `QueryController`, `InfiniteQueryController`, and `QueriesController`
  (which also gains `refetchInterval` polling). New `QueryDefaults.refetchOnAppFocus` /
  `refetchIntervalInBackground`.
  * The interval is now **wall-clock aware**: `RefetchIntervalHandle` records the last tick time, so
    resuming after a background spell doesn't restart the countdown from zero. If a full interval
    already elapsed while backgrounded the poll fires **immediately** on resume (a 30-min poll
    backgrounded at 29 min and resumed 5 min later fetches at once); otherwise the next tick fires at
    the *remaining* time, preserving cadence.

## 3.2.0

### Modular client (SOLID) + a record-owned fetch engine with `QueriesController`

* **Refactored `QueryClient` into single-responsibility collaborators** under `lib/src/client/`
  (`QueryCacheStore`, `CacheChangeNotifier`, `StaleScheduler`, `GcScheduler`, `ObserverRegistry`,
  `ConnectivityCoordinator`, `cache_keys`). `QueryClient` is now a thin facade that delegates — no
  public API change, all existing tests pass unchanged.
* **New: a record-owned fetch engine.** `QueryClient.fetchQuery(...)` owns the fetch loop — retry,
  **in-flight dedup**, network gating, and status transitions — writing lifecycle to a per-`(key,
  params)` runtime record. Concurrent fetches for the same key **coalesce into one request**, and
  status becomes addressable by params.
* **New: `client.stateFor<T>(key, params)`** returns the full `QueryState` (data + status) for any
  param, so loading is readable per-param without a controller instance per param.
* **New: `QueriesController<T, P>`** — the `useQueries` analogue. One `Cubit<Map<P, QueryState<T>>>`
  observes a dynamic list of params, each with its own loading/data, fetches deduped and status
  shared via the engine. Kills the "one instance per param" boilerplate. Ships with a `QueriesBuilder`
  and a `QueriesProvider` (provide it like any bloc; reach it with `context.query<C>()`).
  `invalidateQueries` refetches every observed param (active-observer parity with TanStack).
  Typed, no-serialize helpers: `invalidate(P)`, `refetch(P)`, `addParam(P)` / `removeParam(P)`,
  `stateFor(P)`, `setData(P, data)` — params are serialized internally, never by the caller.
* The example **Cache Lab** "Live queries" grid now runs on a single `QueriesController` instead of
  four hand-managed controllers.

* **Changed: `invalidate` / `invalidateQueries` now KEEP the existing data** (TanStack semantics) —
  they mark the entry stale and background-refetch, and the current data stays visible (with a
  refetching/stale indicator) until fresh data arrives, instead of blanking to empty. New
  **`removeQueries(key, [params])`** performs the explicit hard-drop (what `invalidate` used to do);
  GC eviction and `clear()` still drop data.

Note: the classic `QueryController` / `InfiniteQueryController` are unchanged and still work; they do
not yet route their own fetches through the shared engine (so a `QueryController` and a
`QueriesController` on the same key won't share fetch-status/dedup — data still syncs via the cache).

## 3.1.0

### The QueryClient cache is now the single source of truth for data

Controllers no longer keep their own copy of `data`. Every `QueryController` /
`InfiniteQueryController` now derives `state.data` from the `QueryClient` cache, and
subscribes to a new cache-change signal so mounted controllers re-emit when the cache
changes underneath them. This removes the class of bugs where data lingered after the
cache was cleared or invalidated. **No compile-time breaking changes** — `QueryState`,
controller subclass contracts, providers, builders, consumers, selectors, and
`MutationController` are unchanged.

* **Fixed: stale data lingered after `clear()` / `invalidate()`.** Previously the cache
  was wiped but mounted controllers kept emitting their private copy of the old data. Now:
  * `client.clear()` sends every mounted controller's `state.data` to empty/idle (no
    refetch — the right behavior for logout/reset).
  * `invalidate()` / `invalidateQueries()` clear the entry and refetch active controllers
    (TanStack parity, unchanged behavior).
  * GC eviction empties the (by definition unobserved) entry.
* **New: cross-controller live sync.** Two controllers on the same `cacheKey` + params now
  reflect each other's writes immediately, instead of only on remount/refetch.
* **New: `client.update()` / `updateInfiniteQuery()` propagate immediately** to mounted
  controllers (previously they emitted nothing until the next read).
* **New: `QueryState.params`.** Builders/listeners/selectors can now read `state.params`
  (the params/filters that produced the data) alongside `state.data`, with a typed
  `state.paramsAs<P>()` accessor.
* **New: read cached data by typed params without a controller** — `client.getData<T>(key,
  params)` and the `context.queryData<T>(key, params)` extension serialize params for you.
  `serializeParams` is now exported.
* **New: param-scoped access on controllers** — `controller.dataFor([params])` (sync cache
  read) and `controller.fetchFor(params)` (non-invasive fetch for arbitrary params).
* **Changed: `InfiniteQueryController.refetch()` now replays all loaded pages** instead of
  collapsing back to page 1, preserving the user's scroll depth (TanStack parity). Page
  params are re-derived from freshly fetched pages, exactly like `useInfiniteQuery`.
* **Changed: `InfiniteQueryController.enabled` is now param-derived**, matching
  `QueryController`: always `true` for `void` filters, otherwise `true` only when filters
  are non-null (no fetch fires until filters are set).
* **New: `QueryDefaults.keepPreviousData`** — set the placeholder-on-param-change behavior
  globally instead of per controller (`null` defers to each controller's getter, which
  still defaults to `false`).

## 3.0.0

### Breaking changes

* **Replaced `connectivity_plus`/`internet_connection_checker_plus` with native connectivity detection.** `flutter_query_client` is now a genuine plugin with native Android (Kotlin) and iOS (Swift) implementations instead of depending on third-party connectivity packages. The online/offline status is derived the way production apps do it — the app's **own request outcomes are the primary source of truth**, an OS event provides an instant trigger, and a native TCP reachability probe is only a confirmation/tiebreaker (see the fixes below).
  * `QueryDefaults.connectivityEndpoints` and the re-exported `InternetCheckOption` type have been removed. In their place, **`QueryDefaults.connectivityProbeTargets`** (a `List<ProbeTarget>`) configures the confirmation probe — ideally pointed at **your own backend**, e.g. `connectivityProbeTargets: [ProbeTarget('api.myapp.com')]`. It defaults to Cloudflare's anycast anchors on **port 443** (HTTPS is allowed outbound on nearly every network — corporate firewalls, captive portals, and censored regions — whereas DNS port 53 is often blocked/hijacked).
  * The package now declares itself Android/iOS-only via `flutter.plugin.platforms`; consumers targeting web/macOS/Windows/Linux are no longer supported by this package.
  * New minimum platform requirements: Android API 24 (7.0) and iOS 12.0. Android requires the `INTERNET` permission (declared by the plugin) for the reachability probe.
* **Added `QueryClientProvider.onConnectivityChanged`** — a `void Function(ConnectivityStatus status)?` callback fired on every connectivity transition (both online→offline and offline→online), backed by the new native connectivity signal. Unlike the existing reconnect-refetch behavior (which only fires when coming back online), this fires in both directions so host apps can drive UI (e.g. an offline banner) directly from `QueryClientProvider`. `ConnectivityStatus` is an enum (`online`/`offline`, with an `isOnline` getter) rather than a `bool` so future states can be added without a breaking signature change.

### Fixes (native connectivity)

* **Fixed: disconnects not detected — neither an event nor a poll flipped the status offline.** Relying purely on the OS's route/validated signal (`NET_CAPABILITY_VALIDATED` / `NWPathMonitor.satisfied`) meant "connected but no real internet" — the normal way disconnects happen on emulators/simulators, dead routers, and captive portals — was reported as *online*. Since the observer only emits on a *change*, the native value never changed, so no stream event ever fired and `isOnline` never went offline even across polls. The fix restores real detection **and** makes it instant, the way production apps do it:
  * **Native `isConnected` is now an active reachability probe.** After a fast OS-route pre-check (short-circuit to offline when there is no route at all), both `FlutterQueryClientPlugin.kt` (Android, `Socket().connect(...)`) and `FlutterQueryClientPlugin.swift` (iOS, `NWConnection`) open a short-lived TCP connection to a reliable host with a ~1.5s timeout to confirm actual internet. Probes run off the platform thread so the UI is never blocked.
  * **The `flutter_query_client/connectivity/events` `EventChannel` is back — but wired race-free.** Native code emits a lightweight *hint* on every OS path change (Android `NetworkCallback`, iOS long-lived `NWPathMonitor`); the Dart side re-runs the probe the instant a hint arrives, so detection no longer waits for the next poll tick. Crucially, **the hint only ever triggers a fresh probe — it never carries authoritative state** — so the stale/reversed push events that broke the original event-driven design can no longer overwrite a correct value. The active probe is always the single source of truth.
  * **`NetworkConnectivityObserver` (Dart) reconciles both signals.** Hints are debounced (`hintDebounce`, default 250ms) to coalesce OS event bursts, polling drops to a battery-friendly backstop cadence (`pollInterval`, default 15s), and concurrent probes are ordered by a monotonic sequence so an out-of-order completion from a superseded probe can never set a stale value. Both intervals remain mutable for tests.
* **Request outcomes are now the primary connectivity signal — the way large apps actually detect it.** A hardcoded ping to a third-party IP is neither the most accurate nor the most robust signal (and can be blocked entirely in some regions). Instead:
  * **A successful query proves the device is online** and flips the status immediately (`QueryClient.reportReachable`, called by every controller on fetch success). This costs zero extra network traffic and *self-corrects a false offline* — e.g. when a probe anchor is unreachable in a region but the app's own API works fine.
  * **A query that fails with a network-type error never flips the status offline on its own** (`QueryClient.reportUnreachable` → confirmation probe only). This matters because in this package a confirmed `offline→online` transition triggers a refetch across *every* registered controller — so a lone server 500 or DNS blip must not be able to pause the whole app and then storm it back online. A confirmed success also cancels any pending confirmation probe, preventing flap.
  * The backstop probe is **skipped while recent successful traffic already proves reachability**, so an actively-used app does no redundant probing.

### Fixes

* **Fixed: `InfiniteQueryController` constructor races with an initial `setParams` call** — the constructor fires `_executeFirstPage()` unawaited, before any filters are set. If a consumer calls `setParams(...)` synchronously right after construction (the idiomatic place to apply initial filters, e.g. in `initState()`), the constructor's stale call could resume after `setParams` had already restored a `success` state from cache, and unconditionally overwrite it with `loading` — since that emit wasn't guarded by the `_filterVersion` check used everywhere else in the method. Because the version check only ran *after* the fetch completed, the eventual result was discarded and no state was ever emitted to correct the spurious `loading`, leaving the UI stuck indefinitely despite valid cached data. The `_filterVersion` guard is now checked immediately after the `await Future.delayed(Duration.zero)`, before the `loading` emit, matching the pattern already used in the cache-restore and paused branches above it.

---

## 2.0.2

### Fixes

* **Fixed: `StaleListenerHandle` memory leak for void-params queries** — `unregister()` had an extra `&& _listenedParams != null` guard that prevented cleanup when `params` was `null` (the common case for controllers with no params). Every parameterless controller leaked a stale callback on `unregister()`. Guard removed — only callback presence is checked now.

* **Fixed: `_refetchInternal` race condition** — params were read from `_serializedParams` after `await`, so a concurrent `setParams()` call could silently write results to the wrong cache key and emit state for a different query. Both controllers now capture `_serializedParams` before `await` and abort if it has changed after the fetch completes.

* **Fixed: `copyWith` stale fields bleeding across state transitions** — `QueryController._refetchInternal`, `InfiniteQueryController._executeFirstPage`, `InfiniteQueryController._refetchInternal`, and `MutationController.mutate` all used `state.copyWith(status: ...)` on the error path. Because Freezed's `copyWith` preserves unmentioned fields, previous `isPlaceholderData`, `error`, or `fetchStatus` values could bleed into the new error state. All error emits now use fresh `QueryState<T>(...)` constructors with every field set explicitly.

* **Fixed: `InfiniteQueryController.setParams` cache-hit not registering stale listener or refetch interval** — when `setParams` found a fresh cache hit it returned early without calling `_registerStaleListener()` or `_startRefetchInterval()`, so the stale callback and polling interval were never set up for the new params. Both are now called before the early return.

* **Fixed: `_shouldPause` evaluated eagerly in `_execute`** — `shouldAbort` was constructed as `_shouldPause ? () => true : null` (evaluated once at call time), so if the controller was paused *after* the network call started, the abort flag was invisible to the retry loop. Changed to `() => _shouldPause` (re-evaluated on each retry iteration).

* **Fixed: `ensureData` missing params staleness guard** — after the `await` in `ensureData`, `_serializedParams` was not rechecked, so a concurrent `setParams()` could cause stale data to be returned and emitted for the wrong params. Added the same capture-and-check pattern used in `_refetchInternal`.

* **Fixed: `QueryClient.clear()` not clearing `_staleCallbacks`** — `clear()` cancelled stale timers but left `_staleCallbacks` populated, so callbacks for already-cleared entries could fire if a timer somehow ran before cancellation, or persist as a memory leak for long-running apps that call `clear()` between sessions.

* **Fixed: `_onConnectivityChange` permanently removing throwing callbacks** — when a reconnect callback threw, it was caught and added to a pruning set, permanently unregistering a live controller's reconnect callback on the first transient error. Changed to log-and-continue; stale callbacks are handled at `unregisterReconnectCallback` time.

* **Fixed: `InfiniteQueryController.loadMore` error not resetting `fetchStatus` to `idle`** — on a `loadMore` failure, `fetchStatus` stayed as `fetching`, leaving the controller in a stuck state where the UI could never trigger another `loadMore` call. `fetchStatus: FetchStatus.idle` is now set explicitly in the error emit.

* **Fixed: `handleRemount` not restarting the refetch interval** — `handleRemount` called `_refetch()` but not `_startRefetchInterval()`, so polling stopped permanently after the first widget hide/show cycle. The interval is now restarted alongside the refetch. Note: `handleRemount` (and therefore `refetchOnMount`) has no effect when the controller's provider is mounted at the root level — root providers are never unmounted, so the hidden→visible transition never fires.

---

## 2.0.1

### Fixes

* **Fixed: original error lost after retry exhaustion** — `retryWithBackoff` was wrapping the user's error in a `QueryException('Operation failed after N attempt(s)')`, burying the original API/service error. `transformError`, `onMutationError`, `onQueryError`, and `state.error` all received the `QueryException` wrapper instead of the actual error thrown by `queryFn` or `mutationFn`. Now the original error is rethrown with its original stack trace after retries are exhausted, so it flows through the entire error pipeline unchanged. The `QueryException` abort case (network offline) is unaffected.

### Example

* Updated global `transformError` in `main.dart` to demonstrate the corrected pattern — checking for the app's `ApiException` type instead of `QueryException`
* Added **Error Handling** demo section to the Widgets showcase screen with a deliberately failing mutation that shows `state.error` value and type, proving the original error flows through `transformError` intact

---

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
