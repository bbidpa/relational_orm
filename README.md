# Relational ORM

A lightweight Active Record style ORM for Dart and Flutter with relations, eager loading, polymorphic relations, soft deletes, and query builder support. Works with any SQL database through a simple adapter.

## Usage example

Query builder
```dart
// Query builder
final users = await User()
    .query()
    .where('active', true)
    .orderBy('name')
    .include(['posts', 'posts.comments'])
    .limit(10)
    .get();
```

Save model
```dart
// Create
final user = User(
  name: 'John Doe',
  email: 'john@example.com',
);

// Save
User savedUser = await user.save();
```

Get relations
```dart
// Load a user with posts and related data
User user = await User().find(1, include: [
    'posts.comments.author',
    'posts.tags',
]);

// User
print(user.name);
print(user.email);

// Iterate through loaded relations
for (final post in user.posts) {
  print('Post: ${post.title}'); // Post

  for (final comment in post.comments) {
    print('Comment: ${comment.author.name}: ${comment.content}'); // Comment
  }

  print('Tags: ${post.tags.map((t) => t.name).join(', ')}'); // Tag
}
```

> Examples are simplified for readability and may omit null checks.

## Features

- Active Record style models
- Eager loading
- `hasOne`
- `hasMany`
- `belongsTo`
- `belongsToMany`
- Polymorphic relations `morphTo`
- Soft deletes
- Query builder
- Nested relation loading
- Relation filtering
- Pivot tables
- UUID and auto-increment primary keys
- Database agnostic adapter layer

## Contents

- Installation
- Configure Database
- Defining Models
- Relationships
- Saving Models
- Query Builder
- Eager Loading
- Hydrating Existing Query Results
- Joins
- Relation Queries
- Soft Deletes
- License

## Installation

```yaml
dependencies:
  relational_orm: ^0.1.0
```

## Configure Database

```dart
import 'package:relational_orm/relational_orm.dart';

RelationalOrmConfig.configure(
  database: MyDatabaseAdapter(),
);
```
Relational ORM does not ship with a database implementation.

You provide a class implementing `RelationalDatabaseAdapter`
for SQLite, MySQL, PostgreSQL, Supabase, Drift, or any other
SQL backend.

```dart
class AppDatabaseAdapter
    implements RelationalDatabaseAdapter {

  @override
  Future<List<Map<String, dynamic>>> get(
    String table, {
    String? where,
    List<dynamic>? params,
  }) {
    return db.query(
      table,
      where: where,
      whereArgs: params,
    );
  }

  @override
  Future<dynamic> insert(
    String table,
    Map<String, dynamic> values,
  ) {
    return db.insert(table, values);
  }

  // update, delete and raw methods omitted
}
```
AppDatabaseAdapter is a small bridge between Relational ORM and your SQL library.
See [example/database_adapter.dart](example/database_adapter.dart) for a complete implementation using SQLite.

## Defining Models

Relational ORM models extend `RelationalModel<T>`.

Each model defines:

* the database table name
* fields / JSON serialization
* relation getters
* relation definitions

The examples below use `freezed` and `json_serializable`, but the ORM only requires `fromJson()` and `toJson()`.

### User Model

```dart
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
```

### Post Model

```dart
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
```

### Comment Model

```dart
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
```
See [example/model/](example/model/) for complete examples.

### Using Freezed

The examples in this documentation use `freezed` and `json_serializable`.

After creating or modifying models, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```
For automatic code generation while developing:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

Dependencies:
```yaml
dependencies:
  freezed_annotation: ^latest
  json_annotation: ^latest

dev_dependencies:
  build_runner: ^latest
  freezed: ^latest
  json_serializable: ^latest
```

If you are not using Freezed, you can implement `fromJson()` and `toJson()` manually. Relational ORM does not require Freezed and works with any model class that provides serialization methods.

## Relationships

### Has Many
```dart
'posts': hasMany(Post(), 'user_id')
```

### Belongs To
```dart
'user': belongsTo(User(), 'user_id')
```

### Has One
```dart
'profile': hasOne(Profile(), 'user_id')
```

### Belongs To Many
```dart
'roles': belongsToMany(
  Role(),
  'user_roles',
  'user_id',
  'role_id',
)
```

### Polymorphic
```dart
'owner': morphTo(
  'subject_type',
  'subject_id',
  {
    'user': User(),
    'team': Team(),
  },
)

```
## Saving Models
```dart
final user = User(
  name: 'John',
);

await user.save();
```

#### Update using pending attributes:
```dart
user.setAttribute('name', 'Jane');

await user.save();
```

#### Delete:
```dart
await user.delete();
```

## Query Builder
```dart
final users = await User()
    .query()
    .where('active', true)
    .orderBy('name')
    .limit(10)
    .get();
```

#### Multiple conditions:
```dart
final users = await User()
    .query()
    .where('active', true)
    .where('country', 'UK')
    .get();
```

#### Where In:
```dart
final users = await User()
    .query()
    .whereIn('id', [1, 2, 3])
    .get();
```

#### Or Where:
```dart
final users = await User()
    .query()
    .where('status', 'active')
    .orWhere('status', 'pending')
    .get();
```

#### Where Group:
```dart
final users = await User()
    .query()
    .whereGroup((q) {
      q.where('status', 'active');
      q.orWhere('status', 'pending');
    })
    .where('country', 'UK')
    .get();
