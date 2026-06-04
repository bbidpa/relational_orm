import 'package:relational_orm/relational_orm.dart';
import 'post.dart';

class Comment extends RelationalModel<Comment> {
  int? id;
  int? postId;
  String? body;

  Comment({
    this.id,
    this.postId,
    this.body,
  });

  @override
  String get table => 'comments';

  @override
  Comment fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['post_id'],
      body: json['body'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'body': body,
    };
  }

  @override
  Map<String, Relation<Comment, dynamic>> relations() {
    return {
      'post': belongsTo<Comment, Post>(
        Post(),
        'post_id',
      ),
    };
  }
}