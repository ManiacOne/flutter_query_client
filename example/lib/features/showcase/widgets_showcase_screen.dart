import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../app_navigation.dart';
import '../../core/api_client.dart';
import '../../shared.dart';
import '../posts/post_controllers.dart';
import '../posts/post_model.dart';
import '../products/product_controllers.dart';
import '../products/product_model.dart';

// Features demonstrated on this screen:
//  • MultiQueryProvider      — nest multiple controllers without deep indentation
//  • QueryConsumer           — builder + listener in a single widget
//  • QuerySelector           — rebuild only when a derived value changes
//  • QueryListener           — side-effect listener alongside a builder
//  • QueryBuilder            — with MutationController (mutations emit QueryState)
//  • QueryListener           — with MutationController
//  • QueryConsumer           — with MutationController
//  • InfiniteQueryListener   — no List<T> in type args
//  • InfiniteQuerySelector   — minimal rebuilds for infinite queries
//  • InfiniteQueryConsumer   — builder + listener for infinite queries
//  • MultiQueryListener      — multiple listeners in one widget
//  • QueryObserver           — extends BlocObserver, zero extra dep in app
//  • Error handling          — original errors flow through transformError

class WidgetsShowcaseScreen extends StatelessWidget {
  const WidgetsShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ── MultiQueryProvider: provide PostsQueryController + CreatePostMutation ──
    // Both controllers are available to the entire screen tree.
    return MultiQueryProvider(
      providers: [
        QueryProvider(create: (_) => PostsQueryController()),
        QueryProvider(create: (_) => CreatePostMutation()),
        QueryProvider(create: (_) => _FailingMutation()),
        InfiniteQueryProvider(create: (_) => ProductsInfiniteController()),
      ],
      // ── MultiQueryListener: attach two side-effect listeners ─────
      // One for the query, one for the mutation — both run without
      // adding any widget between them and their controllers.
      child: MultiQueryListener(
        listeners: [
          QueryListener<PostsQueryController, List<Post>>(
            listenWhen: (prev, next) => prev.isError != next.isError,
            listener: (context, state) {
              if (state.isError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '[MultiQueryListener] Posts error: ${state.error}',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
          ),
          QueryListener<CreatePostMutation, Post>(
            listenWhen: (_, next) => next.isSuccess || next.isError,
            listener: (context, state) {
              final msg =
                  state.isSuccess
                      ? '[MultiQueryListener] Mutation succeeded!'
                      : '[MultiQueryListener] Mutation failed';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor:
                      state.isSuccess
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.error,
                ),
              );
            },
          ),
        ],
        child: Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(title: const Text('Widget Showcase')),
          body: _ShowcaseBody(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────

class _ShowcaseBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Feature banner ──────────────────────────────────────────
        FeatureBanner(
          features: [
            const FeatureItem(
              Icons.layers,
              'MultiQueryProvider',
              Colors.indigo,
            ),
            const FeatureItem(Icons.merge, 'QueryConsumer', Colors.teal),
            const FeatureItem(Icons.ads_click, 'QuerySelector', Colors.purple),
            const FeatureItem(Icons.hearing, 'QueryListener', Colors.blue),
            const FeatureItem(
              Icons.all_inclusive,
              'InfiniteQuery*',
              Colors.green,
            ),
            const FeatureItem(
              Icons.queue_music,
              'MultiQueryListener',
              Colors.orange,
            ),
            const FeatureItem(Icons.monitor_heart, 'QueryObserver', Colors.red),
          ],
        ),

        // ── 1. MultiQueryProvider ───────────────────────────────────
        _SectionHeader(
          label: 'MultiQueryProvider',
          description:
              'Provide multiple controllers without nested indentation. '
              'This entire screen is wrapped in one.',
        ),
        _DemoCard(
          widgetName: 'MultiQueryProvider',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CodeLabel('''
MultiQueryProvider(
  providers: [
    QueryProvider(
      create: (_) => PostsController(),
    ),
    QueryProvider(
      create: (_) => CreatePostMutation(),
    ),
    InfiniteQueryProvider(
      create: (_) => ProductsController(),
    ),
  ],
  child: MyScreen(),
)'''),
              const SizedBox(height: 10),
              // Show both controllers are live via their status badges
              Row(
                children: [
                  QuerySelector<PostsQueryController, List<Post>, QueryStatus>(
                    selector: (s) => s.status,
                    builder:
                        (context, status) => _StatusBadge(
                          label: 'PostsQueryController',
                          status: status,
                          color: Colors.indigo,
                        ),
                  ),
                  const SizedBox(width: 8),
                  QuerySelector<CreatePostMutation, Post, QueryStatus>(
                    selector: (s) => s.status,
                    builder:
                        (context, status) => _StatusBadge(
                          label: 'CreatePostMutation',
                          status: status,
                          color: Colors.teal,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 2. QueryConsumer ────────────────────────────────────────
        _SectionHeader(
          label: 'QueryConsumer',
          description:
              'Combines QueryBuilder + QueryListener in one widget. '
              'No nesting needed for side-effect + UI in the same place.',
        ),
        _DemoCard(
          widgetName: 'QueryConsumer<PostsQueryController, List<Post>>',
          child: QueryConsumer<PostsQueryController, List<Post>>(
            listenWhen: (prev, next) => prev.isSuccess != next.isSuccess,
            listener: (context, state) {
              if (state.isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '[QueryConsumer] Posts loaded: ${state.data!.length} items',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
            buildWhen:
                (prev, next) =>
                    prev.status != next.status ||
                    prev.data?.length != next.data?.length,
            builder: (context, state) => _QueryStatusRow(state: state),
          ),
        ),

        // ── 3. QuerySelector ────────────────────────────────────────
        _SectionHeader(
          label: 'QuerySelector',
          description:
              'Rebuilds ONLY when the selected value changes — ideal for '
              'counters, flags, or any derived property.',
        ),
        _DemoCard(
          widgetName: 'QuerySelector<PostsQueryController, List<Post>, int>',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selects only the item count — ignores refetch/stale state changes.
              QuerySelector<PostsQueryController, List<Post>, int>(
                selector: (state) => state.data?.length ?? 0,
                builder:
                    (context, count) => _CountBadge(
                      label: 'Post count',
                      count: count,
                      color: Colors.indigo,
                    ),
              ),
              const SizedBox(height: 8),
              // Selects only isStale — rebuilds only when staleness toggles.
              QuerySelector<PostsQueryController, List<Post>, bool>(
                selector: (state) => state.isStale,
                builder:
                    (context, isStale) =>
                        _BoolBadge(label: 'isStale', value: isStale),
              ),
            ],
          ),
        ),

        // ── 4. QueryListener (explicit, standalone) ─────────────────
        _SectionHeader(
          label: 'QueryListener  (standalone)',
          description:
              'A pure side-effect listener. No UI rebuilt — just fires '
              'the callback when the condition matches.',
        ),
        _DemoCard(
          widgetName: 'QueryListener<PostsQueryController, List<Post>>',
          child: QueryListener<PostsQueryController, List<Post>>(
            listenWhen:
                (prev, next) =>
                    prev.fetchStatus != next.fetchStatus && next.isRefetching,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('[QueryListener] Background refetch started'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: QueryBuilder<PostsQueryController, List<Post>>(
              buildWhen:
                  (prev, next) =>
                      prev.fetchStatus != next.fetchStatus ||
                      prev.data?.length != next.data?.length,
              builder:
                  (context, state) => Column(
                    children: [
                      _QueryStatusRow(state: state),
                      const SizedBox(height: 6),
                      Text(
                        'Tap refresh on Posts tab to trigger a refetch snackbar.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),

        // ── 5. MutationController + QueryBuilder ────────────────────
        _SectionHeader(
          label: 'MutationController + QueryBuilder',
          description:
              'MutationController emits QueryState — so QueryBuilder, '
              'QueryListener, QueryConsumer, and QuerySelector all work with '
              'mutations out of the box. No MutationBuilder needed.',
        ),
        _DemoCard(
          widgetName: 'QueryBuilder<CreatePostMutation, Post>',
          child: QueryBuilder<CreatePostMutation, Post>(
            builder: (context, state) {
              final mutation = context.query<CreatePostMutation>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MutationPhaseBar(
                    isLoading: state.isLoading,
                    isSuccess: state.isSuccess,
                    isError: state.isError,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed:
                        state.isLoading
                            ? null
                            : () => mutation.mutate((
                              userId: 1,
                              title: 'Test post from Showcase',
                              body: 'Created via QueryBuilder demo',
                            )),
                    icon:
                        state.isLoading
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.send, size: 16),
                    label: Text(
                      state.isLoading ? 'Creating…' : 'Create test post',
                    ),
                  ),
                  if (state.isSuccess)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Created: "${state.data?.title}" (id: ${state.data?.id})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // ── 6. MutationController + QueryListener ───────────────────
        _DemoCard(
          widgetName: 'QueryListener<CreatePostMutation, Post>',
          child: QueryListener<CreatePostMutation, Post>(
            listenWhen: (_, next) => next.isSuccess || next.isError,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.isSuccess
                        ? '[QueryListener] Mutation succeeded — id: ${state.data?.id}'
                        : '[QueryListener] Mutation failed: ${state.error}',
                  ),
                  backgroundColor:
                      state.isSuccess
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const _MutationStateInfo(),
          ),
        ),

        // ── 7. MutationController + QueryConsumer ───────────────────
        _DemoCard(
          widgetName: 'QueryConsumer<CreatePostMutation, Post>',
          child: QueryConsumer<CreatePostMutation, Post>(
            listenWhen: (_, next) => next.isSuccess,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '[QueryConsumer] Mutation success — reset in 3 s (id: ${state.data?.id})',
                  ),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            },
            builder: (context, state) {
              final mutation = context.query<CreatePostMutation>();
              return Row(
                children: [
                  Expanded(child: _QueryStatusRow(state: state)),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: state.isIdle ? null : mutation.reset,
                    child: const Text('Reset'),
                  ),
                ],
              );
            },
          ),
        ),

        // ── 8. MutationController + QuerySelector ───────────────────
        _DemoCard(
          widgetName: 'QuerySelector<CreatePostMutation, Post, bool>',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Each selector rebuilds independently — only when its '
                'selected slice of state changes:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              QuerySelector<CreatePostMutation, Post, bool>(
                selector: (s) => s.isLoading,
                builder:
                    (context, isLoading) =>
                        _BoolBadge(label: 'isLoading', value: isLoading),
              ),
              const SizedBox(height: 4),
              QuerySelector<CreatePostMutation, Post, bool>(
                selector: (s) => s.isSuccess,
                builder:
                    (context, isSuccess) =>
                        _BoolBadge(label: 'isSuccess', value: isSuccess),
              ),
              const SizedBox(height: 4),
              QuerySelector<CreatePostMutation, Post, bool>(
                selector: (s) => s.isError,
                builder:
                    (context, isError) =>
                        _BoolBadge(label: 'isError', value: isError),
              ),
            ],
          ),
        ),

        // ── 9. InfiniteQueryListener ────────────────────────────────
        _SectionHeader(
          label: 'InfiniteQueryListener',
          description:
              'No more List<T> in the type argument — just the item type. '
              'Equivalent to QueryListener<C, List<T>> but cleaner.',
        ),
        _DemoCard(
          widgetName:
              'InfiniteQueryListener<ProductsInfiniteController, Product>',
          child: InfiniteQueryListener<ProductsInfiniteController, Product>(
            listenWhen:
                (prev, next) => prev.isLoadingMore && !next.isLoadingMore,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.isError
                        ? '[InfiniteQueryListener] Load-more failed'
                        : '[InfiniteQueryListener] Page loaded — ${state.data?.length ?? 0} total items',
                  ),
                  backgroundColor:
                      state.isError
                          ? Theme.of(context).colorScheme.error
                          : Colors.green.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: InfiniteQueryBuilder<ProductsInfiniteController, Product>(
              buildWhen:
                  (prev, next) =>
                      prev.isLoadingMore != next.isLoadingMore ||
                      prev.data?.length != next.data?.length,
              builder: (context, state) {
                final ctrl = context.query<ProductsInfiniteController>();
                return _InfiniteStatusRow(state: state, ctrl: ctrl);
              },
            ),
          ),
        ),

        // ── 10. InfiniteQuerySelector ───────────────────────────────
        _SectionHeader(
          label: 'InfiniteQuerySelector',
          description:
              'Select a slice of infinite query state — only the '
              'selecting widget rebuilds, not the whole tree.',
        ),
        _DemoCard(
          widgetName:
              'InfiniteQuerySelector<ProductsInfiniteController, Product, int>',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only rebuilds when item count changes (not on refetch/stale/etc.)
              InfiniteQuerySelector<ProductsInfiniteController, Product, int>(
                selector: (state) => state.data?.length ?? 0,
                builder:
                    (context, count) => _CountBadge(
                      label: 'Products loaded',
                      count: count,
                      color: Colors.purple,
                    ),
              ),
              const SizedBox(height: 6),
              // Only rebuilds when isLoadingMore toggles.
              InfiniteQuerySelector<ProductsInfiniteController, Product, bool>(
                selector: (state) => state.isLoadingMore,
                builder:
                    (context, isLoadingMore) => _BoolBadge(
                      label: 'isLoadingMore',
                      value: isLoadingMore,
                    ),
              ),
              const SizedBox(height: 6),
              InfiniteQuerySelector<ProductsInfiniteController, Product, bool>(
                selector: (state) => state.hasData,
                builder:
                    (context, hasData) =>
                        _BoolBadge(label: 'hasData', value: hasData),
              ),
            ],
          ),
        ),

        // ── 11. InfiniteQueryConsumer ───────────────────────────────
        _SectionHeader(
          label: 'InfiniteQueryConsumer',
          description:
              'Combines InfiniteQueryBuilder + InfiniteQueryListener. '
              'The List<T> wrapper is baked in — specify only the item type.',
        ),
        _DemoCard(
          widgetName:
              'InfiniteQueryConsumer<ProductsInfiniteController, Product>',
          child: InfiniteQueryConsumer<ProductsInfiniteController, Product>(
            listenWhen: (prev, next) => !prev.isSuccess && next.isSuccess,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '[InfiniteQueryConsumer] Initial load complete — '
                    '${state.data?.length ?? 0} items',
                  ),
                  backgroundColor: Colors.green.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            buildWhen:
                (prev, next) =>
                    prev.status != next.status ||
                    prev.data?.length != next.data?.length ||
                    prev.isLoadingMore != next.isLoadingMore,
            builder: (context, state) {
              final ctrl = context.query<ProductsInfiniteController>();
              return _InfiniteStatusRow(state: state, ctrl: ctrl);
            },
          ),
        ),

        // ── 12. Error Handling ─────────────────────────────────────
        _SectionHeader(
          label: 'Error Handling',
          description:
              'Original errors from your API/service flow through directly — '
              'even after retry exhaustion. transformError receives the real '
              'error, not a wrapper.',
        ),
        _DemoCard(
          widgetName: 'transformError + original error',
          child: QueryBuilder<_FailingMutation, String>(
            builder: (context, state) {
              final mutation = context.query<_FailingMutation>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CodeLabel('''
// Global transformError in main.dart:
transformError: (error) {
  if (error is ApiException) {
    return 'Server error \${error.statusCode}: '
           '\${error.message}';
  }
  return error;
}

// The original ApiException thrown by your
// service is received directly — not wrapped
// in QueryException.'''),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        state.isLoading
                            ? null
                            : () => mutation.mutate(),
                    icon: const Icon(Icons.error_outline, size: 16),
                    label: const Text('Trigger failing mutation'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (state.isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'state.error:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.error}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'error type: ${state.error.runtimeType}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (state.isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton(
                        onPressed: mutation.reset,
                        child: const Text('Reset'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // ── 13. MultiQueryListener ──────────────────────────────────
        _SectionHeader(
          label: 'MultiQueryListener',
          description:
              'Attach multiple QueryListeners without extra widget layers. '
              'Both listeners on this screen fire via the outer MultiQueryListener.',
        ),
        _DemoCard(
          widgetName: 'MultiQueryListener',
          child: const _CodeLabel('''
MultiQueryListener(
  listeners: [
    QueryListener<PostsQueryController, List<Post>>(
      listenWhen: (prev, next) => prev.isError != next.isError,
      listener: (context, state) { /* error snackbar */ },
    ),
    QueryListener<CreatePostMutation, Post>(
      listenWhen: (_, next) => next.isSuccess || next.isError,
      listener: (context, state) { /* mutation result snackbar */ },
    ),
  ],
  child: Scaffold(...),
)

// ↑ This screen is already wrapped in this exact pattern.
//   Trigger a mutation or an error to see both listeners fire.'''),
        ),

        // ── 13. QueryObserver ───────────────────────────────────────
        _SectionHeader(
          label: 'QueryObserver  (extends BlocObserver)',
          description:
              'Global observer for all query/mutation controllers. '
              'Extends BlocObserver — set once in main(), zero extra deps.',
        ),
        _DemoCard(
          widgetName: 'QueryObserver',
          child: const _CodeLabel('''
QueryClientProvider(
      client: QueryClient.instance,
      observer: AppQueryObserver(),
      child: MaterialApp(...),
)

class AppQueryObserver extends QueryObserver {
  // Called when any QueryController / InfiniteQueryController /
  // MutationController is created.
  @override
  void onQueryCreate(String cacheKey) =>
      debugPrint("created: \$cacheKey");

  // currentState + nextState — same as BlocObserver.onChange
  @override
  void onQueryChange(
    String cacheKey,
    QueryState<dynamic> currentState,
    QueryState<dynamic> nextState,
  ) {
    debugPrint(
      "[\$cacheKey] \${currentState.status} → \${nextState.status}",
    );
  }

  @override
  void onQueryError(
    String cacheKey, Object error, StackTrace st,
  ) => FirebaseCrashlytics.instance.recordError(error, st);

  @override
  void onQueryClose(String cacheKey) =>
      debugPrint("closed: \$cacheKey");
}'''),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Layout helpers
// ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String description;

  const _SectionHeader({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: cs.outline.withValues(alpha: 0.3), height: 1),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final String widgetName;
  final Widget child;

  const _DemoCard({required this.widgetName, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widgetName,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeLabel extends StatelessWidget {
  final String code;
  const _CodeLabel(this.code);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          color: cs.onSurface.withValues(alpha: 0.85),
          height: 1.55,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Status display widgets
// ─────────────────────────────────────────────────────────────────

class _QueryStatusRow extends StatelessWidget {
  final QueryState<dynamic> state;
  const _QueryStatusRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String label;
    Color color;
    if (state.isLoading) {
      label = 'Loading…';
      color = cs.primary;
    } else if (state.isRefetching) {
      label = 'Refetching…';
      color = Colors.blue;
    } else if (state.isSuccess) {
      final count = state.data is List ? (state.data as List).length : null;
      label = count != null ? 'Success — $count items' : 'Success';
      color = Colors.green;
    } else if (state.isError) {
      label = 'Error: ${state.error}';
      color = cs.error;
    } else {
      label = 'Idle';
      color = cs.onSurface.withValues(alpha: 0.4);
    }

    return Row(
      children: [
        if (state.isLoading || state.isRefetching)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(
            state.isSuccess
                ? Icons.check_circle_outline
                : state.isError
                ? Icons.error_outline
                : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        QueryStatusBadge(
          isPaused: state.isPaused,
          isRefetching: state.isRefetching,
          isStale: state.isStale,
          isSuccess: state.isSuccess,
        ),
      ],
    );
  }
}

class _InfiniteStatusRow extends StatelessWidget {
  final QueryState<List<Product>> state;
  final ProductsInfiniteController ctrl;

  const _InfiniteStatusRow({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          state.isLoading
              ? Icons.hourglass_empty
              : state.isSuccess
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 14,
          color: state.isSuccess ? Colors.green : cs.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.isLoading
                ? 'Loading first page…'
                : '${state.data?.length ?? 0} items · '
                    'page ${ctrl.currentPage} · '
                    '${ctrl.hasMore ? "more available" : "all loaded"}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        if (state.isLoadingMore)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final QueryStatus status;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 2),
          Text(
            status.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _BoolBadge extends StatelessWidget {
  final String label;
  final bool value;

  const _BoolBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value ? Colors.green : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value ? Icons.check_box : Icons.check_box_outline_blank,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color),
        ),
      ],
    );
  }
}

/// A mutation that always fails with an [ApiException].
/// Used in the Error Handling demo to show that the original error
/// flows through to state.error and transformError unchanged.
class _FailingMutation extends MutationController<String, void> {
  @override
  int get retryCount => 2;

  @override
  Duration get retryDelay => const Duration(milliseconds: 100);

  @override
  Future<String> mutationFn(void params) async {
    // Simulate an API call that returns a 422 error.
    throw ApiException(422, 'Validation failed: title is required');
  }
}

/// Shows the current state of the CreatePostMutation without a button.
/// Used inside QueryListener to show "run a mutation above to see me fire."
class _MutationStateInfo extends StatelessWidget {
  const _MutationStateInfo();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      'Use the QueryBuilder card above to trigger a mutation.\n'
      'This listener fires independently on success/error.',
      style: TextStyle(
        fontSize: 12,
        color: cs.onSurface.withValues(alpha: 0.55),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
