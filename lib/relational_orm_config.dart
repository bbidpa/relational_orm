import 'relational_database_adapter.dart';

class RelationalOrmConfig {
  static RelationalDatabaseAdapter? _database;

  static void configure({
    required RelationalDatabaseAdapter database,
  }) {
    _database = database;
  }

  static RelationalDatabaseAdapter get database {
    final db = _database;

    if (db == null) {
      throw StateError(
        'RelationalOrm is not configured. '
        'Call RelationalOrm.configure(database: ...) before using queries.',
      );
    }

    return db;
  }
}