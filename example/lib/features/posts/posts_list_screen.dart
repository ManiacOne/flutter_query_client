import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'post_controllers.dart';
import 'post_model.dart';
import 'post_detail_screen.dart';
import 'post_form_screen.dart';

// Features demonstrated on this screen:
//  • QueryController<List<Post>, void>  — void params, auto-enabled
//  • refetchInterval: 60s              — background polling
//  • optimistic cache update/prepend   — instant UI feedback on create/delete
//  • DeletePostMutation lifecycle hooks — onSuccess / onSettled
//  • NetworkMode.online                — isPaused state when offline

class PostsListScreen extends StatelessWidget {
  const PostsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryProvider<PostsQueryController, List<Post>>(
      create: (_) => PostsQueryController(),
      child: const _PostsListView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _PostsListView extends StatefulWidget {
  const _PostsListView();

  @override
  State<_PostsListView> createState() => _PostsListViewState();
}

class _PostsListViewState extends State<_PostsListView> {
  late final DeletePostMutation _deleteMutation;

  @override
  void initState() {
    super.initState();
    _deleteMutation = DeletePostMutation();
  }

  @override
  void dispose() {
    _deleteMutation.close();
    super.dispose();
  }

  Future<void> _delete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete post?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${post.title}"'),
                const SizedBox(height: 8),
                const Text(
                  'Demonstrates optimistic cache removal — the post disappears '
                  'instantly without waiting for a refetch.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    await _deleteMutation.mutate(post.id);

    if (!mounted) return;
    if (_deleteMutation.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${_deleteMutation.state.error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      // Optimistic cache removal — updateCache() writes directly to the
      // QueryClient cache and emits a new state without a network refetch.
      context.query<PostsQueryController>().updateCache(
        (posts) => posts?.where((p) => p.id != post.id).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text('Post #${post.id} removed from cache (optimistic)'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => const PostFormScreen()),
    );
  }

  static const _userColors = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFF4F46E5),
  ];

  Color _colorForUser(int userId) => _userColors[userId % _userColors.length];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        actions: [
          IconButton(
            tooltip: 'Manual refetch',
            onPressed: () => context.query<PostsQueryController>().refetch(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_posts',
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New post'),
      ),
      body: Column(
        children: [
          // ── Feature banner ─────────────────────────────────────
          FeatureBanner(
            features: [
              FeatureItem(Icons.sync, 'refetchInterval: 60s', Colors.blue),
              FeatureItem(Icons.bolt, 'Optimistic cache', Colors.purple),
              FeatureItem(
                Icons.notifications_outlined,
                'Lifecycle hooks',
                Colors.orange,
              ),
              FeatureItem(Icons.wifi_off, 'NetworkMode.online', Colors.teal),
            ],
          ),

          // ── Query content ──────────────────────────────────────
          Expanded(
            child: QueryBuilder<PostsQueryController, List<Post>>(
              builder: (context, state) {
                // ── Loading (first fetch) ──
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ── Paused with no data (offline before first fetch) ──
                if (state.isPaused && !state.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 56,
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Offline',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NetworkMode.online — query paused until reconnect',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ── Error ──
                if (state.error != null && !state.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load posts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              () =>
                                  context
                                      .query<PostsQueryController>()
                                      .refetch(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final posts = state.data ?? [];

                return Column(
                  children: [
                    // ── Thin progress bar when background-refetching ──
                    if (state.isRefetching)
                      LinearProgressIndicator(
                        minHeight: 2,
                        color: cs.primary,
                        backgroundColor: cs.primary.withValues(alpha: 0.15),
                      ),

                    // ── Status row ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${posts.length} posts',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live query status badge
                          QueryStatusBadge(
                            isPaused: state.isPaused,
                            isRefetching: state.isRefetching,
                            isStale: state.isStale,
                            isSuccess: state.isSuccess,
                          ),
                          const Spacer(),
                          if (state.isPaused)
                            Text(
                              'Auto-poll paused',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.withValues(alpha: 0.8),
                              ),
                            )
                          else
                            Text(
                              'Auto-polls every 60s',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Offline banner (has stale data but refetch paused) ──
                    if (state.isPaused)
                      Container(
                        width: double.infinity,
                        color: Colors.orange.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Offline — showing cached data',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Post list ──
                    Expanded(
                      child: ListView.separated(
                        itemCount: posts.length,
                        separatorBuilder:
                            (_, __) => Divider(
                              height: 1,
                              color: cs.outline.withValues(alpha: 0.2),
                            ),
                        itemBuilder: (context, i) {
                          final post = posts[i];
                          final userColor = _colorForUser(post.userId);
                          return InkWell(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            PostDetailScreen(postId: post.id),
                                  ),
                                ),
                            child: Row(
                              children: [
                                // Colored user accent strip
                                Container(
                                  width: 4,
                                  height: 72,
                                  color: userColor.withValues(alpha: 0.7),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        // User avatar
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: userColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          child: Text(
                                            '#${post.userId}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: userColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Title + subtitle
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                post.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                post.body,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: cs.error.withValues(
                                              alpha: 0.7,
                                            ),
                                            size: 20,
                                          ),
                                          onPressed: () => _delete(post),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
