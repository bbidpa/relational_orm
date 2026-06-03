class BaseQuery {
  String? where;
  final List<dynamic> params = [];

  int? limitValue;
  int? offsetValue;
  bool distinctValue = false;
  List<String>? selectColumns;
  final List<String> joins = [];
  final List<String> groupByColumns = [];
  String? orderByClause;

  /// ---------- DISTINCT ----------
  void setDistinct() {
    distinctValue = true;
  }

  /// ---------- SELECT ----------
  void setSelect(dynamic columns) {
    if (columns is String) {
      selectColumns = [columns];
    } else if (columns is Iterable<String>) {
      selectColumns = List<String>.from(columns);
    } else {
      throw Exception('select expects String or List<String>');
    }
  }

  /// ---------- SELECT TABLE ----------
  void setSelectTable(String table) {
    selectColumns = ['$table.*'];
  }

  /// ---------- WHERE ----------
  void addWhere(String sql, [List<dynamic>? values]) {
    where = where == null ? sql : '($where) AND $sql';
    if (values != null) params.addAll(values);
  }

  /// ---------- OR WHERE ----------
  void addOrWhere(String sql, [List<dynamic>? values]) {
    where = where == null ? sql : '($where) OR $sql';
    if (values != null) params.addAll(values);
  }

  // ---------- WHERE GROUP ----------
  void addWhereGroup(String sql, [List<dynamic>? values]) {
    where = where == null ? '($sql)' : '($where) AND ($sql)';
    if (values != null) params.addAll(values);
  }

  // ---------- OR WHERE GROUP ----------
  void addOrWhereGroup(String sql, [List<dynamic>? values]) {
    where = where == null ? '($sql)' : '($where) OR ($sql)';
    if (values != null) params.addAll(values);
  }

  /// ---------- WHERE IN ----------
  void addWhereIn(String column, List<dynamic> values) {
    if (values.isEmpty) return;
    final placeholders = List.filled(values.length, '?').join(',');
    addWhere('$column IN ($placeholders)', values);
  }

  /// ---------- LIMIT ----------
  void setLimit(int value) {
    limitValue = value;
  }

  /// ---------- OFFSET ----------
  void setOffset(int value) {
    if (value < 0) {
      throw Exception('offset must be >= 0');
    }
    offsetValue = value;
  }

  /// ---------- ORDER ----------
  void addOrderBy(String column, {bool descending = false}) {
    final dir = descending ? 'DESC' : 'ASC';
    final clause = '$column $dir';
    orderByClause =
        orderByClause == null ? clause : '$orderByClause, $clause';
  }

  /// ---------- GROUP ----------
  void addGroupBy(dynamic columns) {
    if (columns is String) {
      groupByColumns.add(columns);
    } else if (columns is Iterable<String>) {
      groupByColumns.addAll(columns);
    } else {
      throw Exception('groupBy expects String or List<String>');
    }
  }

  /// ---------- JOIN ----------
  void addJoin(String sql) {
    joins.add(sql);
  }

  /// ---------- SUB SQL ----------
  String toSubSql(String table) {
    final sql = buildSql(table);
    return sql.endsWith(';')
        ? sql.substring(0, sql.length - 1)
        : sql;
  }

  /// ---------- SQL ----------
  String buildSql(String table) {
    final selectSql =
        selectColumns != null && selectColumns!.isNotEmpty
            ? selectColumns!.join(', ')
            : '*';

    final distinctSql = distinctValue ? 'DISTINCT ' : '';
    final joinSql = joins.isNotEmpty ? ' ${joins.join(' ')} ' : '';
    final whereSql = where != null ? ' WHERE $where' : '';
    final groupSql = groupByColumns.isNotEmpty
        ? ' GROUP BY ${groupByColumns.join(', ')}'
        : '';
    final orderSql =
        orderByClause != null ? ' ORDER BY $orderByClause' : '';
    final limitSql = limitValue != null ? ' LIMIT $limitValue' : '';
    final offsetSql =
        offsetValue != null && limitValue != null
            ? ' OFFSET $offsetValue'
            : '';

    return 'SELECT $distinctSql$selectSql FROM $table$joinSql$whereSql$groupSql$orderSql$limitSql$offsetSql;';
  }
}