```

#### Where Null:
```dart
final users = await User()
    .query()
    .whereNull('deleted_at')
    .get();
```

#### Where not Null:
```dart
final users = await User()
    .query()
    .whereNotNull('email_verified_at')
    .get();
```

#### Limit

Limit the number of returned records.

```dart
final users = await User()
    .query()
    .limit(10)
    .get();
```

#### Offset

Skip a number of records before returning results.

```dart
final users = await User()
    .query()
    .offset(20)
    .limit(10)
    .get();
```

#### Page

Zero-based pagination.

```dart
final users = await User()
    .query()
    .page(2, perPage: 20)
    .get();
```

#### Page1

One-based pagination.

```dart
final users = await User()
    .query()
    .page1(1, perPage: 20)
    .get();
```

#### Order By

Sort results by a column.

```dart
final users = await User()
    .query()
    .orderBy('name')
    .get();
```

Descending order:

```dart
final users = await User()
    .query()
    .orderBy(
      'created_at',
      descending: true,
    )
    .get();
```

#### Group By

Group results by one or more columns.

```dart
final users = await User()
    .query()
    .groupBy('country')
    .get();
```

Multiple columns:

```dart
final users = await User()
    .query()
    .groupBy([
      'country',
      'city',
    ])
    .get();
```

#### SQL Preview

Generate SQL without executing the query.

```dart
final sql = User()
    .query()
    .where('active', true)
    .orderBy('name')
    .toSql();

print(sql);
```

#### Get

Execute the query and return a list of models.

```dart
final users = await User()
    .query()
    .where('active', true)
    .get();
```

#### First

Execute the query and return the first matching model.

Returns `null` when no record is found.

```dart
final user = await User()
    .query()
    .where('email', 'john@example.com')
    .first();
```

#### First Or Fail

Execute the query and return the first matching model.

Throws an exception when no record is found.

```dart
final user = await User()
    .query()
    .where('email', 'john@example.com')
    .firstOrFail();
```


## Eager Loading
```dart
final users = await User()
    .query()
    .include([
      'posts',
      'profile',
    ])
    .get();
```

#### Nested:
```dart
final users = await User()
    .query()
    .include([
      'posts.comments',
    ])
    .get();
```

#### Scoped:
```dart
final users = await User()
    .query()
    .include([
      {
        'posts': (q) => q.limit(5),
      }
    ])
    .get();
```

## Hydrating Existing Query Results

```dart
// Your custom query
final rows = await db.raw(
  '''
  SELECT *
  FROM users
  JOIN subscriptions
    ON subscriptions.user_id = users.id
  WHERE subscriptions.active = 1
  '''
);

// Hydrate
final users = await User()
    .hydrate(rows)
    .include([
      'posts.comments',
    ])
    .get();
```

Hydration allows you to convert existing query results into models and load relations afterwards.

This is useful when:
- Using custom SQL queries
- Using repositories or services
- Querying views or complex joins
- Migrating existing applications to Relational ORM

## Joins

#### Manual Join

Join tables manually when you need full control over the generated SQL.

```dart
final users = await User()
    .query()
    .join('posts', localKey: 'id', foreignKey: 'user_id')
    .where('posts.published', true)
    .get();
```

#### Join Relations

`joinRelation()` automatically builds joins using the relationships defined on your models.

```dart
final users = await User()
    .query()
    .joinRelation('posts')
    .where('posts.published', true)
    .get();
```

#### Nested Relation Joins

Relations can be joined across multiple levels.

```dart
final users = await User()
    .query()
    .joinRelation('posts.comments.author')
    .where('authors.active', true)
    .get();
```

#### Filtering Through Relations

Find all users who have a comment written by a specific author.

```dart
final users = await User()
    .query()
    .joinRelation('posts.comments.author')
    .where('authors.id', authorId)
    .get();
```

#### Include vs Join

Use `include()` when you want to load related models.

```dart
final users = await User()
    .query()
    .include([
      'posts.comments.author',
    ])
    .get();
```

Use `joinRelation()` when you need to filter, sort, or group using related tables.

```dart
final users = await User()
    .query()
    .joinRelation('posts.comments.author')
    .where('authors.active', true)
    .orderBy('authors.name')
    .get();
```

| Method           | Purpose                                   |
| ---------------- | ----------------------------------------- |
| `include()`      | Load related models                       |
| `whereHas()`     | Filter by relation existence              |
| `joinRelation()` | Join related tables using model relations |
| `join()`         | Manual SQL joins                          |


## Relation Queries

```dart
final users = await User()
    .query()
    .whereHas(
      'posts',
      (q) => q.where('published', true),
    )
    .get();
```

#### Nested:
```dart
final users = await User()
    .query()
    .whereHas(
      'posts.comments',
      (q) => q.where('approved', true),
    )
    .get();
```

## Soft Deletes

Inside the model:
```dart
@override
bool get softDeletes => true;
```

Then delete the model:
```dart
await user.delete();
```

#### List only deleted models:
```dart
final deleted = await User()
    .query()
    .onlyDeleted()
    .get();
```

#### List with deleted models:
```dart
final deleted = await User()
    .query()
    .withDeleted()
    .get();
```

#### List without deleted (default):
```dart
final deleted = await User()
    .query()
    .withoutDeleted()
    .get();
```

## License

Relational ORM is open-source and is released under the Apache 2.0 License. See the [LICENSE](LICENSE) file for more information.
