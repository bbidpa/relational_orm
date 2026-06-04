import 'package:relational_orm/relational_orm.dart';

import 'database_adapter.dart';
import 'database.dart';
import 'model/user.dart';
import 'model/post.dart';

Future<void> main() async {
  // Create test database
  final testDb = TestDatabase();
  await testDb.open();

  // Configure ORM
  RelationalOrmConfig.configure(
    database: DatabaseAdapter(testDb.db),
  );

  // Create user
  final user = User(
    name: 'John Doe',
    email: 'john@example.com',
  );

  await user.save();

  // Create post
  await Post(
    userId: user.id,
    title: 'Hello Relational ORM',
  ).save();

  // Query users with relations
  final users = await User()
      .query()
      .include(['posts'])
      .get();

  for (final user in users) {
    print('User: ${user.name}');

    for (final post in user.posts) {
      print('  Post: ${post.title}');
    }
  }

  await testDb.close();
}