import 'package:relational_orm/relational_orm.dart';
import 'user.dart';
import 'comment.dart';

class Post extends RelationalModel<Post> {
  int? id;
  int? userId;
  String? title;

  Post({
    this.id,
    this.userId,
    this.title,
  });

  @override
  String get table => 'posts';

  List<Comment> get comments {
    final rel = getRelation('comments');
    if (rel == null) return [];
    return (rel as List).cast<Comment>();
  }

  @override
  Post fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
    };
  }

  @override
  Map<String, Relation<Post, dynamic>> relations() {
    return {
      'author': belongsTo<Post, User>(
        User(),
        'user_id',
      ),
      'comments': hasMany<Post, Comment>(
        Comment(),
        'post_id',
      ),
    };
  }
}