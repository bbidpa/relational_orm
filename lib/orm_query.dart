import 'relational_model.dart';
import 'relation.dart';
import 'base_query.dart';

class Query<T extends RelationalModel<T>> {
  final T model;
  final BaseQuery base = BaseQuery();

  final List<dynamic> _relations = [];

  Query(this.model) {
    if (model.softDeletes) {
      withoutDeleted();
    }
  }

  // ---------- DISTINCT ----------
  Query<T> distinct() {
    base.setDistinct();
    return this;
  }

  /// ---------- SELECT FIELDS ----------
  Query<T> select(dynamic columns) {
    base.setSelect(columns);
    return this;
  }

  /// ---------- SELECT TABLE ----------
  Query<T> selectTable(String table) {
    base.setSelectTable(table);
    return this;
  }

  /// ---------- WHERE ----------
  Query<T> where(String column, dynamic value) {
    base.addWhere('$column = ?', [value]);
    return this;
  }

  /// ---------- OR WHERE ----------
  Query<T> orWhere(String column, dynamic value) {
    base.addOrWhere('$column = ?', [value]);
    return this;
  }

  /// ---------- WHERE GROUP ----------
  Query<T> whereGroup(void Function(Query<T> q) callback) {
    final sub = Query<T>(model);
    callback(sub);

    if (sub.base.where != null) {
      base.addWhereGroup(
        sub.base.where!,
        sub.base.params,
      );
    }

    return this;
  }

  /// ---------- OR WHERE GROUP ----------
  Query<T> orWhereGroup(void Function(Query<T> q) callback) {
    final sub = Query<T>(model);
    callback(sub);

    if (sub.base.where != null) {
      base.addOrWhereGroup(
        sub.base.where!,
        sub.base.params,
      );
    }

    return this;
  }

  /// ---------- WHERE RAW ----------
  void whereRaw(String sql, [List<dynamic>? params]) {
    base.addWhere(sql, params);
  }

  /// ---------- WHERE IN ----------
  Query<T> whereIn(String column, List<dynamic> values) {
    base.addWhereIn(column, values);
    return this;
  }

  /// ---------- WHERE NULL ----------
  Query<T> whereNull(String column) {
    base.addWhere('$column IS NULL');
    return this;
  }

  /// ---------- WHERE NOT NULL ----------
  Query<T> whereNotNull(String column) {
    base.addWhere('$column IS NOT NULL');
    return this;
  }

  /// ---------- WHERE NULLABLE ----------
  Query<T> whereNullable(String column, dynamic value) {
    if (value == null) {
      return whereNull(column);
    }
    return where(column, value);
  }

  /// ---------- SOFT DELETES ----------
  Query<T> withDeleted() {
    if (base.where != null) {
      base.where = base.where!.replaceAll(
        RegExp(
          '${model.table}\\.deleted_at\\s*(IS\\s+NOT\\s+NULL|IS\\s+NULL|=\\s*NULL|!=\\s*NULL|<>\\s*NULL)',
          caseSensitive: false,
        ),
        '1=1',
      );
    }
    return this;
  }

  /// ---------- ONLY DELETED SCOPE ----------
  Query<T> onlyDeleted() {
    base.addWhere('${model.table}.deleted_at IS NOT NULL');
    return this;
  }

  /// ---------- WITHOUT DELETED SCOPE ----------
  Query<T> withoutDeleted() {
    base.addWhere('${model.table}.deleted_at IS NULL');
    return this;
  }

  // ---------- JOIN ----------
  Query<T> join(
    String table, {
    required String localKey,
    required String foreignKey,
  }) {
    base.addJoin(
      'JOIN $table ON ${model.table}.$localKey = $table.$foreignKey',
    );
    return this;
  }

  // ---------- WHERE HAS ----------
  Query<T> whereHas(
    String relationPath,
    [void Function(Query<dynamic> q)? callback]
  ) {
    final List<dynamic> collectedParams = [];

    final sql = _buildExists(
      relationPath.split('.'),
      model,
      model.table,
      callback,
      collectedParams,
    );

    base.addWhere(sql, collectedParams);
    return this;
  }

  // ---------- OR WHERE HAS ----------
  Query<T> orWhereHas(
    String relationPath,
    [void Function(Query<dynamic> q)? callback]
  ) {
    final List<dynamic> collectedParams = [];

    final sql = _buildExists(
      relationPath.split('.'),
      model,
      model.table,
      callback,
      collectedParams,
    );

    base.addOrWhere(sql, collectedParams);
    return this;
  }

