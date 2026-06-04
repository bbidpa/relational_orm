import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

import 'helper.dart';
import 'relational_database_adapter.dart';
import 'orm_query.dart';
import 'hydrator.dart';
import 'relation.dart';
import 'relational_orm_config.dart';

typedef RelationScope = Query<dynamic> Function(Query<dynamic>);

/// Abstract base class that provides RelationalModel-style CRUD operations
/// for any model.
/// 
/// Each model must:
/// - provide a [table] name,
/// - implement [fromMap] to hydrate itself from a row,
/// - implement [toMap] to serialize itself for insert/update.
abstract class RelationalModel<T extends RelationalModel<T>> {
  /// Table name this model belongs to (e.g. "rooms", "bots").
  String get table;

  // Primary key
  String get primaryKey => 'id';

  // Is primary autoincrement integer
  bool get autoIncrementPrimary => true;

  // Enable this for models that have deleted_at column not null
  bool get softDeletes => false;

  // Do created_at and updated_at exist in database and automatically update them
  bool get timestamps => true;

  @JsonKey(includeFromJson: false, includeToJson: false)
  Map<String, dynamic>? pivot;

  /// Universal DB service
  RelationalDatabaseAdapter get dbService => RelationalOrmConfig.database;

  /// Track which relations were included and loaded last
  @JsonKey(includeFromJson: false, includeToJson: false)
  Map<String, RelationScope> loadedIncludes = {};

  @JsonKey(includeToJson: false, includeFromJson: false)
  Map<String, dynamic> resolvedRelations = {};

  @JsonKey(includeToJson: false, includeFromJson: false)
  final Map<String, dynamic> _pendingAttributes = {};

  // Query method
  Query<T> query() {
    return Query<T>(this as T);
  }

  /// Hydrate method. Hydrate either a single row or many (no async here).
  Hydrator<T> hydrate(List<Map<String, dynamic>> rows) {
    return Hydrator<T>(this as T, rows);
  }

  /// Each model overrides this to declare relations
  Map<String, Relation<T, dynamic>> relations() => {};

  /// Find a record by primary key (`id`).
  Future<T?> find(dynamic pkValue, {dynamic include = const {}}) async 
  {
    final pkName = primaryKey;

    final result = await query()
        .where(pkName, pkValue)
        .include(include)
        .first();

    return result;
  }

  /// Find a record by primary key (`id`) or throw if not found.
  Future<T> findOrFail(dynamic pkValue, {List<String> include = const []}) async 
  {
    final result = await find(pkValue, include: include);

    if (result == null) {
      throw Exception("$table: record with primary key '$pkValue' not found");
    }

    return result;
  }

  void setAttribute(String column, dynamic value) {
    _pendingAttributes[column] = value;
  }

  /// Find multiple records by a list of IDs.
  Future<List<T>> all({dynamic include = const []}) async {
    return await query()
        .include(include)
        .get();
  }

  /// Find multiple records by a list of IDs.
  Future<List<T>> findMany(List<dynamic> pkValues, {dynamic include = const []}) async {
    final pkName = primaryKey;
      return await query()
        .whereIn(pkName, pkValues)
        .include(include)
        .get();
  }

  /// Get the first record matching a condition.
  Future<T?> firstWhere(String column, dynamic value) async 
  {
    final rows = await dbService.get(table, where: '$column = ?', params: [value], limit: 1);
    return rows.isNotEmpty ? fromMap(rows.first) : null;
  }

  /// Get all records matching a condition.
  Future<List<T>> where(String column, dynamic value) async 
  {
    final rows = await dbService.get(table, where: '$column = ?', params: [value]);
    return rows.map((e) => fromMap(e)).toList();
  }

  /// Insert this model into the database.
  /// Returns the inserted row ID.
  static Future<void> insert<T extends RelationalModel<T>>(T model, Map<String, dynamic> data) async {
    await model.dbService.insert(model.table, data);
  }

