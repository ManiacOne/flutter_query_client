class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        userId: json['userId'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'body': body,
      };

  Post copyWith({int? id, int? userId, String? title, String? body}) => Post(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        body: body ?? this.body,
      );
}

class Comment {
  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as int,
        postId: json['postId'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        body: json['body'] as String,
      );
}
