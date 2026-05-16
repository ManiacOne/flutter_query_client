import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'post_controllers.dart';
import 'post_model.dart';
import 'post_form_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    // Provide both controllers with their params set at creation time.
    return QueryProvider<PostByIdController, Post>(
      create: (_) => PostByIdController()..setParams(postId),
      child: QueryProvider<PostCommentsController, List<Comment>>(
        create: (_) => PostCommentsController()..setParams(postId),
        child: _PostDetailView(postId: postId),
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
      controller.updateCache((_) => updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post #$postId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.query<PostByIdController>().refetch();
              context.query<PostCommentsController>().refetch();
            },
          ),
        ],
      ),
      body: QueryBuilder<PostByIdController, Post>(
        builder: (context, postState) {
          if (postState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (postState.error != null) {
            return Center(child: Text('Error: ${postState.error}'));
          }

          if (postState.data == null) {
            return const Center(child: Text('Post not found'));
          }

          final post = postState.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Post body ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _edit(context, post),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'User #${post.userId}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(post.body),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                      return Text('Comments error: ${commentsState.error}');
                    }
                    final comments = commentsState.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comments (${comments.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...comments.map(
                          (c) => ListTile(
                            leading: const Icon(Icons.comment_outlined),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.email,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  c.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