  /// Insert and get id
  static Future<int> insertGetId<T extends RelationalModel<T>>(T model, Map<String, dynamic> data) async {
    return await model.dbService.insert(model.table, data);
  }

  /// Create model from data
  static Future<T> create<T extends RelationalModel<T>>(T model, Map<String, dynamic> data) async {
    final db = model.dbService;
    final pkValue = await db.insert(model.table, data);
    final pkName = model.primaryKey;

    final row = await db.get(model.table, where: '$pkName = ?', params: [pkValue], limit: 1);
    return model.fromMap(row.first);
  }

  /// Save itself, auto-generates UUID if needed, returns fresh hydrated model.
  Future<T?> save({bool autoTimestamps = true, bool autoId = true}) async 
  {
    final map = toMap();

    // Apply pending changes!
    if (_pendingAttributes.isNotEmpty) {
      map.addAll(_pendingAttributes);
      _pendingAttributes.clear();
    }

    final pkName = primaryKey;
    var pkValue = map[pkName];

    // -----------------------------------------------------
    // AUTO GENERATE UUID FOR NON-AUTOINCREMENT MODELS
    // -----------------------------------------------------
    if (!autoIncrementPrimary) {
      final missing = pkValue == null || pkValue.toString().isEmpty;

      if (missing) {
        if (autoId) {
          // Generate UUID only when missing
          final newUuid = const Uuid().v4();
          map[pkName] = newUuid;
          pkValue = newUuid;
        } else {
          throw Exception(
            "Cannot save $table: primary key '$pkName' is missing and autoId=false.",
          );
        }
      }
    }

    // TIMESTAMPS
    if (timestamps) {
      if (autoTimestamps && map.containsKey('updated_at')) {
        map['updated_at'] = Helper.now(format: 'sql');
      }

      if (map.containsKey('created_at') && map['created_at'] == null) {
        map['created_at'] = Helper.now(format: 'sql');
      }
    }

    // DETERMINE INSERT vs UPDATE
    bool exists;

    if (autoIncrementPrimary) {
      exists = pkValue != null;
    } else {
      // For UUID primary keys
      exists = await find(pkValue) != null;
    }

    // INSERT / UPDATE
    dynamic finalPkValue;

    if (!exists) {
      if (autoIncrementPrimary) {
        finalPkValue = await dbService.insert(table, map);
      } else {
        await dbService.insert(table, map);
        finalPkValue = pkValue;
      }
    } else {
      finalPkValue = pkValue;

      await dbService.update(
        table,
        map,
        where: '$pkName = ?',
        params: [pkValue],
      );
    }

    final fresh = await find(finalPkValue, include: loadedIncludes);

    return fresh;
  }

  /// Refresh model
  Future<T> refresh({dynamic include, bool append = true}) async {
    final pkValue = toMap()[primaryKey];

    if (pkValue == null) {
      throw Exception('Cannot refresh an unsaved model.');
    }

    Map<String, RelationScope> adjustedIncludes;
    if (include != null && append == true) {
      adjustedIncludes = mergeIncludes(include, loadedIncludes);
    } else if (include != null && append == false) {
      adjustedIncludes = mergeIncludes(include, {});
    } else {
      adjustedIncludes = loadedIncludes;
    }

    // Reload using the same relations that were previously loaded
    final fresh = await find(pkValue, include: adjustedIncludes);

    if (fresh == null) {
      throw Exception('Model no longer exists in database.');
    }

    return fresh;
  }

  Map<String, RelationScope> mergeIncludes(dynamic newIncludes, Map<String, RelationScope> existingIncludes) {
    final normalized = normalizeIncludes(newIncludes);

    // print('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
    // print(getLoadedIncludePaths());
    // print(getRelations());

    for (final entry in normalized.entries) {
      existingIncludes[entry.key] = mergeRelationScopes(
        entry.value,
        existingIncludes[entry.key],
      );
    }

    // print('XX%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
    // print(getLoadedIncludePaths());

    return existingIncludes;
  }

