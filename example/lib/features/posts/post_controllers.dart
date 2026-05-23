import 'package:flutter_query_client/flutter_query_client.dart';
import 'post_model.dart';
import 'post_service.dart';

// ── Query controllers ──────────────────────────────────────────────

/// No-param query — void params always enable the query and auto-fetch on mount.
/// refetchInterval polls for fresh data every 60 seconds in the background.
class PostsQueryController extends QueryController<List<Post>, void> {
  PostsQueryController() : super('posts');

  // Auto-poll every 60 seconds — great for feeds or live dashboards.
  @override
  Duration? get refetchInterval => const Duration(seconds: 60);

  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.stale;

  @override
  Future<List<Post>> queryFn(void params) => postService.getPosts();
}

/// Single-param (int) dependent query — disabled until setParams() is called.
/// Demonstrates per-controller staleTime and retryCount overrides.
class PostByIdController extends QueryController<Post, int> {
  PostByIdController() : super('post');

  // Override global staleTime: individual posts go stale sooner than the list.
  @override
  Duration? get staleTime => const Duration(seconds: 30);

  // Fewer retries for detail views — fail faster instead of blocking the UI.
  @override
  int get retryCount => 1;

  @override
  Future<Post> queryFn(int? id) => postService.getPostById(id!);
}

/// Comments are always re-fetched when navigating back to the detail screen
/// because they can change independently of the post body.
class PostCommentsController extends QueryController<List<Comment>, int> {
  PostCommentsController() : super('post-comments');

  // RefetchOnMount.always: background-refresh every time this widget mounts,
  // even when the cache is still fresh.
  @override
  RefetchOnMount get refetchOnMount => RefetchOnMount.always;

  @override
  Future<List<Comment>> queryFn(int? postId) =>
      postService.getPostComments(postId!);
}

// ── Mutation param types ──────────────────────────────────────────

typedef CreatePostParams = ({int userId, String title, String body});

typedef UpdatePostParams = ({int id, String? title, String? body});

// ── Mutation controllers ───────────────────────────────────────────

/// Demonstrates mutation lifecycle hooks: onSuccess, onMutationError, onSettled.
/// Override these to run side effects after the mutation completes without
/// coupling that logic to the UI layer.
class CreatePostMutation
    extends MutationController<Post, CreatePostParams> {
  @override
  Future<Post> mutationFn(CreatePostParams params) {
    return postService.createPost(
      userId: params.userId,
      title: params.title,
      body: params.body,
    );
  }

  @override
  void onSuccess(Post data) {
    QueryLogger.info('[CreatePost] Created post id=${data.id}');
  }

  @override
  void onMutationError(Object error) {
    QueryLogger.warning('[CreatePost] Failed: $error');
  }

  @override
  void onSettled(Post? data, Object? error) {
    QueryLogger.fine('[CreatePost] Settled (success: ${data != null})');
  }
}

class UpdatePostMutation
    extends MutationController<Post, UpdatePostParams> {
  @override
  Future<Post> mutationFn(UpdatePostParams params) {
    return postService.updatePost(
      params.id,
      title: params.title,
      body: params.body,
    );
  }

  @override
  void onSuccess(Post data) {
    QueryLogger.info('[UpdatePost] Updated post id=${data.id}');
  }

  @override
  void onMutationError(Object error) {
    QueryLogger.warning('[UpdatePost] Failed: $error');
  }
}

/// Returns true on success (JSONPlaceholder delete returns empty body).
class DeletePostMutation extends MutationController<bool, int> {
  @override
  Future<bool> mutationFn(int params) async {
    await postService.deletePost(params);
    return true;
  }

  @override
  void onSuccess(bool data) {
    QueryLogger.info('[DeletePost] Post deleted');
  }
}