  /// ---------- WHERE RELATION (JUST CALLBACK) ----------
  Query<T> whereRelation(
    String relationPath,
    void Function(Query<dynamic> q) callback,
  ) {
    return whereHas(relationPath, callback);
  }

  /// ---------- OR WHERE RELATION (JUST CALLBACK) ----------
  Query<T> orWhereRelation(
    String relationPath,
    void Function(Query<dynamic> q) callback,
  ) {
    return orWhereHas(relationPath, callback);
  }

  /// ---------- WHERE RELATION EQUALS ----------
  Query<T> whereRelationEquals(
    String relationPath,
    String column,
    dynamic value,
  ) {
    return whereRelation(relationPath, (q) {
      q.where(column, value);
    });
  }

  /// ---------- OR WHERE RELATION EQUALS ----------
  Query<T> orWhereRelationEquals(
    String relationPath,
    String column,
    dynamic value,
  ) {
    return orWhereRelation(relationPath, (q) {
      q.where(column, value);
    });
  }

  /// ---------- WHERE RELATION OP ----------
  Query<T> whereRelationOp(
    String relationPath,
    String column,
    String operator,
    dynamic value,
  ) {
    return whereRelation(relationPath, (q) {
      q.whereRaw('$column $operator ?', [value]);
    });
  }

  /// ---------- OR WHERE RELATION OP ----------
  Query<T> orWhereRelationOp(
    String relationPath,
    String column,
    String operator,
    dynamic value,
  ) {
    return orWhereRelation(relationPath, (q) {
      q.whereRaw('$column $operator ?', [value]);
    });
  }

  /// ---------- WHERE RELATION IN ----------
  Query<T> whereRelationIn(
    String relationPath,
    String column,
    Iterable values,
  ) {
    return whereRelation(relationPath, (q) {
      q.whereIn(column, List.from(values));
    });
  }

  /// ---------- OR WHERE RELATION IN ----------
  Query<T> orWhereRelationIn(
    String relationPath,
    String column,
    Iterable values,
  ) {
    return orWhereRelation(relationPath, (q) {
      q.whereIn(column, List.from(values));
    });
  }

  // Inner build if exists
  String _buildExists(
    List<String> parts,
    RelationalModel<dynamic> parentModel,
    String parentTable,
    void Function(Query<dynamic> q)? callback,
    List<dynamic> paramsCollector,
  ) {
    final relName = parts.first;
    final rel = parentModel.relations()[relName]!;

    final child = rel.child;
    final childTable = child.table;

    final Query<dynamic> sub = child.query();

    // Correlation
    if (rel.type == RelationType.hasMany ||
        rel.type == RelationType.hasOne) {
      sub.whereRaw(
        '$childTable.${rel.foreignKey} = $parentTable.${rel.resolveLocalKey(parentModel)}',
      );
    } else if (rel.type == RelationType.belongsTo) {
      sub.whereRaw(
        '$childTable.${child.primaryKey} = $parentTable.${rel.foreignKey}',
      );
    }

    // Apply relation scope (morphMany, etc.)
    if (rel.scope != null) {
      rel.scope!(sub);
    }

    // Nested whereHas → NEST
    if (parts.length > 1) {
      final nestedSql = _buildExists(
        parts.sublist(1),
        child,
        childTable,
        callback,
        paramsCollector,
      );

      sub.whereRaw(nestedSql);
    } else {
      callback?.call(sub);
    }

    // collect params AFTER callback & nesting
    paramsCollector.addAll(sub.base.params);

    return 'EXISTS (${sub.base.toSubSql(childTable)})';
  }

