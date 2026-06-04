import 'package:test/test.dart';
import 'package:relational_orm/relational_orm.dart';
import 'helpers/database_adapter.dart';

import 'helpers/test_database.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'models/comment.dart';

void main() {
  late TestDatabase testDb;
  late DatabaseAdapter db;

  setUp(() async {
    testDb = TestDatabase();
    await testDb.open();

    db = DatabaseAdapter(testDb.db);

    RelationalOrmConfig.configure(
      database: DatabaseAdapter(testDb.db),
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  group('Model serialization', () {
    test('User fromJson and toJson', () {
      final user = User().fromJson({
        'id': 1,
        'name': 'John',
        'email': 'john@example.com',
      });

      expect(user.id, 1);
      expect(user.name, 'John');
      expect(user.email, 'john@example.com');

      expect(user.toJson(), {
        'id': 1,
        'name': 'John',
        'email': 'john@example.com',
      });
    });

    test('Post fromJson and toJson', () {
      final post = Post().fromJson({
        'id': 1,
        'user_id': 10,
        'title': 'Hello world',
      });

      expect(post.id, 1);
      expect(post.userId, 10);
      expect(post.title, 'Hello world');

      expect(post.toJson(), {
        'id': 1,
        'user_id': 10,
        'title': 'Hello world',
      });
    });

    test('Comment fromJson and toJson', () {
      final comment = Comment().fromJson({
        'id': 1,
        'post_id': 20,
        'body': 'Nice post',
      });

      expect(comment.id, 1);
      expect(comment.postId, 20);
      expect(comment.body, 'Nice post');

      expect(comment.toJson(), {
        'id': 1,
        'post_id': 20,
        'body': 'Nice post',
      });
    });
  });

  group('Relations definition', () {
    test('User defines posts relation', () {
      final relations = User().relations();

      expect(relations.containsKey('posts'), true);
    });

    test('Post defines author and comments relations', () {
      final relations = Post().relations();

      expect(relations.containsKey('author'), true);
      expect(relations.containsKey('comments'), true);
    });

    test('Comment defines post relation', () {
      final relations = Comment().relations();

      expect(relations.containsKey('post'), true);
    });
  });

  group('Database adapter', () {
    test('inserts and gets user row', () async {
      final id = await db.insert('users', {
        'name': 'John',
      });

      final rows = await db.get(
        'users',
        where: 'id = ?',
        params: [id],
      );

      expect(rows.length, 1);
      expect(rows.first['id'], id);
      expect(rows.first['name'], 'John');
    });

    test('filters posts by user_id', () async {
      await db.insert('posts', {
        'user_id': 1,
        'title': 'Post 1',
      });

      await db.insert('posts', {
        'user_id': 2,
        'title': 'Post 2',
      });

      final rows = await db.get(
        'posts',
        where: 'user_id = ?',
        params: [1],
      );

      expect(rows.length, 1);
      expect(rows.first['title'], 'Post 1');
    });

    test('filters comments by post_id', () async {
      await db.insert('comments', {
        'post_id': 5,
        'body': 'Comment 1',
      });

      await db.insert('comments', {
        'post_id': 6,
        'body': 'Comment 2',
      });

      final rows = await db.get(
        'comments',
        where: 'post_id = ?',
        params: [5],
      );

      expect(rows.length, 1);
      expect(rows.first['body'], 'Comment 1');
    });

    test('updates matching rows', () async {
      final id = await db.insert('users', {
        'name': 'John',
      });

      final updated = await db.update(
        'users',
        {
          'name': 'Mario',
        },
        where: 'id = ?',
        params: [id],
      );

      final rows = await db.get(
        'users',
        where: 'id = ?',
        params: [id],
      );

      expect(updated, 1);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Mario');
    });

    test('deletes matching rows', () async {
      final id = await db.insert('users', {
        'name': 'John',
      });

      final deleted = await db.delete(
        'users',
        where: 'id = ?',
        params: [id],
      );

      final rows = await db.get(
        'users',
        where: 'id = ?',
        params: [id],
      );

      expect(deleted, 1);
      expect(rows, isEmpty);
    });

    test('applies limit and offset', () async {
      await db.insert('users', {'name': 'User 1'});
      await db.insert('users', {'name': 'User 2'});
      await db.insert('users', {'name': 'User 3'});

      final rows = await db.get(
        'users',
        limit: 1,
        offset: 1,
      );

      expect(rows.length, 1);
      expect(rows.first['name'], 'User 2');
    });

    test('applies select columns', () async {
      await db.insert('users', {
        'name': 'John',
        'email': 'john@example.com',
      });

      final rows = await db.get(
        'users',
        select: ['name'],
      );

      expect(rows.length, 1);
      expect(rows.first.containsKey('name'), true);
      expect(rows.first.containsKey('email'), false);
    });
  });

  group('ORM model operations', () {
    test('creates user through model save', () async {
      final user = User(name: 'John');

      await user.save();

      final rows = await db.get('users');

      expect(rows.length, 1);
      expect(rows.first['name'], 'John');
    });

    test('finds user through model', () async {
      final id = await db.insert('users', {
        'name': 'John',
      });

      final user = await User().find(id);

      expect(user, isNotNull);
      expect(user!.id, id);
      expect(user.name, 'John');
    });

    test('updates user through model save', () async {
      final id = await db.insert('users', {
        'name': 'John',
      });

      final user = await User().find(id);

      expect(user, isNotNull);

      user!.name = 'Mario';
      await user.save();

      final rows = await db.get(
        'users',
        where: 'id = ?',
        params: [id],
      );

      expect(rows.first['name'], 'Mario');
    });

    test('deletes user through model', () async {
      final id = await db.insert('users', {
        'name': 'John',
      });

      final user = await User().find(id);

      expect(user, isNotNull);

      await user!.delete();

      final rows = await db.get(
        'users',
        where: 'id = ?',
        params: [id],
      );

      expect(rows, isEmpty);
    });
  });

  group('Query builder', () {
    test('gets all users', () async {
      await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});

      final users = await User().query().get();

      expect(users.length, 2);
      expect(users.first, isA<User>());
    });

    test('gets first user', () async {
      await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});

      final user = await User().query().first();

      expect(user, isNotNull);
      expect(user!.name, 'John');
    });

    test('limits users', () async {
      await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});

      final users = await User().query().limit(1).get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });
  });

  //------------------------------------------
  // Query builder advanced 
  //------------------------------------------
  group('Query builder advanced', () {
    test('where filters users', () async {
      await db.insert('users', {'name': 'John', 'email': 'john@example.com'});
      await db.insert('users', {'name': 'Jane', 'email': 'jane@example.com'});

      final users = await User()
          .query()
          .where('name', 'John')
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });

    test('whereIn filters users', () async {
      final id1 = await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});
      final id3 = await db.insert('users', {'name': 'Mario'});

      final users = await User()
          .query()
          .whereIn('id', [id1, id3])
          .orderBy('id')
          .get();

      expect(users.length, 2);
      expect(users.map((u) => u.name), ['John', 'Mario']);
    });

    test('orWhere filters users', () async {
      await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});
      await db.insert('users', {'name': 'Mario'});

      final users = await User()
          .query()
          .where('name', 'John')
          .orWhere('name', 'Jane')
          .orderBy('id')
          .get();

      expect(users.length, 2);
      expect(users.map((u) => u.name), ['John', 'Jane']);
    });

    test('whereGroup combines grouped conditions', () async {
      await db.insert('users', {'name': 'John', 'email': 'john@example.com'});
      await db.insert('users', {'name': 'Jane', 'email': 'jane@example.com'});
      await db.insert('users', {'name': 'Mario', 'email': 'mario@example.com'});

      final users = await User()
          .query()
          .whereGroup((q) {
            q.where('name', 'John');
            q.orWhere('name', 'Jane');
          })
          .orderBy('id')
          .get();

      expect(users.length, 2);
      expect(users.map((u) => u.name), ['John', 'Jane']);
    });

    test('whereNull and whereNotNull work', () async {
      await db.insert('users', {'name': 'John', 'email': null});
      await db.insert('users', {'name': 'Jane', 'email': 'jane@example.com'});

      final withoutEmail = await User()
          .query()
          .whereNull('email')
          .get();

      final withEmail = await User()
          .query()
          .whereNotNull('email')
          .get();

      expect(withoutEmail.length, 1);
      expect(withoutEmail.first.name, 'John');

      expect(withEmail.length, 1);
      expect(withEmail.first.name, 'Jane');
    });

    test('page and page1 paginate records', () async {
      await db.insert('users', {'name': 'User 1'});
      await db.insert('users', {'name': 'User 2'});
      await db.insert('users', {'name': 'User 3'});

      final zeroBased = await User()
          .query()
          .orderBy('id')
          .page(1, perPage: 1)
          .get();

      final oneBased = await User()
          .query()
          .orderBy('id')
          .page1(2, perPage: 1)
          .get();

      expect(zeroBased.first.name, 'User 2');
      expect(oneBased.first.name, 'User 2');
    });

    test('firstOrFail returns model when found', () async {
      await db.insert('users', {'name': 'John'});

      final user = await User()
          .query()
          .where('name', 'John')
          .firstOrFail();

      expect(user.name, 'John');
    });

    test('firstOrFail throws when not found', () async {
      expect(
        () => User()
            .query()
            .where('name', 'Missing')
            .firstOrFail(),
        throwsException,
      );
    });

    test('toSql previews generated SQL', () {
      final sql = User()
          .query()
          .where('name', 'John')
          .orderBy('name')
          .limit(10)
          .toSql();

      expect(sql, contains('SELECT'));
      expect(sql, contains('FROM users'));
      expect(sql, contains('WHERE name = ?'));
      expect(sql, contains('ORDER BY name ASC'));
      expect(sql, contains('LIMIT 10'));
    });
  });

  //------------------------------------------
  // Relations
  //------------------------------------------
  group('Relations and eager loading', () {
    test('loads hasMany posts for user', () async {
      final userId = await db.insert('users', {
        'name': 'John',
      });

      await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 1',
      });

      await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 2',
      });

      final user = await User().find(
        userId,
        include: ['posts'],
      );

      expect(user, isNotNull);
      expect(user!.posts.length, 2);
      expect(user.posts.first.title, 'Post 1');
    });

    test('loads belongsTo author for post', () async {
      final userId = await db.insert('users', {'name': 'John'});

      final postId = await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 1',
      });

      final post = await Post().find(postId, include: ['author']);

      final author = post!.getRelation('author') as User?;

      expect(author, isNotNull);
      expect(author!.name, 'John');
    });

    test('loads nested posts.comments relation', () async {
      final userId = await db.insert('users', {'name': 'John'});

      final postId = await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 1',
      });

      await db.insert('comments', {
        'post_id': postId,
        'body': 'Nice post',
      });

      final user = await User().find(userId, include: [
        'posts.comments',
      ]);

      final posts = user!.posts;
      final comments = posts.first.comments;

      expect(posts.length, 1);
      expect(comments.length, 1);
      expect(comments.first.body, 'Nice post');
    });

    test('scoped include limits loaded posts', () async {
      final userId = await db.insert('users', {'name': 'John'});

      await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 1',
      });

      await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 2',
      });

      final user = await User().find(userId, include: [
        {
          'posts': (q) => q.orderBy('id').limit(1),
        }
      ]);

      final posts = user!.posts;

      expect(posts.length, 1);
      expect(posts.first.title, 'Post 1');
    });
  });

  //------------------------------------------
  // Joins
  //------------------------------------------
  group('Joins and relation queries', () {
    test('manual join filters users by post title', () async {
      final johnId = await db.insert('users', {'name': 'John'});
      final janeId = await db.insert('users', {'name': 'Jane'});

      await db.insert('posts', {
        'user_id': johnId,
        'title': 'Target Post',
      });

      await db.insert('posts', {
        'user_id': janeId,
        'title': 'Other Post',
      });

      final users = await User()
          .query()
          .select([
            'users.id AS id',
            'users.name AS name',
            'users.email AS email',
          ])
          .join(
            'posts',
            localKey: 'id',
            foreignKey: 'user_id',
          )
          .where('posts.title', 'Target Post')
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });

    test('joinRelation filters users by related post title', () async {
      final johnId = await db.insert('users', {'name': 'John'});
      final janeId = await db.insert('users', {'name': 'Jane'});

      await db.insert('posts', {
        'user_id': johnId,
        'title': 'Target Post',
      });

      await db.insert('posts', {
        'user_id': janeId,
        'title': 'Other Post',
      });

      final users = await User()
          .query()
          .select([
            'users.id AS id',
            'users.name AS name',
            'users.email AS email',
          ])
          .joinRelation('posts')
          .where('posts.title', 'Target Post')
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });

    test('whereHas filters users that have matching posts', () async {
      final johnId = await db.insert('users', {'name': 'John'});
      final janeId = await db.insert('users', {'name': 'Jane'});

      await db.insert('posts', {
        'user_id': johnId,
        'title': 'Published Post',
      });

      await db.insert('posts', {
        'user_id': janeId,
        'title': 'Draft Post',
      });

      final users = await User()
          .query()
          .whereHas('posts', (q) {
            q.where('title', 'Published Post');
          })
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });

    test('nested whereHas filters users through posts.comments', () async {
      final johnId = await db.insert('users', {'name': 'John'});
      final janeId = await db.insert('users', {'name': 'Jane'});

      final johnPostId = await db.insert('posts', {
        'user_id': johnId,
        'title': 'John Post',
      });

      final janePostId = await db.insert('posts', {
        'user_id': janeId,
        'title': 'Jane Post',
      });

      await db.insert('comments', {
        'post_id': johnPostId,
        'body': 'Approved',
      });

      await db.insert('comments', {
        'post_id': janePostId,
        'body': 'Pending',
      });

      final users = await User()
          .query()
          .whereHas('posts.comments', (q) {
            q.where('body', 'Approved');
          })
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });
  });

  //------------------------------------------
  // Hydration and deletes
  //------------------------------------------
  group('Hydration and deletes', () {
    test('hydrates raw query results into models', () async {
      await db.insert('users', {
        'name': 'John',
        'email': 'john@example.com',
      });

      final rows = await db.raw(
        'SELECT * FROM users WHERE email = ?',
        ['john@example.com'],
      );

      final users = await User()
          .hydrate(rows)
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'John');
    });

    test('hydrates rows and loads relations', () async {
      final userId = await db.insert('users', {'name': 'John'});

      await db.insert('posts', {
        'user_id': userId,
        'title': 'Post 1',
      });

      final rows = await db.raw(
        'SELECT * FROM users WHERE id = ?',
        [userId],
      );

      final users = await User()
          .hydrate(rows)
          .include(['posts'])
          .get();

      final posts = users.first.posts;

      expect(users.length, 1);
      expect(posts.length, 1);
      expect(posts.first.title, 'Post 1');
    });

    test('setAttribute updates model on save', () async {
      final id = await db.insert('users', {
        'name': 'John',
        'email': 'john@example.com',
      });

      final user = await User().find(id);

      user!.setAttribute('name', 'Jane');

      final saved = await user.save();

      expect(saved!.name, 'Jane');

      final rows = await db.get(
        'users',
        where: 'id = ?',
        params: [id],
      );

      expect(rows.first['name'], 'Jane');
    });

    test('query forceDelete deletes matching rows', () async {
      await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});

      final deleted = await User()
          .query()
          .where('name', 'John')
          .forceDelete();

      final users = await User().query().get();

      expect(deleted, 1);
      expect(users.length, 1);
      expect(users.first.name, 'Jane');
    });

    test('model delete deletes only that model', () async {
      final johnId = await db.insert('users', {'name': 'John'});
      await db.insert('users', {'name': 'Jane'});

      final john = await User().find(johnId);

      await john!.delete();

      final users = await User()
          .query()
          .orderBy('id')
          .get();

      expect(users.length, 1);
      expect(users.first.name, 'Jane');
    });
  });
}