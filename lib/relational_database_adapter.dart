import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract class RelationalDatabaseAdapter {
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
  });

  Future<dynamic> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  });

  Future<dynamic> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? params,
  });

  Future<dynamic> delete(
    String table, {
    String? where,
    List<dynamic>? params,
  });

  Future<List<Map<String, dynamic>>> raw(
    String sql, [
    List<dynamic>? args,
  ]);
}