  /// Merge relation scopes
  RelationScope mergeRelationScopes(
    RelationScope newScope,
    RelationScope? oldScope,
  ) {
    if (oldScope == null) return newScope;

    return (q) {
      final q1 = oldScope(q);
      return newScope(q1);
    };
  }

  /// Get loaded includes
  Map<String, RelationScope> getLoadedIncludes() 
  {
    return loadedIncludes;
  }

  /// Get names of loaded includes
  List<String> getLoadedIncludePaths() {
    final result = <String>{};

    void walk(RelationalModel model, String prefix) {
      for (final rel in model.loadedIncludes.keys) {
        final path = prefix.isEmpty
            ? rel
            : '$prefix.$rel';

        result.add(path);

        final value = model.getRelation(rel);

        if (value is RelationalModel) {
          walk(value, path);
        }

        if (value is List) {
          for (final item in value) {
            if (item is RelationalModel) {
              walk(item, path);
            }
          }
        }
      }
    }

    walk(this, '');

    return result.toList();
  }

  /// Update this model in the database.
  /// - If [where] is provided, it updates those rows.
  /// - Otherwise, you should provide a primary key in `toMap()`.
  Future<int> update({String? where, List<dynamic>? params}) async 
  {
    return await dbService.update(table, toMap(), where: where, params: params);
  }

  /// Delete this model safely through RelationalModel.
  /// - Respects softDeletes
  /// - Uses Query.forceDelete for physical delete
  /// - Prevents mass-delete (must have PK)
  Future<int> delete({Map<String, dynamic>? where}) async 
  {
    final map = toMap();
    final pk = primaryKey;
    final id = map[pk];

    if (id == null) {
      throw Exception('Cannot delete: primary key ($pk) is null.');
    }

    // Soft delete mode
    if (softDeletes) {
      final $now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().toUtc());

      return await dbService.update(
        table,
        {'deleted_at': $now},
        where: '$pk = ?',
        params: [id],
      );
    }

    // Build query
    var q = query().where(pk, id);

    // Additional key=>value constraints
    if (where != null) {
      where.forEach((key, value) {
        q = q.where(key, value);
      });
    }

