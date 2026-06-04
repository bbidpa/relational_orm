import 'package:relational_orm/relational_orm.dart';
import 'post.dart';

class User extends RelationalModel<User> {
  int? id;
  String? name;
  String? email;

  User({this.id, this.name, this.email});

  @override
  String get table => 'users';

  List<Post> get posts {
    final rel = getRelation('posts');
    if (rel == null) return [];
    return (rel as List).cast<Post>();
  }

  @override
  User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }

  @override
  Map<String, Relation<User, dynamic>> relations() {
    return {
      'posts': hasMany<User, Post>(
        Post(),
        'user_id',
      ),
    };
  }
}