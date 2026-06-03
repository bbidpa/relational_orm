import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:relational_orm/relational_orm.dart';

import 'post.dart';
import 'author.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@unfreezed
class Comment extends RelationalModel<Comment> with _$Comment {
  Comment._();

  factory Comment({
    int? id,
    int? postId,
    int? authorId,
    String? content,
    String? createdAt,
    String? updatedAt,
  }) = _Comment;

  /// The post this comment belongs to
  Post? get post => getRelation('post');

  /// The author who wrote this comment
  Author? get author => getRelation('author');

  @override
  String get table => 'comments';

  @override
  String get primaryKey => 'id';

  @override
  bool get autoIncrementPrimary => true;

  @override
  Map<String, Relation<Comment, dynamic>> relations() {
    return {
      'post': belongsTo<Comment, Post>(
        Post(),
        'post_id',
      ),
      'author': belongsTo<Comment, Author>(
        Author(),
        'author_id',
      ),
    };
  }

  @override
  Comment fromJson(Map<String, dynamic> json) => Comment.fromJson(json);

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}