    // Perform raw delete using your Query.forceDelete
    return await q.forceDelete();
  }

  // Every Freezed model already has these thanks to @Freezed(toJson: true)
  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  // Default hydration using Freezed’s generated `fromJson`
  T fromMap(Map<String, dynamic> map) {
    return (this as dynamic).fromJson(map) as T;
  }

  // Default serialization using Freezed’s generated `toJson`
  Map<String, dynamic> toMap() {
    return (this as dynamic).toJson() as Map<String, dynamic>;
  }

  /// Serialize any model to Map (shortcut for toJson)
  Map<String, dynamic> serialize() {
    return toMap();
  }

  /// Hydrate a single row into a model (no query).
  T hydrateOne(Map<String, dynamic> row) {
    return fromMap(row);
  }

  /// Hydrate many rows into models (no query).
  List<T> hydrateMany(List<Map<String, dynamic>> rows) {
    return rows.map((row) => fromMap(row)).toList();
  }

  /// Mark includes as loaded
  void setLoadedIncludes(Map<String, RelationScope> includes) {
    for (final entry in includes.entries) {
      loadedIncludes[entry.key] = mergeRelationScopes(
        entry.value,
        loadedIncludes[entry.key],
      );
    }
  }

  // Load relations 
  Future<List<T>> loadRelations(List<T> items, {dynamic include}) async 
  {
    if (include == null) return items;

    // Allow only List or Map
    if (include is! List && include is! Map) {
      throw Exception(
        "Includes must be a List or Map. Got: ${include.runtimeType}"
      );
    }

    if (include.isEmpty) return items;

    // 1. Normalize includes → { relationName: scopeFunction }
    final normalized = normalizeIncludes(include);

    // 2. For each relation, apply the scope and load it
    for (final entry in normalized.entries) {
      final relName = entry.key;
      final includeScope = entry.value; // RelationScope

      final rel = relations()[relName];
      if (rel == null) continue;

      if (rel.type == RelationType.morphTo) {
        // MorphTo uses the scope directly on *real* models
        await _loadMorphTo(items, rel, relName, includeScope);
        continue;
      }

      // Non-morph relations → keep old behaviour
      final scopedQuery = includeScope(rel.child.query());

      await _loadHasOneOrMany(items, rel, relName, overrideQuery: scopedQuery);
      await _loadBelongsTo(items, rel, relName, overrideQuery: scopedQuery);
      await _loadBelongsToMany(items, rel, relName, overrideQuery: scopedQuery);

      for (final item in items) {
        item.setLoadedIncludes({relName: includeScope});
      }
    }

    return items;
  }

  Future<void> _loadHasOneOrMany(List<T> items, Relation<T, dynamic> rel, String name, {Query<dynamic>? overrideQuery}) async 
  {
    if (rel.type != RelationType.hasOne && rel.type != RelationType.hasMany) return;

    // final parentKeys = _getParentKeys(items, rel);
    final parentKeys = items
        .map((p) => (p as dynamic).toMap()[rel.resolveLocalKey(p)])
        .where((x) => x != null)
        .toSet()
        .toList();

    if (parentKeys.isEmpty) return;

    // final children = await rel.child.query().whereIn(rel.foreignKey, parentKeys).get();

    final rawQuery  = overrideQuery ?? rel.child.query();

    Query<dynamic> q = rawQuery;

    // Apply base relation scope (morphMany() etc.)
    if (rel.scope != null) {
      q = rel.scope!(q);
    }

    final children = await q.whereIn(rel.foreignKey, parentKeys).get();

    final byFk = <dynamic, List<dynamic>>{};
    for (final child in children) {
      final fk = (child as dynamic).toMap()[rel.foreignKey];
      byFk.putIfAbsent(fk, () => []).add(child);
    }

    for (final parent in items) {
      final p = parent as dynamic;
      final key = p.toMap()[rel.resolveLocalKey(parent)];
      final related = byFk[key] ?? [];

      if (rel.type == RelationType.hasOne) {
        p.setRelation(name, related.isNotEmpty ? related.first : null);
      } else {
        p.setRelation(name, related);
      }
    }
  }

  Future<void> _loadBelongsTo(List<T> items, Relation<T, dynamic> rel, String name, {Query<dynamic>? overrideQuery}) async {
    if (rel.type != RelationType.belongsTo) return;

    // final fkValues = _getFKValues(items, rel);
    final fkValues = items
        .map((i) => (i as dynamic).toMap()[rel.foreignKey])
        .where((x) => x != null)
        .toSet()
        .toList();

    if (fkValues.isEmpty) return;

    // final parents = await rel.child.query().whereIn(rel.child.primaryKey, fkValues).get();

    final rawQuery  = overrideQuery ?? rel.child.query();

    Query<dynamic> q = rawQuery;

    // Apply base relation scope (optional)
    if (rel.scope != null) {
      q = rel.scope!(q);
    }

    final parents = await q.whereIn(rel.child.primaryKey, fkValues).get();

    final mapById = {
      for (final p in parents)
        (p as dynamic).toMap()[rel.child.primaryKey]: p,
    };

    for (final item in items) {
      final i = item as dynamic;
      final fk = i.toMap()[rel.foreignKey];
      i.setRelation(name, mapById[fk]);
    }
  }

  /// Belongs to many, used with pivot table
  Future<void> _loadBelongsToMany(
    List<T> items,
    Relation<T, dynamic> rel,
    String name, {
    Query<dynamic>? overrideQuery,
  }) async {
    if (rel.type != RelationType.belongsToMany) return;

    final pivotTable = rel.pivotTable!;
    final pivotFk = rel.pivotForeignKey!;
    final pivotRelated = rel.pivotRelatedKey!;

    // Parent IDs
    final parentPk = primaryKey;
    final parentIds = items
        .map((p) => (p as dynamic).toMap()[parentPk])
        .where((id) => id != null)
        .toSet()
        .toList();

    if (parentIds.isEmpty) return;

    // 1) Load pivot rows
    final placeholders = List.filled(parentIds.length, '?').join(',');
    final pivotRows = await dbService.get(
      pivotTable,
      where: '$pivotFk IN ($placeholders)',
      params: parentIds,
    );

    // Always set relation (even if empty)
    if (pivotRows.isEmpty) {
      for (final parent in items) {
        (parent as dynamic).setRelation(name, <dynamic>[]);
      }
      return;
    }

    // 2) Group pivot rows by parent id
    final Map<dynamic, List<Map<String, dynamic>>> pivotByParent = {};

    for (final row in pivotRows) {
      final pid = row[pivotFk];
      if (pid == null) continue;
      pivotByParent.putIfAbsent(pid, () => []).add(row);
    }

    // 3) Collect all related IDs
    final allRelatedIds = pivotRows
        .map((r) => r[pivotRelated])
        .where((id) => id != null)
        .toSet()
        .toList();

    if (allRelatedIds.isEmpty) {
      for (final parent in items) {
        (parent as dynamic).setRelation(name, <dynamic>[]);
      }
      return;
    }

    // 4) Load related models
    final rawQuery = overrideQuery ?? rel.child.query();
    Query<dynamic> q = rawQuery;

    if (rel.scope != null) {
      q = rel.scope!(q);
    }

    final childPk = rel.child.primaryKey;
    final children = await q.whereIn(childPk, allRelatedIds).get();

    // 5) Index children by id
    final Map<dynamic, dynamic> childrenById = {
      for (final c in children)
        (c as dynamic).toMap()[childPk]: c,
    };

    // 6) Attach models + pivot data
    for (final parent in items) {
      final pid = (parent as dynamic).toMap()[parentPk];
      final pivotRowsForParent = pivotByParent[pid] ?? const [];

      final relatedModels = <dynamic>[];

      for (final pivotRow in pivotRowsForParent) {
        final relatedId = pivotRow[pivotRelated];
        final model = childrenById[relatedId];
        if (model == null) continue;

        // 🔑 Laravel-style pivot attachment
        (model as dynamic).pivot =
            Map<String, dynamic>.from(pivotRow);

        relatedModels.add(model);
      }

      (parent as dynamic).setRelation(name, relatedModels);
    }
  }


  // Load morph to
  Future<void> _loadMorphTo(
    List<T> items,
    Relation<T, dynamic> rel,
    String name,
    RelationScope? includeScope,
  ) async {
    if (rel.type != RelationType.morphTo) return;

    final typeColumn = rel.morphTypeColumn!;
    final fkColumn   = rel.foreignKey;
    final models     = rel.morphMap!;

    // ---- Group child records by type ----
    final Map<String, List<dynamic>> groupedIds = {};

    for (final item in items) {
      final row = (item as dynamic).toMap();
      final typeValue = row[typeColumn];
      final fkValue   = row[fkColumn];

      if (typeValue == null || fkValue == null) continue;
      if (!models.containsKey(typeValue)) continue;

      groupedIds.putIfAbsent(typeValue, () => []).add(fkValue);
    }

    // ---- For each type → query the correct *real* model ----
    final Map<String, Map<dynamic, dynamic>> loadedParents = {};

    for (final entry in groupedIds.entries) {
      final type = entry.key;
      final ids  = entry.value;

      final model = models[type]!; // e.g. Deployment()

      // Start from the real model's query
      Query<dynamic> q = model.query();

      // Apply include scope from normalizeIncludes → handles 'deployment.model'
      if (includeScope != null) {
        q = includeScope(q);
      }

      // If you ever add rel.scope for morphTo itself, apply it too:
      if (rel.scope != null) {
        q = rel.scope!(q);
      }

      final parents = await q.whereIn(model.primaryKey, ids).get();

      loadedParents[type] = {
        for (final p in parents)
          (p as dynamic).toMap()[model.primaryKey]: p
      };
    }

    // ---- Assign parent per item ----
    for (final item in items) {
      final map = (item as dynamic).toMap();
      final typeValue = map[typeColumn];
      final fkValue   = map[fkColumn];

      if (typeValue == null ||
          fkValue == null ||
          !loadedParents.containsKey(typeValue)) continue;

      final parent = loadedParents[typeValue]![fkValue];
      item.setRelation(name, parent);
    }
  }

  // BELONGS TO: child.associate('publisher', parent), sets FK on this model, requires save()
  void associate(String relName, RelationalModel parent) 
  {
    final rel = relations()[relName];
    if (rel == null || rel.type != RelationType.belongsTo) {
      throw Exception("$relName is not a belongsTo relation.");
    }

    final fk = rel.foreignKey;     // e.g. publisher_uuid, publisher_id
    final pk = parent.primaryKey;  // child.parentID = parent.primaryKey
    final parentId = parent.toMap()[pk];

    if (parentId == null) {
      throw Exception("Cannot associate: parent has no primary key.");
    }

    // Queue FK change, but do NOT touch DB or rebuild object
    setAttribute(fk, parentId);

    // Keep object available for eager loaded memory reads
    setRelation(relName, parent);
  }

  /// HAS ONE / HAS MANY: parent.attach('hosts', child), sets FK on child, requires save()
  void attach(String relName, RelationalModel child) 
  {
    final rel = relations()[relName];
    if (rel == null ||
        (rel.type != RelationType.hasOne && rel.type != RelationType.hasMany)) {
      throw Exception("$relName is not a hasOne/hasMany relation.");
    }

    final fk = rel.foreignKey; // e.g. publisher_id on HOST model

    // Resolve local key (parent primary key or custom)
    final localKeyValue = (this as dynamic).toMap()[rel.resolveLocalKey(this as T)];

    if (localKeyValue == null) {
      throw Exception("Cannot attach child: parent has no primary key.");
    }

    // Queue child foreign key update, do NOT save
    child.setAttribute(fk, localKeyValue);

    // Store related child in memory (eager-loaded relation)
    if (rel.type == RelationType.hasOne) {
      setRelation(relName, child);
    } else {
      final current = (getRelation(relName) ?? []) as List<dynamic>;
      current.add(child);
      setRelation(relName, current);
    }
  }

  // HAS MANY: parent.attachMany('hosts', [...])
  void attachMany(String relName, List<RelationalModel> children) {
    for (final child in children) {
      attach(relName, child);
    }
  }

  /// Attach with pivot table. Saved into db
  Future<void> attachPivot(
    String relName,
    RelationalModel related, {
    Map<String, dynamic>? pivot,
  }) async {
    final rel = relations()[relName];

    if (rel == null) {
      throw Exception(
        "Relation '$relName' is not defined on ${runtimeType}."
      );
    }

    if (rel.type != RelationType.belongsToMany) {
      throw Exception(
        "attachPivot() can only be used with belongsToMany relations. "
        "'$relName' is ${rel.type}."
      );
    }

    final parentId = toMap()[primaryKey];
    final relatedId = related.toMap()[related.primaryKey];

    if (parentId == null) {
      throw Exception(
        "Cannot attachPivot('$relName'): parent model is not saved."
      );
    }

    if (relatedId == null) {
      throw Exception(
        "Cannot attachPivot('$relName'): related model is not saved."
      );
    }

    await dbService.insert(rel.pivotTable!, {
        rel.pivotForeignKey!: parentId,
        rel.pivotRelatedKey!: relatedId,
        ...?pivot,
      },
      // conflictAlgorithm: ConflictAlgorithm.ignore
    );

    // Optional: keep in-memory relation consistent if already loaded
    final current = getRelation(relName);

    if (current is List) {
      final relatedPk = related.primaryKey;
      final relatedIdValue = related.toMap()[relatedPk];

      final exists = current.any(
        (e) =>
          (e as dynamic).toMap()[relatedPk] == relatedIdValue,
      );

      if (!exists) {
        // Attach pivot data to the related model
        (related as dynamic).pivot = {
          rel.pivotForeignKey!: parentId,
          rel.pivotRelatedKey!: relatedId,
          ...?pivot,
        };

        current.add(related);
      }
    }
  }

  /// Update pivot data between this model and a related model.
  /// Updates DB immediately. Does NOT reload models.
  Future<int> updatePivot(
    String relName,
    dynamic relatedId,
    Map<String, dynamic> values,
  ) async {
    final rel = relations()[relName];

    if (rel == null) {
      throw Exception(
        "Relation '$relName' is not defined on $runtimeType."
      );
    }

    if (rel.type != RelationType.belongsToMany) {
      throw Exception(
        "updatePivot() can only be used with belongsToMany relations. "
        "'$relName' is ${rel.type}."
      );
    }

    if (values.isEmpty) {
      return 0;
    }

    final parentId = toMap()[primaryKey];
    if (parentId == null) {
      throw Exception(
        "Cannot updatePivot('$relName'): parent model is not saved."
      );
    }

    if (relatedId == null) {
      throw Exception(
        "Cannot updatePivot('$relName'): relatedId is null."
      );
    }

    // 1) Update pivot table
    final affected = await dbService.update(
      rel.pivotTable!,
      values,
      where:
        '${rel.pivotForeignKey} = ? AND ${rel.pivotRelatedKey} = ?',
      params: [parentId, relatedId],
    );

    // 2) Best-effort in-memory sync (Laravel does this implicitly)
    final current = getRelation(relName);
    if (current is List) {
      for (final item in current) {
        final id =
            (item as dynamic).toMap()[rel.child.primaryKey];
        if (id == relatedId) {
          (item as dynamic).pivot ??= {};
          (item as dynamic).pivot!.addAll(values);
          break;
        }
      }
    }

    return affected;
  }

  /// Detach from pivot table by related model ID.
  /// Deleted from DB immediately.
  Future<void> detachPivot(
    String relName,
    dynamic relatedId,
  ) async {
    final rel = relations()[relName];

    if (rel == null) {
      throw Exception(
        "Relation '$relName' is not defined on $runtimeType."
      );
    }

    if (rel.type != RelationType.belongsToMany) {
      throw Exception(
        "detachPivotById() can only be used with belongsToMany relations. "
        "'$relName' is ${rel.type}."
      );
    }

    final parentId = toMap()[primaryKey];

    if (parentId == null) {
      throw Exception(
        "Cannot detachPivotById('$relName'): parent model is not saved."
      );
    }

    if (relatedId == null) {
      throw Exception(
        "Cannot detachPivotById('$relName'): relatedId is null."
      );
    }

    await dbService.delete(
      rel.pivotTable!,
      where:
        '${rel.pivotForeignKey} = ? AND ${rel.pivotRelatedKey} = ?',
      params: [parentId, relatedId],
    );

    // Optional: keep in-memory relation consistent if already loaded
    final current = getRelation(relName);
    if (current is List) {
      current.removeWhere(
        (e) =>
          (e as dynamic).toMap()[rel.child.primaryKey] == relatedId,
      );
    }
  }

  /// Normalize inputs
  Map<String, RelationScope> normalizeIncludes(dynamic includesInput) 
  {
    // Accept both List and Map for root
    final List includes = includesInput is Map
        ? [includesInput]
        : (includesInput ?? []) as List;

    final Map<String, RelationScope> result = {};

    // Helper: merge two scopes together
    RelationScope mergeScopes(RelationScope? oldScope, RelationScope newScope) {
      if (oldScope == null) return newScope;

      return (q) {
        final q1 = oldScope(q);
        final q2 = newScope(q1);
        return q2;
      };
    }

    // Helper: create a scope from nested include list
    RelationScope scopeFromNested(List nested) {
      return (q) => q.include(nested);
    }

    for (final inc in includes) {
      // CASE 1: Simple string (dot path)
      if (inc is String) {
        final parts = inc.split('.');
        final rel = parts.first;

        if (parts.length == 1) {
          // simple relation
          result[rel] = mergeScopes(result[rel], (q) => q);
        } else {
          final nested = [parts.sublist(1).join('.')];
          result[rel] =
              mergeScopes(result[rel], scopeFromNested(nested));
        }

        continue;
      }

      // CASE 2: Map { relation: config }
      if (inc is Map) {
        for (final entry in inc.entries) {
          final relName = entry.key.toString();
          final cfg = entry.value;

          RelationScope newScope;

          if (cfg is Function) {
            newScope = (q) {
              final out = cfg(q);
              return out is Query ? out : q;
            };
          } else if (cfg is List) {
            newScope = scopeFromNested(cfg);
          } else if (cfg is Map) {
            newScope = scopeFromNested([cfg]);
          } else if (cfg == true) {
            newScope = (q) => q;
          } else {
            throw Exception("Invalid include config for '$relName': $cfg");
          }

          result[relName] = mergeScopes(result[relName], newScope);
        }

        continue;
      }

      // CASE 3: List inside list → flatten / merge
      if (inc is List) {
        if (inc.isEmpty) continue;

        final nested = normalizeIncludes(inc); // recursion
        for (final e in nested.entries) {
          result[e.key] = mergeScopes(result[e.key], e.value);
        }
        continue;
      }

      // print("normalizeIncludes() invalid inc type: ${inc.runtimeType} value=$inc");

      throw Exception("Invalid include type: $inc");
    }

    return result;
  }

  /// Get relation
  dynamic getRelation(String name) {
    return resolvedRelations[name];
  }

  /// Get relations
  dynamic getRelations() {
    return resolvedRelations;
  }

  /// Set relation
  void setRelation(String name, dynamic value) {
    // Create a dynamic map to store resolved relations
    (this as dynamic).resolvedRelations ??= <String, dynamic>{};

    // Save relation
    (this as dynamic).resolvedRelations[name] = value;
  }
}

