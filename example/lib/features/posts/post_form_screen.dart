import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'post_controllers.dart';
import 'post_model.dart';

// Features demonstrated on this screen:
//  • MutationController<T, P> with typed params — mutationFn override
//  • context.query<T>().mutate(params) — consistent with QueryController
//  • MultiQueryListener — react to Create or Update without nesting
//  • QueryClient.instance.update — patch the flat 'posts' cache from outside
//    the list widget tree so the list stays consistent without a refetch

class PostFormScreen extends StatelessWidget {
  final Post? post;
  const PostFormScreen({super.key, this.post});

  @override
  Widget build(BuildContext context) {
    return MultiQueryProvider(
      providers: [
        QueryProvider(create: (_) => CreatePostMutation()),
        QueryProvider(create: (_) => UpdatePostMutation()),
      ],
      child: _PostFormBody(post: post),
    );
  }
}

// ─────────────────────────────────────────────────────────────────

class _PostFormBody extends StatefulWidget {
  final Post? post;
  const _PostFormBody({this.post});

  @override
  State<_PostFormBody> createState() => _PostFormBodyState();
}

class _PostFormBodyState extends State<_PostFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.post?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.post?.body ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing) {
      context.query<UpdatePostMutation>().mutate((
        id: widget.post!.id,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      ));
    } else {
      context.query<CreatePostMutation>().mutate((
        userId: 1,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // queryWatch(listen: true) registers this build for rebuilds on state changes.
    final isLoading =
        context.queryWatch<CreatePostMutation>().state.isLoading ||
        context.queryWatch<UpdatePostMutation>().state.isLoading;
    final isSuccess =
        context.queryWatch<CreatePostMutation>().state.isSuccess ||
        context.queryWatch<UpdatePostMutation>().state.isSuccess;
    final isError =
        context.queryWatch<CreatePostMutation>().state.isError ||
        context.queryWatch<UpdatePostMutation>().state.isError;

    return MultiQueryListener(
      listeners: [
        QueryListener<CreatePostMutation, Post>(
          listener: (ctx, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${state.error}')),
                    ],
                  ),
                  backgroundColor: cs.error,
                ),
              );
            } else if (state.data != null) {
              // Patch the flat 'posts' cache — prepend the new post so that
              // any PostsQueryController that re-mounts picks it up without
              // a network round-trip. The list screen syncs its live
              // controller from this cache after Navigator.pop returns.
              QueryClient.instance.update<List<Post>>(
                'posts',
                (posts) => [state.data!, ...posts],
              );
              Navigator.pop(ctx, state.data);
            }
          },
        ),
        QueryListener<UpdatePostMutation, Post>(
          listener: (ctx, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${state.error}')),
                    ],
                  ),
                  backgroundColor: cs.error,
                ),
              );
            } else if (state.data != null) {
              final updated = state.data!;
              // Replace the edited post in the flat 'posts' list cache.
              QueryClient.instance.update<List<Post>>(
                'posts',
                (posts) =>
                    posts.map((p) => p.id == updated.id ? updated : p).toList(),
              );
              // Also patch the single-post cache ('post' key, all param
              // variants) so PostByIdController reflects the edit immediately.
              QueryClient.instance.update<Post>(
                'post',
                (p) => p.id == updated.id ? updated : null,
              );
              Navigator.pop(ctx, state.data);
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit Post' : 'New Post')),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ── Feature banner ────────────────────────────────
              FeatureBanner(
                features: [
                  FeatureItem(
                    Icons.notifications_outlined,
                    'MutationController<T, P>',
                    Colors.orange,
                  ),
                  FeatureItem(
                    Icons.hearing,
                    'MultiQueryListener',
                    Colors.purple,
                  ),
                  FeatureItem(
                    Icons.system_update_alt_outlined,
                    'QueryClient.update',
                    Colors.teal,
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bodyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Body',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 20),

                      // Submit button — disabled while loading
                      FilledButton(
                        onPressed: isLoading ? null : () => _submit(context),
                        child:
                            isLoading
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(_isEditing ? 'Update' : 'Create'),
                      ),

                      const SizedBox(height: 16),

                      // ── Mutation lifecycle tracker ─────────────
                      MutationPhaseBar(
                        isLoading: isLoading,
                        isSuccess: isSuccess,
                        isError: isError,
                      ),

                      if (isSuccess) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'QueryListener detected success — cache patched via '
                            'QueryClient.instance.update() then Navigator.pop() '
                            'returned the post to the caller.',
                            style: TextStyle(fontSize: 11, color: Colors.green),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
