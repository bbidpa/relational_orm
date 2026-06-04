import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestDatabase {
  late Database db;

  Future<void> open() async {
    sqfliteFfiInit();

    final databaseFactory = databaseFactoryFfi;

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              email TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE posts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              title TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE comments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              post_id INTEGER,
              body TEXT
            )
          ''');
        },
      ),
    );
  }

  Future<void> close() async {
    await db.close();
  }
}