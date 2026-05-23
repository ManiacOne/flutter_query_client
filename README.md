# flutter_query_client

A [TanStack Query](https://tanstack.com/query)-inspired server state management library for Flutter.

Handles **fetching, caching, synchronizing, and updating** server state with minimal boilerplate — automatic background refetching, stale-while-revalidate caching, infinite pagination, mutation support, and a rich widget layer out of the box.

---

## Features

- **QueryController** — fetch and cache server data automatically
- **MutationController** — user-triggered mutations; emits `QueryState` so all Query\* widgets work with it
- **InfiniteQueryController** — paginated / infinite-scroll data with `loadMore()`
- **Stale-while-revalidate** — serve cached data instantly, refetch in background
- **Configurable stale time & garbage collection** — control cache lifetime precisely
- **Automatic retry with exponential backoff** — resilient to transient failures
- **Network-aware fetching** — pauses when offline, resumes on reconnect
- **`keepPreviousData`** — show old results while fetching new ones after `setParams()`
- **Global defaults** with per-controller overrides
- **BLoC-based state** — integrates naturally with `flutter_bloc`; observe all controllers via `QueryObserver` set in `QueryClientProvider`
- **Freezed immutable state** — safe pattern matching on `QueryState`

---

## Installation

```yaml
dependencies:
  flutter_query_client: ^2.0.0
```

---

## Quick Start

### 1. Wrap your app

```dart
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      defaults: const QueryDefaults(
        staleTime: Duration(minutes: 5),
        gcTime: Duration(minutes: 10),
        retryCount: 3,
      ),
      // Optional: attach a global observer (no flutter_bloc import needed).
      observer: AppQueryObserver(),
      child: const MaterialApp(home: HomeScreen()),
    );
  }
}
```

### 2. Define a controller

```dart
class PostsController extends QueryController<List<Post>, void> {
  PostsController() : super('posts');

  @override
  Future<List<Post>> queryFn(void params) => postService.getPosts();
}
```

### 3. Provide and build

```dart
QueryProvider<PostsController, List<Post>>(
  create: (_) => PostsController(),
  child: QueryBuilder<PostsController, List<Post>>(
    builder: (context, state) {
      if (state.isLoading) return const CircularProgressIndicator();
      if (state.isError)   return Text('Error: ${state.error}');
      return PostListView(posts: state.data!);
    },
  ),
),
```

---

## Core Concepts

### QueryState

Every controller emits `QueryState<T>`:

| Property | Type | Description |
|---|---|---|
| `data` | `T?` | The cached data |
| `error` | `Object?` | The last error |
| `status` | `QueryStatus` | `idle` · `loading` · `success` · `error` |
| `fetchStatus` | `FetchStatus` | `idle` · `fetching` · `refetching` · `paused` |
| `isStale` | `bool` | Data is past its stale time |
| `isPlaceholderData` | `bool` | Showing previous data during a `setParams()` fetch |
| `isLoadingMore` | `bool` | Infinite query is fetching the next page |
| `isLoading` | `bool` | `status == loading` |
| `isSuccess` | `bool` | `status == success` |
| `isError` | `bool` | `status == error` |
| `isIdle` | `bool` | `status == idle` |
| `isFetching` | `bool` | Any active background fetch |
| `isRefetching` | `bool` | Background refetch with data already present |
| `isPaused` | `bool` | Fetch paused (offline) |
| `hasData` | `bool` | `data != null` |
| `hasError` | `bool` | `error != null` |

---

## Widget Reference

### Provider Widgets

| Widget | Purpose |
|---|---|
| `QueryProvider<C, T>` | Provides a `QueryController` or `MutationController` via `BlocProvider`; handles remount |
| `InfiniteQueryProvider<C>` | Provides an `InfiniteQueryController`; handles remount |
| `MultiQueryProvider` | Nest multiple providers without indentation |
| `QueryClientProvider` | Inject `QueryClient` + global `QueryDefaults` into the tree |

### Builder / Listener Widgets

| Widget | Purpose |
|---|---|
| `QueryBuilder<C, T>` | Rebuild on `QueryState<T>` changes |
| `InfiniteQueryBuilder<C, T>` | Rebuild on `QueryState<List<T>>` changes |
| `QueryListener<C, T>` | Side-effects on `QueryState<T>` changes — no rebuild |
| `InfiniteQueryListener<C, T>` | Side-effects on `QueryState<List<T>>` — no `List<T>` in type arg |
| `MultiQueryListener` | Multiple `QueryListener`s without extra widget layers |

### Consumer Widgets (builder + listener combined)

| Widget | Purpose |
|---|---|
| `QueryConsumer<C, T>` | `QueryBuilder` + `QueryListener` in one widget |
| `InfiniteQueryConsumer<C, T>` | Same for infinite queries; `List<T>` baked in |

### Selector Widgets (minimal rebuilds)

| Widget | Purpose |
|---|---|
| `QuerySelector<C, T, S>` | Rebuilds only when a derived value `S` changes |
| `InfiniteQuerySelector<C, T, S>` | Same for infinite queries; `List<T>` baked in |

> **Tip — mutations use the same widgets.** `MutationController<T>` emits `QueryState<T>`, so `QueryBuilder`, `QueryListener`, `QueryConsumer`, and `QuerySelector` all work with mutations out of the box.

---

## Provider Widgets

### `QueryProvider`

```dart
QueryProvider<PostsController, List<Post>>(
  create: (_) => PostsController(),
  child: const PostsListView(),
)
```

Automatically calls `controller.handleRemount()` when a widget transitions from hidden → visible (e.g. inside `IndexedStack` or `Visibility`).

### `InfiniteQueryProvider`

```dart
InfiniteQueryProvider<ProductsController>(
  create: (_) => ProductsController(),
  child: const ProductsView(),
)
```

### `MultiQueryProvider`

Provide multiple controllers without deep nesting — identical ergonomics to `MultiBlocProvider`. Pass each provider without a `child`; `MultiQueryProvider` injects it automatically. Providers are applied top-to-bottom (first entry = outermost ancestor).

```dart
MultiQueryProvider(
  providers: [
    QueryProvider<PostsController, List<Post>>(
      create: (_) => PostsController(),
    ),
    QueryProvider<CreatePostMutation, Post>(
      create: (_) => CreatePostMutation(),
    ),
    InfiniteQueryProvider<ProductsController>(
      create: (_) => ProductsController(),
    ),
  ],
  child: const HomeScreen(),
)
```

---

## Builder Widgets

### `QueryBuilder`

```dart
QueryBuilder<PostsController, List<Post>>(
  buildWhen: (prev, next) => prev.status != next.status,
  builder: (context, state) {
    if (state.isLoading)    return const CircularProgressIndicator();
    if (state.isError)      return ErrorView(error: state.error);
    if (state.isRefetching) return PostsView(posts: state.data!, loading: true);
    return PostsView(posts: state.data ?? []);
  },
)
```

### `InfiniteQueryBuilder`

```dart
InfiniteQueryBuilder<ProductsController, Product>(
  builder: (context, state) {
    final products = state.data ?? [];
    return ListView.builder(
      itemCount: products.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= products.length) return const LoadingTile();
        return ProductTile(products[i]);
      },
    );
  },
)
```

---

## Listener Widgets

### `QueryListener`

Side-effects only — no rebuild. Works with both query and mutation controllers.

```dart
QueryListener<PostsController, List<Post>>(
  listenWhen: (prev, next) => !prev.isError && next.isError,
  listener: (context, state) => showErrorSnackBar(state.error),
  child: const PostsView(),
)

// With a MutationController
QueryListener<CreatePostMutation, Post>(
  listenWhen: (_, next) => next.isSuccess || next.isError,
  listener: (context, state) {
    if (state.isSuccess) Navigator.pop(context, state.data);
    if (state.isError)   showErrorSnackBar(state.error);
  },
  child: const CreatePostForm(),
)
```

### `InfiniteQueryListener`

Identical to `QueryListener` for infinite queries — the `List<T>` wrapper is baked into the type so you only specify the item type:

```dart
// Before (verbose)
QueryListener<ProductsController, List<Product>>(...)

// After
InfiniteQueryListener<ProductsController, Product>(
  listenWhen: (prev, next) => prev.isLoadingMore && !next.isLoadingMore,
  listener: (context, state) {
    if (state.isError) showErrorSnackBar('Failed to load more');
  },
  child: const ProductsView(),
)
```

### `MultiQueryListener`

Attach multiple listeners without extra widget layers:

```dart
MultiQueryListener(
  listeners: [
    QueryListener<PostsController, List<Post>>(
      listenWhen: (_, next) => next.isError,
      listener: (context, state) => showErrorSnackBar(state.error),
    ),
    QueryListener<CreatePostMutation, Post>(
      listenWhen: (_, next) => next.isSuccess || next.isError,
      listener: (context, state) { /* handle mutation result */ },
    ),
  ],
  child: const HomeScreen(),
)
```

---

## Consumer Widgets

Combine builder + listener without nesting — useful when you need both a reactive UI and a side-effect on the same controller.

### `QueryConsumer`

```dart
QueryConsumer<PostsController, List<Post>>(
  listenWhen: (_, next) => next.isError,
  listener: (context, state) => showErrorSnackBar(state.error),
  buildWhen: (prev, next) => prev.data != next.data,
  builder: (context, state) {
    if (state.isLoading) return const CircularProgressIndicator();
    return PostsView(posts: state.data ?? []);
  },
)

// With a MutationController
QueryConsumer<CreatePostMutation, Post>(
  listenWhen: (_, next) => next.isSuccess,
  listener: (context, state) => Navigator.pop(context, state.data),
  builder: (context, state) => FilledButton(
    onPressed: state.isLoading ? null : _submit,
    child: state.isLoading
        ? const CircularProgressIndicator()
        : const Text('Submit'),
  ),
)
```

### `InfiniteQueryConsumer`

```dart
InfiniteQueryConsumer<ProductsController, Product>(
  listenWhen: (prev, next) => prev.isLoadingMore && !next.isLoadingMore && next.isError,
  listener: (context, state) => showErrorSnackBar('Failed to load more'),
  builder: (context, state) {
    final products = state.data ?? [];
    if (state.isLoading) return const CircularProgressIndicator();
    return ProductsView(products: products, isLoadingMore: state.isLoadingMore);
  },
)
```

---

## Selector Widgets

Rebuilds **only** when the selected value changes — use for badges, counters, or flags that don't need the full state.

### `QuerySelector`

```dart
// Only rebuilds when post count changes — ignores refetch/stale events.
QuerySelector<PostsController, List<Post>, int>(
  selector: (state) => state.data?.length ?? 0,
  builder: (context, count) => Badge(label: Text('$count')),
)

// Only rebuilds when the mutation's loading flag toggles.
QuerySelector<CreatePostMutation, Post, bool>(
  selector: (state) => state.isLoading,
  builder: (context, isLoading) => FilledButton(
    onPressed: isLoading ? null : _submit,
    child: const Text('Submit'),
  ),
)
```

### `InfiniteQuerySelector`

```dart
// Only rebuilds when total item count changes.
InfiniteQuerySelector<ProductsController, Product, int>(
  selector: (state) => state.data?.length ?? 0,
  builder: (context, count) => Text('$count items loaded'),
)
```

---

## QueryController

Base class for any single-resource fetch.

```dart
class PostByIdController extends QueryController<Post, int> {
  PostByIdController() : super('post');

  // Optional overrides
  @override Duration? get staleTime => const Duration(seconds: 30);
  @override int get retryCount => 1;
  @override RefetchOnMount get refetchOnMount => RefetchOnMount.always;

  @override
  Future<Post> queryFn(int? id) => postService.getPostById(id!);

  // Lifecycle hooks
  @override void onSuccess(Post data) { /* analytics, logging */ }
  @override void onQueryError(Object error) { /* report error */ }
}
```

### Key methods

```dart
// Trigger the query (or re-trigger with new params)
controller.setParams(postId);

// Manual refetch
controller.refetch();

// Get or fetch data imperatively (returns cached if fresh)
final post = await controller.ensureData(postId);

// Optimistic cache update
controller.updateCache((current) => current?.copyWith(title: 'New title'));

// Invalidate — marks stale and refetches if active
controller.invalidate();
```

### Override contract

| Override | Default | Purpose |
|---|---|---|
| `queryFn(P? params)` | — | **Required.** The fetch function |
| `enabled` | auto | `false` prevents execution (auto: false when P ≠ void and params == null) |
| `staleTime` | `null` | Duration until data is considered stale (`null` = never) |
| `refetchInterval` | `null` | Auto-poll interval (`null` = disabled) |
| `refetchOnMount` | `always` | `always` · `stale` · `never` |
| `refetchOnReconnect` | `ifStale` | `always` · `ifStale` · `never` |
| `networkMode` | `online` | `online` · `always` · `offlineFirst` |
| `retryCount` | `3` | Retry attempts on failure |
| `retryDelay` | `1s` | Base delay; actual uses exponential backoff |
| `keepPreviousData` | `false` | Show old data during `setParams()` refetch |
| `onSuccess(T data)` | no-op | Called after successful fetch |
| `onQueryError(Object e)` | no-op | Called after all retries fail |

---

## InfiniteQueryController

For cursor- or page-based pagination. `T` = item type, `PageParam` = page parameter type, `P` = filter type (`void` if no filters).

`initialPageParam` and `limit` are optional — they inherit from `QueryDefaults` (`0` and `20` by default) and only need to be overridden when a controller differs from the global setting.

```dart
// Minimal — initialPageParam and limit come from QueryDefaults.
class ProductsController extends InfiniteQueryController<Product, int, String> {
  ProductsController() : super('products');

  @override bool get keepPreviousData => true;

  @override
  int? getNextPageParam(List<Product> lastPage, List<List<Product>> allPages) =>
      lastPage.length < limit ? null : allPages.length;

  @override
  Future<List<Product>> queryFn(int pageParam, String? query) =>
      productService.getProducts(page: pageParam, search: query ?? '');
}

// Override only when this controller differs from the global default.
class CursorProductsController extends InfiniteQueryController<Product, String, void> {
  CursorProductsController() : super('cursor-products');

  @override String get initialPageParam => '';   // cursor, not an int
  @override int    get limit           => 10;    // smaller page size

  @override
  String? getNextPageParam(List<Product> last, List<List<Product>> all) =>
      last.isEmpty ? null : last.last.cursor;

  @override
  Future<List<Product>> queryFn(String cursor, void _) =>
      productService.getProductsAfter(cursor, limit: limit);
}
```

### Key methods

```dart
// Trigger next page
await controller.loadMore();

// Apply new filter params — resets pagination and refetches
controller.setParams('running shoes');

// Refetch from page 0
controller.refetch();

// Invalidate and reset
controller.invalidateAndRefresh();

// Optimistic item updates across all pages
controller.updateItem((p) => p.id == updated.id, updated);
controller.removeItem((p) => p.id == deletedId);
controller.prependItem(newItem);
controller.appendItem(newItem);
```

### Key getters

```dart
controller.hasMore      // bool — whether getNextPageParam returns non-null
controller.currentPage  // int — number of pages loaded
controller.totalItems   // int — flat item count across all pages
controller.filters      // P?  — current filter params
```

---

## MutationController

For create / update / delete operations. Takes a typed params generic `P` matching `QueryController<T, P>`. Override `mutationFn(P params)` — no closures needed. Mutations emit `QueryState<T>`, so every Query\* widget works with them out of the box.

```dart
// Define a record typedef for the params (Dart 3 named records work well).
typedef CreatePostParams = ({int userId, String title, String body});

class CreatePostMutation extends MutationController<Post, CreatePostParams> {
  @override
  Future<Post> mutationFn(CreatePostParams params) {
    return postService.createPost(
      userId: params.userId,
      title: params.title,
      body: params.body,
    );
  }

  @override
  void onSuccess(Post data) => QueryLogger.info('Created: ${data.id}');

  @override
  void onMutationError(Object error) => QueryLogger.warning('Failed: $error');

  @override
  void onSettled(Post? data, Object? error) { /* always called */ }
}

// For mutations that need no params, use void as the second type argument.
class DeletePostMutation extends MutationController<bool, int> {
  @override
  Future<bool> mutationFn(int id) async {
    await postService.deletePost(id);
    return true;
  }
}
```

```dart
// Provide like a QueryController
QueryProvider<CreatePostMutation, Post>(
  create: (_) => CreatePostMutation(),
  child: const CreatePostForm(),
)

// Trigger with typed named-record params
context.query<CreatePostMutation>().mutate((
  userId: 1,
  title: 'Hello',
  body: 'World',
));

// Reset state to idle
context.query<CreatePostMutation>().reset();

// Use standard query widgets — mutations emit QueryState<T>
QueryConsumer<CreatePostMutation, Post>(
  listenWhen: (_, next) => next.isSuccess || next.isError,
  listener: (context, state) { /* navigate / show toast */ },
  builder: (context, state) => FilledButton(
    onPressed: state.isLoading ? null : _submit,
    child: state.isLoading
        ? const CircularProgressIndicator()
        : const Text('Create'),
  ),
)
```

### Override contract

| Override | Default | Purpose |
|---|---|---|
| `mutationFn(P params)` | — | **Required.** The mutation function; receives typed params |
| `retryCount` | `0` | Global `retryCount` intentionally not applied to mutations |
| `onSuccess(T data)` | no-op | Called after mutation succeeds |
| `onMutationError(Object e)` | no-op | Called after mutation fails |
| `onSettled(T? data, Object? error)` | no-op | Always called after settle |

---

## QueryClient

Singleton cache manager. Access via `QueryClient.instance` or `context.queryClient`.

```dart
final client = QueryClient.instance;

// Invalidate a specific key + params (removes from cache)
client.invalidate('posts', serializedParams);

// Invalidate all param variants for a key and notify active controllers
client.invalidateQueries(['posts', 'products']);

// Update cached data for all param variants of a key
client.update<List<Post>>('posts', (posts) => [newPost, ...posts]);

// Update infinite query pages
client.updateInfiniteQuery<Product>('products', (pages) => pages);

// Direct cache access
final cached = client.get<List<Post>>('posts');

// Register a global observer (prefer QueryClientProvider(observer:) at startup)
client.setObserver(AppQueryObserver());

// Set global defaults
client.setDefaults(const QueryDefaults(staleTime: Duration(minutes: 5)));
```

### BuildContext extensions

```dart
// Get a controller from the widget tree
final ctrl = context.query<PostsController>();

// Get the QueryClient
final client = context.queryClient;

// Read cached data directly
final posts = context.cachedQuery<List<Post>>('posts');
final post  = context.cachedQueryWithParams<Post>('post', serializedId);
```

---

## QueryObserver

A `BlocObserver` subclass that filters events to query and mutation controllers only, exposing typed hooks. Pass it to `QueryClientProvider` alongside your other global defaults — no direct `flutter_bloc` import needed in your app.

```dart
QueryClientProvider(
  defaults: const QueryDefaults(...),
  observer: AppQueryObserver(),   // ← registered here, alongside defaults
  child: const MyApp(),
)

class AppQueryObserver extends QueryObserver {
  /// Called when any QueryController, InfiniteQueryController,
  /// or MutationController is created.
  @override
  void onQueryCreate(String cacheKey) =>
      debugPrint('created: $cacheKey');

  /// currentState + nextState — same semantics as BlocObserver.onChange.
  @override
  void onQueryChange(
    String cacheKey,
    QueryState<dynamic> currentState,
    QueryState<dynamic> nextState,
  ) {
    debugPrint(
      '[$cacheKey] ${currentState.status.name} → ${nextState.status.name}',
    );
  }

  @override
  void onQueryError(String cacheKey, Object error, StackTrace stackTrace) =>
      FirebaseCrashlytics.instance.recordError(error, stackTrace);

  @override
  void onQueryClose(String cacheKey) =>
      debugPrint('closed: $cacheKey');
}
```

To also observe non-query cubits, override the raw `BlocObserver` hooks and call `super`:

```dart
@override
void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
  super.onChange(bloc, change); // ← fires onQueryChange for query controllers
  if (bloc is MyOtherCubit) { /* handle */ }
}
```

---

## Global Configuration

All global setup lives in a single `QueryClientProvider`:

```dart
QueryClientProvider(
  client: QueryClient.instance,       // optional — defaults to singleton
  observer: AppQueryObserver(),       // optional — global lifecycle observer
  defaults: QueryDefaults(
    staleTime: const Duration(minutes: 5),
    gcTime: const Duration(minutes: 10),
    retryCount: 3,
    retryDelay: const Duration(seconds: 1),
    refetchOnMount: RefetchOnMount.stale,
    refetchOnReconnect: RefetchOnReconnect.ifStale,
    networkMode: NetworkMode.online,
    refetchInterval: null,
    // Infinite query defaults — applied to every InfiniteQueryController
    // that doesn't override them individually.
    initialPageParam: 0,              // first page param (default: 0)
    limit: 20,                        // items per page (default: 20)
    transformError: (error) => AppException.from(error),
    connectivityEndpoints: [
      InternetCheckOption(uri: Uri.parse('https://api.example.com/health')),
    ],
    enableLogging: true,
    logLevel: Level.INFO,
  ),
  child: const MyApp(),
)
```

All `QueryDefaults` values apply globally but are overridable on each controller.

---

## Network Modes

| Mode | Behaviour |
|---|---|
| `NetworkMode.online` | Pauses fetching when offline, resumes on reconnect |
| `NetworkMode.always` | Fetches regardless of network status |
| `NetworkMode.offlineFirst` | Executes once without network check, then requires connectivity |

---

## Logging

```dart
// Enable via QueryDefaults
QueryDefaults(enableLogging: true, logLevel: Level.FINE)

// Or directly
QueryLogger.enable(level: Level.INFO, onLog: (record) => Sentry.addBreadcrumb(...));
QueryLogger.disable();
```

---

## Example

A full example app demonstrating all features is in the [`example/`](example/) directory:

- **Posts tab** — `QueryController`, `QueryBuilder`, `MutationController<T, P>` typed params, `QueryClient.instance.update` cache patching from mutation listeners, background polling, offline support
- **Products tab** — `InfiniteQueryController`, `setParams()` live search, `loadMore()` on scroll, `keepPreviousData`, `updateInfiniteQuery` + `prependItem` after create, optimistic item removal
- **Widgets tab** — live showcase of every widget: `MultiQueryProvider`, `QueryConsumer`, `QuerySelector`, `InfiniteQueryListener`, `InfiniteQueryConsumer`, `InfiniteQuerySelector`, `MultiQueryListener`, `QueryObserver`, and using mutation controllers with all Query\* widgets
- **Issues tab** — interactive before/after benchmarks for all v2.0.0 performance and memory optimizations; detailed documentation in [`example/lib/features/inefficiency_demos/OPTIMIZATIONS.md`](example/lib/features/inefficiency_demos/OPTIMIZATIONS.md)
