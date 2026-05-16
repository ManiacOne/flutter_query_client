import '../../core/api_client.dart';
import '../../core/endpoints.dart';
import 'post_model.dart';

class PostService {
  final ApiClient _api;
  PostService({ApiClient? api}) : _api = api ?? apiClient;

  Future<List<Post>> getPosts() async {
    final data = await _api.get(Endpoints.posts()) as List;
    return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Post> getPostById(int id) async {
    final data = await _api.get(Endpoints.postById(id));
    return Post.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Comment>> getPostComments(int postId) async {
    final data = await _api.get(Endpoints.postComments(postId)) as List;
    return data
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
  }) async {
    final data = await _api.post(Endpoints.posts(), {
      'userId': userId,
      'title': title,
      'body': body,
    });
    return Post.fromJson(data as Map<String, dynamic>);
  }

  Future<Post> updatePost(int id, {String? title, String? body}) async {
    final data = await _api.put(Endpoints.postById(id), {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
    return Post.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePost(int id) async {
    await _api.delete(Endpoints.postById(id));
  }
}

final postService = PostService();
