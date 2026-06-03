import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:relational_orm/relational_orm.dart';

import 'post.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@unfreezed
class User extends RelationalModel<User> with _$User {
  User._();

  factory User({
    int? id,
    String? name,
    String? email,
    String? createdAt,
    String? updatedAt,
  }) = _User;

  /// Loaded posts relation
  List<Post> get posts {
    final rel = getRelation('posts');
    if (rel == null) return [];
    return (rel as List).cast<Post>();
  }

  @override
  String get table => 'users';

  @override
  String get primaryKey => 'id';

  @override
  bool get autoIncrementPrimary => true;

  @override
  Map<String, Relation<User, dynamic>> relations() {
    return {
      'posts': hasMany<User, Post>(
        Post(),
        'user_id',
      ),
    };
  }

  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);

  factory User.fromJson(Map<String, dynamic> json) =>
      _$UserFromJson(json);
}