  /// ---------- JOIN BY RELATION ----------
  Query<T> joinRelation(String path) {
    final parts = path.split('.');

    RelationalModel<dynamic> currentModel = model;
    String currentTable = model.table;

    for (final relName in parts) {
      final rel = currentModel.relations()[relName];
      if (rel == null) {
        throw Exception(
          'Relation "$relName" not found on ${currentModel.runtimeType}',
        );
      }

      final child = rel.child;               // Relational<dynamic>
      final childTable = child.table;

      late final String joinSql;

      if (rel.type == RelationType.belongsTo) {
        joinSql =
            'JOIN $childTable '
            'ON $childTable.${child.primaryKey} = '
            '$currentTable.${rel.foreignKey}';
      }
      else if (rel.type == RelationType.hasOne ||
              rel.type == RelationType.hasMany) {
        joinSql =
            'JOIN $childTable '
            'ON $childTable.${rel.foreignKey} = '
            '$currentTable.${rel.resolveLocalKey(currentModel)}';
      }
      else if (rel.type == RelationType.belongsToMany) {
        final pivotTable = rel.pivotTable;
        final pivotForeignKey = rel.pivotForeignKey;
        final pivotRelatedKey = rel.pivotRelatedKey;

        if (pivotTable == null ||
            pivotForeignKey == null ||
            pivotRelatedKey == null) {
          throw Exception(
            'belongsToMany relation "$relName" is missing pivot metadata',
          );
        }

        final localKey = rel.resolveLocalKey(currentModel);
        final relatedKey = child.primaryKey;

        base.addJoin(
          'JOIN $pivotTable '
          'ON $pivotTable.$pivotForeignKey = '
          '$currentTable.$localKey',
        );

        joinSql =
            'JOIN $childTable '
            'ON $childTable.$relatedKey = '
            '$pivotTable.$pivotRelatedKey';
      }
      else {
        throw Exception(
          'joinRelation not implemented for ${rel.type}',
        );
      }

      // Write JOIN into BaseQuery
      base.addJoin(joinSql);

      // Respect soft deletes
      if (child.softDeletes) {
        base.addWhere('$childTable.deleted_at IS NULL');
      }

      currentModel = child;
      currentTable = childTable;
    }

    return this;
  }

  /// ---------- RELATIONS ----------
  Query<T> include(dynamic relations) {
    if (relations == null) return this;

    if (relations is String ||
        relations is Map ||
        relations is Iterable) {
      _relations.add(relations);
      return this;
    }

    throw Exception('Invalid include type');
  }

  /// ---------- LIMIT ----------
  Query<T> limit(int limit) {
    base.setLimit(limit);
    return this;
  }

  /// ---------- OFFSET ----------
  Query<T> offset(int offset) {
    base.setOffset(offset);
    return this;
  }

  /// ---------- PAGE ----------
  Query<T> page(int page, {int perPage = 20}) {
    if (page < 0) {
      throw Exception('page must be >= 0');
    }

    limit(perPage);
    offset(page * perPage);
    return this;
  }

  /// ---------- PAGE (STARTS FROM 1) ----------
  Query<T> page1(int page, {int perPage = 20}) {
    if (page < 1) {
      throw Exception('page must be >= 1');
    }

    limit(perPage);
    offset((page - 1) * perPage);
    return this;
  }

  /// ---------- ORDER ----------
  Query<T> orderBy(String? column, {bool? descending}) {
    if (column == null) return this;
    base.addOrderBy(column, descending: descending == true);
    return this;
  }

  /// ---------- GROUP ----------
  Query<T> groupBy(dynamic columns) {
    base.addGroupBy(columns);
    return this;
  }

  /// ---------- SQL ----------
  String toSql() => base.buildSql(model.table);

  /// ---------- GET ----------
  Future<List<T>> get() async {
    final rows = await model.dbService.get(
      model.table,
      select: base.selectColumns,
      distinct: base.distinctValue,
      joins: base.joins,
      where: base.where,
      params: base.params,
      groupBy: base.groupByColumns,
      orderBy: base.orderByClause,
      limit: base.limitValue,
      offset: base.offsetValue,
    );

    var items = rows.map((row) => model.fromMap(row)).toList();

    if (_relations.isNotEmpty) {
      items = await model.loadRelations(items, include: _relations);
    }

    return items;
  }

  /// ---------- FIRST ----------
  Future<T?> first() async {
    limit(1);
    final list = await get();
    return list.isEmpty ? null : list.first;
  }

  /// ---------- FIRST OR FAIL ----------
  Future<T> firstOrFail() async {
    final r = await first();
    if (r == null) {
      throw Exception('${model.table} record not found');
    }
    return r;
  }

  /// ---------- FORCE DELETE ----------
  Future<int> forceDelete() async {
    return await model.dbService.delete(
      model.table,
      where: base.where,
      params: base.params,
    );
  }
}
