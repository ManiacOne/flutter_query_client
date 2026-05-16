import 'package:flutter/material.dart';
import 'package:flutter_query_client/flutter_query_client.dart';
import 'post_controllers.dart';
import 'post_model.dart';
import 'post_service.dart';

class PostFormScreen extends StatefulWidget {
  final Post? post; // null = create, non-null = edit
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
    return QueryListener<MutationController<Post>, Post>(
      bloc: _mutation,
      listenWhen: (prev, curr) => prev.isLoading && !curr.isLoading,
      listener: (ctx, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text('Error: ${state.error}')));
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
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
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
                        maxLines: 6,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
