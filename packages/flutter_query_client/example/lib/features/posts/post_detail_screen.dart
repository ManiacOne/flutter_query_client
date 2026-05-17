import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'post_controllers.dart';
import 'post_model.dart';
import 'post_form_screen.dart';

// Features demonstrated on this screen:
//  • MultiQueryListener  — combined error handling for two independent queries
//  • staleTime: 30s      — per-controller override (PostByIdController)
//  • refetchOnMount: always — comments re-fetched every time screen mounts
//  • Nested QueryBuilders — post + comments independently managed

class PostDetailScreen extends StatelessWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return QueryProvider<PostByIdController, Post>(
      create: (_) => PostByIdController()..setParams(postId),
      child: QueryProvider<PostCommentsController, List<Comment>>(
        create: (_) => PostCommentsController()..setParams(postId),
        // MultiQueryListener lets you react to state changes across multiple
        // independent query controllers in a single place — no nested listeners.
        child: MultiQueryListener(
          listeners: [
            QueryListener<PostByIdController, Post>(
              listenWhen: (prev, curr) => !prev.isError && curr.isError,
              listener: (ctx, state) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PostByIdController error: ${state.error}',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                );
              },
            ),
            QueryListener<PostCommentsController, List<Comment>>(
              listenWhen: (prev, curr) => !prev.isError && curr.isError,
              listener: (ctx, state) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.comment_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PostCommentsController error: ${state.error}',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange.shade700,
                  ),
                );
              },
            ),
          ],
          child: _PostDetailView(postId: postId),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _PostDetailView extends StatelessWidget {
  final int postId;
  const _PostDetailView({required this.postId});

  Future<void> _edit(BuildContext context, Post post) async {
    final controller = context.query<PostByIdController>();
    final updated = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => PostFormScreen(post: post)),
    );
    if (updated != null) {
      // updateCache() writes directly to QueryClient — no server round-trip.
      controller.updateCache((_) => updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Post #$postId'),
        actions: [
          IconButton(
            tooltip: 'Refetch both queries',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.query<PostByIdController>().refetch();
              context.query<PostCommentsController>().refetch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Feature banner ──────────────────────────────────────
          FeatureBanner(
            features: [
              FeatureItem(
                Icons.merge_type,
                'MultiQueryListener',
                Colors.purple,
              ),
              FeatureItem(
                Icons.timelapse,
                'staleTime: 30s override',
                Colors.blue,
              ),
              FeatureItem(
                Icons.replay,
                'refetchOnMount: always',
                Colors.green,
              ),
              FeatureItem(
                Icons.edit_note,
                'updateCache()',
                Colors.orange,
              ),
            ],
          ),

          // ── Post ───────────────────────────────────────────────
          Expanded(
            child: QueryBuilder<PostByIdController, Post>(
              builder: (context, postState) {
                if (postState.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (postState.error != null && !postState.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text('${postState.error}',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              context.query<PostByIdController>().refetch(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final post = postState.data!;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Post card ──
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Staleness badge (staleTime: 30s)
                                        if (postState.isStale)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: QueryStatusBadge(
                                              isPaused: false,
                                              isRefetching: false,
                                              isStale: true,
                                              isSuccess: false,
                                            ),
                                          ),
                                        Text(
                                          post.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit post (updates cache)',
                                    onPressed: () => _edit(context, post),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // User chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'User #${post.userId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post.body,
                                style: TextStyle(
                                  height: 1.5,
                                  color: cs.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Comments ──
                      QueryBuilder<PostCommentsController, List<Comment>>(
                        builder: (context, commentsState) {
                          if (commentsState.isLoading) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (commentsState.error != null) {
                            return Card(
                              color: cs.errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Comments error: ${commentsState.error}',
                                  style:
                                      TextStyle(color: cs.onErrorContainer),
                                ),
                              ),
                            );
                          }

                          final comments = commentsState.data ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Comments header
                              Row(
                                children: [
                                  Text(
                                    'Comments',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${comments.length}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // refetchOnMount: always indicator
                                  if (commentsState.isRefetching)
                                    QueryStatusBadge(
                                      isPaused: false,
                                      isRefetching: true,
                                      isStale: false,
                                      isSuccess: false,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Comment list
                              ...comments.map(
                                (c) => _CommentTile(comment: c),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  Color _avatarColor(String email) {
    final colors = [
      Colors.indigo,
      Colors.teal,
      Colors.purple,
      Colors.blue,
      Colors.green,
    ];
    return colors[email.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _avatarColor(comment.email);
    final initials = comment.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Initials avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      comment.email,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
