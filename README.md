# flutter_query_client

A [TanStack Query](https://tanstack.com/query)-inspired server state management library for Flutter.

Handles **fetching, caching, synchronizing, and updating** server state with minimal boilerplate — automatic background refetching, stale-while-revalidate caching, infinite pagination, and mutation support out of the box.

---

## Features

- **QueryController** — fetch and cache server data automatically
- **MutationController** — trigger user-driven mutations (create, update, delete)
- **InfiniteQueryController** — paginated / infinite-scroll data with `loadMore()`
- **Stale-while-revalidate** — serve cached data instantly, refetch in background
- **Configurable stale time & garbage collection** — control cache lifetime
- **Automatic retry with exponential backoff** — resilient to transient failures
- **Network-aware fetching** — pauses when offline, resumes on reconnect
- **Refetch on mount** — always, only if stale, or never
- **Keep previous data** - keeps previous data when fetching data
- **Global defaults** with per-controller overrides
- **BLoC-based state** — integrates naturally with `flutter_bloc`
- **Freezed immutable state** — safe pattern matching on `QueryState`

---

## Installation

```yaml
dependencies:
  flutter_query_client: ^1.0.1
```

---

## Quick Start

### 1. Wrap your app with `QueryClientProvider`

```dart
void main() {
  runApp(
    QueryClientProvider(
      defaults: QueryDefaults(
        staleTime: const Duration(minutes: 5),
        gcTime: const Duration(minutes: 10),
        retryCount: 3,
      ),
      child: const MyApp(),
    ),
  );
}
```

### 2. Define a `QueryController`

```dart
class PostsController extends QueryController<List<Post>, void> {
  PostsController() : super(baseKey: 'posts');

  @override
  Future<List<Post>> queryFn(void params) async {
    return postService.getPosts();
  }
}
```

### 3. Provide and consume it in your widget tree

```dart
QueryProvider<PostsController, List<Post>>(
  create: (_) => PostsController(),
  builder: (context, controller) {
    return QueryBuilder<PostsController, List<Post>>(
      controller: controller,
      builder: (context, state) {
        if (state.isLoading) return const CircularProgressIndicator();
        if (state.isError) return Text('Error: ${state.error}');
        return ListView(
          children: state.data!.map((p) => Text(p.title)).toList(),
        );
      },
    );
  },
);
```

---

## Core Concepts

### QueryState

Every controller exposes a `QueryState<T>`:

| Property | Description |
|---|---|
| `data` | The cached data (nullable) |
| `error` | The error (nullable) |
| `status` | `idle` / `loading` / `success` / `error` |
| `fetchStatus` | `idle` / `fetching` / `refetching` / `paused` |
| `isStale` | Whether data is past its stale time |
| `isLoading` | `status == loading` |
| `isSuccess` | `status == success` |
| `isError` | `status == error` |
| `isFetching` | Actively fetching (initial or background) |
| `isRefetching` | Background refetch with existing data |
| `isPaused` | Paused due to no network |
| `hasData` | `data != null` |
| `hasError` | `error != null` |

---

## QueryController

Use for any single-resource fetch (list, detail, etc.).

```dart
class PostByIdController extends QueryController<Post, int> {
  PostByIdController() : super(baseKey: 'posts');

  @override
  Future<Post> queryFn(int id) => postService.getPostById(id);
}

// Set params to trigger the fetch
controller.setParams(postId);

// Manually refetch
controller.refetch();

// Update cache directly (optimistic update)
controller.updateCache((current) => current.copyWith(title: 'New title'));

// Invalidate (marks stale + refetches if active)
controller.invalidate();
```

### Constructor options

```dart
QueryController({
  required String baseKey,
  Duration? staleTime,           // Default: from QueryDefaults
  Duration? gcTime,              // Default: from QueryDefaults
  int? retryCount,               // Default: 3
  Duration? retryDelay,          // Default: exponential backoff
  Duration? refetchInterval,     // Poll interval (null = disabled)
  RefetchOnMount refetchOnMount, // always | stale | never
  NetworkMode networkMode,       // online | always | offlineFirst
  RefetchOnReconnect refetchOnReconnect, // always | ifStale | never
})
```

---

## MutationController

Use for create / update / delete operations. Mutations do **not** auto-retry by default.

```dart
class CreatePostMutation extends MutationController<Post> {
  CreatePostMutation(this._client) : super(queryClient: _client);
  final QueryClient _client;

  @override
  Future<Post> mutationFn(dynamic params) async {
    final post = await postService.createPost(params as Map<String, dynamic>);
    // Invalidate the list to trigger a refetch
    _client.invalidate('posts');
    return post;
  }

  @override
  void onSuccess(Post data) {
    // Optimistically update the cache
    _client.update<List<Post>>('posts', null, (posts) => [data, ...posts!]);
  }
}
```

```dart
// Trigger the mutation
mutation.mutate({'title': 'Hello', 'body': 'World'});

// React to result with QueryListener
QueryListener<CreatePostMutation, Post>(
  controller: mutation,
  onSuccess: (post) => Navigator.pop(context),
  onError: (err) => showSnackBar(err.toString()),
  child: ...,
);
```

---

## InfiniteQueryController

Use for paginated or infinite-scroll data.

```dart
class ProductsController extends InfiniteQueryController<Product, int, String> {
  ProductsController() : super(baseKey: 'products', initialPageParam: 1);

  @override
  Future<List<Product>> queryFn(int page, String query) =>
      productService.getProducts(page: page, search: query);

  @override
  int? getNextPageParam(List<Product> lastPage, int currentPage) =>
      lastPage.length == 20 ? currentPage + 1 : null;
}
```

```dart
InfiniteQueryProvider<Product>(
  create: (_) => ProductsController(),
  builder: (context, controller) {
    return InfiniteQueryBuilder<ProductsController, Product, int, String>(
      controller: controller,
      builder: (context, state) {
        return ListView.builder(
          itemCount: state.data?.length ?? 0,
          itemBuilder: (_, i) => ProductTile(state.data![i]),
        );
      },
    );
  },
);

// Trigger next page
controller.loadMore();

// Check if more pages exist
controller.hasMore;
```

---

## QueryClient

The `QueryClient` is a singleton that manages the cache. Access it via `context`:

```dart
final client = QueryClientProvider.of(context).client;

// Invalidate a specific key (marks stale + refetches active controllers)
client.invalidate('posts');

// Invalidate all queries matching a prefix
client.invalidateQueries('posts');

// Update cached data directly
client.update<List<Post>>('posts', null, (posts) => [...posts!, newPost]);

// Read cached data
final cached = client.get<List<Post>>('posts', null);
```

---

## Global Configuration

Configure defaults once in `QueryClientProvider`:

```dart
QueryClientProvider(
  defaults: QueryDefaults(
    staleTime: const Duration(minutes: 5),
    gcTime: const Duration(minutes: 10),
    retryCount: 3,
    retryDelay: const Duration(seconds: 2),
    networkMode: NetworkMode.online,
    refetchOnReconnect: RefetchOnReconnect.ifStale,
    refetchOnMount: RefetchOnMount.stale,
    errorTransform: (error) => AppException.from(error),
    connectivityEndpoints: [
      InternetCheckOption(uri: Uri.parse('https://your-api.com/health')),
    ],
    enableLogging: true,
  ),
  child: const MyApp(),
),
```

---

## Network Modes

| Mode | Behaviour |
|---|---|
| `NetworkMode.online` | Pauses fetching when offline, resumes on reconnect |
| `NetworkMode.always` | Fetches regardless of network status |
| `NetworkMode.offlineFirst` | Fetches immediately, then pauses on error if offline |

---

## Widgets Reference

| Widget | Purpose |
|---|---|
| `QueryProvider<C, T>` | Provides a `QueryController` via `BlocProvider` |
| `InfiniteQueryProvider<T>` | Provides an `InfiniteQueryController` |
| `QueryBuilder<C, T>` | Rebuilds on every state change |
| `InfiniteQueryBuilder<C, T, P, Param>` | Builder for infinite queries |
| `QueryListener<C, T>` | Side effects without rebuilding |
| `MultiQueryListener` | Listen to multiple controllers at once |

---

## Example

A full example app demonstrating CRUD for Posts and infinite-scroll Products is available in the [`example/`](example/) directory.

---

