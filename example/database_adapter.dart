import 'package:relational_orm/relational_orm.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseAdapter implements RelationalDatabaseAdapter {
  final Database db;

  DatabaseAdapter(this.db);

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
  }) {
    return queryTableWithJoins(
      table,
      select: select,
      distinct: distinct,
      joins: joins,
      where: where,
      whereArgs: params,
      groupBy: groupBy,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
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

  Future<List<Map<String, dynamic>>> queryTableWithJoins(
    String table, {
    List<String>? select, 
    bool distinct = false,
    List<String>? joins,
    String? where,
    List<dynamic>? whereArgs,
    List<String>? groupBy,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final joinSql =
        joins != null && joins.isNotEmpty ? ' ${joins.join(' ')} ' : '';

    final selectClause =
        select != null && select.isNotEmpty ? select.join(', ') : '*';

    final distinctClause = distinct ? 'DISTINCT ' : '';

    final sql = StringBuffer()
      ..write('SELECT $distinctClause$selectClause FROM $table$joinSql');

    if (where != null && where.trim().isNotEmpty) {
      sql.write(' WHERE $where');
    }

    if (groupBy != null && groupBy.isNotEmpty) {
      sql.write(' GROUP BY ${groupBy.join(', ')}');
    }

    if (orderBy != null) {
      sql.write(' ORDER BY $orderBy');
    }

    if (limit != null) {
      sql.write(' LIMIT $limit');
    }

    if (offset != null) {
      sql.write(' OFFSET $offset');
    }

    sql.write(';');

    return await raw(sql.toString(), whereArgs);
  }
}