// Converter for freezed
class JsonMapConverter implements JsonConverter<Map<String, dynamic>?, Object?> {
  const JsonMapConverter();

  @override
  Map<String, dynamic>? fromJson(Object? json) {
    if (json == null) return null;

    if (json is Map<String, dynamic>) {
      return json;
    }

    if (json is String) {
      if (json.trim().isEmpty) return null;

      try {
        final decoded = jsonDecode(json);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  @override
  Object? toJson(Map<String, dynamic>? object) {
    if (object == null) return null;
    return jsonEncode(object);
  }
}

// Converter for freezed
class BoolIntConverter implements JsonConverter<bool, Object?> {
  const BoolIntConverter();

  @override
  bool fromJson(Object? json) {
    if (json is bool) return json;
    if (json is int) return json != 0;
    return false; // fallback
  }

  @override
  Object toJson(bool object) => object ? 1 : 0;
}

class BoolIntNullableConverter implements JsonConverter<bool?, Object?> {
  const BoolIntNullableConverter();

  @override
  bool? fromJson(Object? json) {
    if (json == null) return null;
    if (json is bool) return json;
    if (json is int) return json != 0;
    return null; // invalid → null
  }

  @override
  Object? toJson(bool? object) {
    if (object == null) return null;
    return object ? 1 : 0;
  }
}

class EmptyToNullConverter implements JsonConverter<String?, String?> {
  const EmptyToNullConverter();

  @override
  String? fromJson(String? value) {
    if (value == null) return null;
    return value.trim().isEmpty ? null : value;
  }

  @override
  String? toJson(String? value) {
    return value; // null stays null
  }
}
