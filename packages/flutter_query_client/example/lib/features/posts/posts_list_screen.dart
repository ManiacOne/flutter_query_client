import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'post_controllers.dart';
import 'post_model.dart';
import 'post_service.dart';
import 'post_detail_screen.dart';
import 'post_form_screen.dart';

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
            content: Text('"${post.title}"'),
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

    await _deleteMutation.mutate(
      () => postService.deletePost(post.id).then((_) => true),
    );

    if (!mounted) return;
    if (_deleteMutation.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${_deleteMutation.state.error}'),
        ),
      );
    } else {
      // Optimistically remove from cached list without a refetch
      context.query<PostsQueryController>().updateCache(
        (posts) => posts?.where((p) => p.id != post.id).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post #${post.id} deleted (mock)')),
      );
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => const PostFormScreen()),
    );
    if (created != null && mounted) {
      // Prepend to cached list so it appears immediately
      context.query<PostsQueryController>().updateCache(
        (posts) => posts != null ? [created, ...posts] : [created],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        actions: [
          IconButton(
            onPressed: () => context.query<PostsQueryController>().refetch(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_posts',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: QueryBuilder<PostsQueryController, List<Post>>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${state.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        () => context.query<PostsQueryController>().refetch(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final posts = state.data ?? [];
          return ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final post = posts[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${post.id}')),
                title: Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('User #${post.userId}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(post),
                ),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(postId: post.id),
                      ),
                    ),
              );
            },
          );
        },
      ),
    );
  }
}
