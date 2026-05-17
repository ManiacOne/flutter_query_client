import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import '../../shared.dart';
import 'post_controllers.dart';
import 'post_model.dart';
import 'post_service.dart';

// Features demonstrated on this screen:
//  • MutationController lifecycle hooks — onSuccess / onMutationError / onSettled
//  • QueryListener  — react to mutation state transitions outside the builder
//  • QueryBuilder   — build UI from mutation state (loading button, etc.)

class PostFormScreen extends StatefulWidget {
  final Post? post;
  const PostFormScreen({super.key, this.post});

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  // Typed as base class so Create/Update share the same QueryBuilder type.
  late final MutationController<Post> _mutation;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.post?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.post?.body ?? '');
    _mutation = _isEditing ? UpdatePostMutation() : CreatePostMutation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _mutation.close();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing) {
      _mutation.mutate(
        () => postService.updatePost(
          widget.post!.id,
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
        ),
      );
    } else {
      _mutation.mutate(
        () => postService.createPost(
          userId: 1,
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return QueryListener<MutationController<Post>, Post>(
      bloc: _mutation,
      listenWhen: (prev, curr) => prev.isLoading && !curr.isLoading,
      listener: (ctx, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${state.error}')),
                ],
              ),
              backgroundColor: cs.error,
            ),
          );
        } else if (state.data != null) {
          Navigator.pop(ctx, state.data);
        }
      },
      child: QueryBuilder<MutationController<Post>, Post>(
        bloc: _mutation,
        builder:
            (context, state) => Scaffold(
              appBar: AppBar(
                title: Text(_isEditing ? 'Edit Post' : 'New Post'),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Feature banner ──────────────────────────────
                    FeatureBanner(
                      features: [
                        FeatureItem(
                          Icons.notifications_outlined,
                          'MutationController hooks',
                          Colors.orange,
                        ),
                        FeatureItem(
                          Icons.hearing,
                          'QueryListener',
                          Colors.purple,
                        ),
                        FeatureItem(
                          Icons.build_outlined,
                          'QueryBuilder',
                          Colors.blue,
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
                              onPressed: state.isLoading ? null : _submit,
                              child:
                                  state.isLoading
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

                            // ── Mutation lifecycle tracker ───────────
                            // This widget visualises the MutationController
                            // state in real-time and shows which hooks fired.
                            MutationPhaseBar(
                              isLoading: state.isLoading,
                              isSuccess: state.isSuccess,
                              isError: state.isError,
                            ),

                            // Post-success hint
                            if (state.isSuccess) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'QueryListener detected success and called Navigator.pop() '
                                  'to return the new post to the list screen.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                  ),
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
      ),
    );
  }
}
