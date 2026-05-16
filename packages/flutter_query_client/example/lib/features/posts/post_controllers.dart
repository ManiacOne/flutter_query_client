import 'package:flutter_query_client/flutter_query_client.dart';
import 'post_model.dart';
import 'post_service.dart';

// ── Query controllers ──────────────────────────────────────────────

class PostsQueryController extends QueryController<List<Post>, void> {
  PostsQueryController() : super('posts');

  @override
  Future<List<Post>> queryFn(void params) => postService.getPosts();
}

class PostByIdController extends QueryController<Post, int> {
  PostByIdController() : super('post');

  @override
  Future<Post> queryFn(int? id) => postService.getPostById(id!);
}

class PostCommentsController extends QueryController<List<Comment>, int> {
  PostCommentsController() : super('post-comments');

  @override
  Future<List<Comment>> queryFn(int? postId) =>
      postService.getPostComments(postId!);
}

// ── Mutation controllers ───────────────────────────────────────────

class CreatePostMutation extends MutationController<Post> {}

class UpdatePostMutation extends MutationController<Post> {}

/// Returns true on success (JSONPlaceholder delete returns empty body).
class DeletePostMutation extends MutationController<bool> {}
