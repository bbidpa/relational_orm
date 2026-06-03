import 'package:relational_orm/relational_orm.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabaseAdapter implements RelationalDatabaseAdapter {
  final Database db;

  AppDatabaseAdapter(this.db);

  @override
  Future<List<Map<String, dynamic>>> get(
    String table, {
    List<String>? select,
    bool distinct = false,
    List<String>? joins,
    String? where,
    List<dynamic>? params,
    List<String>? groupBy,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final columns = select?.join(', ') ?? '*';
    final distinctSql = distinct ? 'DISTINCT ' : '';
    final joinSql = joins?.join(' ') ?? '';
    final whereSql = where != null ? 'WHERE $where' : '';
    final groupSql =
        groupBy != null && groupBy.isNotEmpty
            ? 'GROUP BY ${groupBy.join(', ')}'
            : '';
    final orderSql = orderBy != null ? 'ORDER BY $orderBy' : '';
    final limitSql = limit != null ? 'LIMIT $limit' : '';
    final offsetSql = offset != null ? 'OFFSET $offset' : '';

    final sql = '''
      SELECT $distinctSql$columns
      FROM $table
      $joinSql
      $whereSql
      $groupSql
      $orderSql
      $limitSql
      $offsetSql
    ''';

    return db.rawQuery(sql, params);
  }

  @override
  Future<dynamic> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return db.insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<dynamic> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? params,
  }) {
    return db.update(
      table,
      values,
      where: where,
      whereArgs: params,
    );
  }

  @override
  Future<dynamic> delete(
    String table, {
    String? where,
    List<dynamic>? params,
  }) {
    return db.delete(
      table,
      where: where,
      whereArgs: params,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> raw(
    String sql, [
    List<dynamic>? args,
  ]) {
    return db.rawQuery(sql, args);
  }
}