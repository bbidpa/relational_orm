import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:relational_orm/relational_orm.dart';

import 'comment.dart';

part 'author.freezed.dart';
part 'author.g.dart';

@unfreezed
class Author extends RelationalModel<Author> with _$Author {
  Author._();

  factory Author({
    int? id,
    String? name,
    String? email,
    String? createdAt,
    String? updatedAt,
  }) = _Author;

  /// Comments written by this author
  List<Comment> get comments {
    final rel = getRelation('comments');
    if (rel == null) return [];
    return (rel as List).cast<Comment>();
  }

  @override
  String get table => 'authors';

  @override
  String get primaryKey => 'id';

  @override
  bool get autoIncrementPrimary => true;

  @override
  Map<String, Relation<Author, dynamic>> relations() {
    return {
      'comments': hasMany<Author, Comment>(
        Comment(),
        'author_id',
      ),
    };
  }

  @override
  Author fromJson(Map<String, dynamic> json) => Author.fromJson(json);

  factory Author.fromJson(Map<String, dynamic> json) =>
      _$AuthorFromJson(json);
}