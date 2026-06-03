import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:relational_orm/relational_orm.dart';

import 'user.dart';
import 'comment.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@unfreezed
class Post extends RelationalModel<Post> with _$Post {
  Post._();

  factory Post({
    int? id,
    int? userId,
    String? title,
    String? body,
    String? createdAt,
    String? updatedAt,
  }) = _Post;

  /// The user who owns this post
  User? get user => getRelation('user');

  /// Loaded comments relation
  List<Comment> get comments {
    final rel = getRelation('comments');
    if (rel == null) return [];
    return (rel as List).cast<Comment>();
  }

  @override
  String get table => 'posts';

  @override
  String get primaryKey => 'id';

  @override
  bool get autoIncrementPrimary => true;

  @override
  Map<String, Relation<Post, dynamic>> relations() {
    return {
      'user': belongsTo<Post, User>(
        User(),
        'user_id',
      ),
      'comments': hasMany<Post, Comment>(
        Comment(),
        'post_id',
      ),
    };
  }

  @override
  Post fromJson(Map<String, dynamic> json) => Post.fromJson(json);

  factory Post.fromJson(Map<String, dynamic> json) =>
      _$PostFromJson(json);
}