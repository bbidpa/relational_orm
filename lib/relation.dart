// relation.dart

import 'relational_model.dart';
import 'morph_placeholder.dart';

enum RelationType {
  hasOne,
  hasMany,
  belongsTo,
  belongsToMany,
  morphTo,
}

class Relation<Parent extends RelationalModel<Parent>, Child extends RelationalModel<Child>> {
  final RelationalModel<Child> child;

  final RelationType type;

  /// FK on child (hasOne / hasMany) OR FK on parent (belongsTo)
  final String foreignKey;

  /// Local model key (defaults to model.primaryKey)
  final String? localKey;

  /// Pivot metadata
  final String? pivotTable;
  final String? pivotForeignKey;
  final String? pivotRelatedKey;
  final RelationScope? scope;
  final String? morphTypeColumn;
  final Map<String, RelationalModel>? morphMap;

  const Relation({
    required this.child,
    required this.type,
    required this.foreignKey,
    this.localKey,
    this.scope,   
    this.pivotTable,
    this.pivotForeignKey,
    this.pivotRelatedKey,
    this.morphTypeColumn,
    this.morphMap,
  });

  /// If localKey is null → use primaryKey of the Parent model
  String resolveLocalKey(Parent parent) {
    return localKey ?? parent.primaryKey;
  }

  bool get many => type == RelationType.hasMany || type == RelationType.belongsToMany;
}

Relation<Parent, Child> hasOne<Parent extends RelationalModel<Parent>,Child extends RelationalModel<Child>>(
  RelationalModel<Child> child,
  String foreignKey,
  [
    String? localKey,
    RelationScope? scope,
  ]
) {
  return Relation(
    child: child,
    type: RelationType.hasOne,
    foreignKey: foreignKey,
    localKey: localKey,
    scope: scope, 
  );
}

Relation<Parent, Child> hasMany<Parent extends RelationalModel<Parent>,Child extends RelationalModel<Child>>(
  RelationalModel<Child> child,
  String foreignKey,
  [
    String? localKey,
    RelationScope? scope,
  ]
) {
  return Relation(
    child: child,
    type: RelationType.hasMany,
    foreignKey: foreignKey,
    localKey: localKey,
    scope: scope, 
  );
}

Relation<Parent, Child> belongsTo<Parent extends RelationalModel<Parent>,Child extends RelationalModel<Child>>(
  RelationalModel<Child> child,
  String foreignKey,
  [
    String? ownerKey,
    RelationScope? scope,
  ]
) {
  return Relation(
    child: child,
    type: RelationType.belongsTo,
    foreignKey: foreignKey,
    localKey: ownerKey, // null -> remote PK
    scope: scope, 
  );
}

Relation<Parent, Child> belongsToMany<Parent extends RelationalModel<Parent>, Child extends RelationalModel<Child>>(
  RelationalModel<Child> child,
  String pivotTable,
  String pivotForeignKey,
  String pivotRelatedKey, [
  RelationScope? scope,
]) {
  return Relation(
    child: child,
    type: RelationType.belongsToMany,
    foreignKey: '',          // unused
    localKey: null,          // unused
    pivotTable: pivotTable,
    pivotForeignKey: pivotForeignKey,
    pivotRelatedKey: pivotRelatedKey,
    scope: scope,
  );
}

Relation<Parent, Child> morphMany<Parent extends RelationalModel<Parent>, Child extends RelationalModel<Child>>(
  RelationalModel<Child> child,
  String foreignKey,       // e.g. 'subject_uuid'
  String typeColumn,       // e.g. 'subject_type'
  String typeValue,        // e.g. 'publisher'
  [
    String? localKey,      // e.g. 'uuid'
    RelationScope? scope,  // optional extra filtering
  ]
) {
  // Base polymorphic match
  RelationScope autoScope;
  autoScope = (q) => q.where(typeColumn, typeValue);

  // Merge autoScope + userScope
  RelationScope? finalScope;
  if (scope != null) {
    finalScope = (q) => scope(autoScope(q));  // autoScope FIRST → then user scope
  } else {
    finalScope = autoScope;
  }

  return hasMany<Parent, Child>(
    child,
    foreignKey,
    localKey,
    finalScope, 
  );
}

Relation<Parent, Child> morphOne<Parent extends RelationalModel<Parent>,Child extends RelationalModel<Child>>(
  RelationalModel<Child> child,
  String foreignKey,     // e.g. "subject_uuid"
  String typeColumn,     // e.g. "subject_type"
  String typeValue,      // e.g. "publisher"
  [
    String? localKey,
    RelationScope? scope
  ]
) {
  // auto scope for the morph
  final RelationScope autoScope;
  autoScope = (q) => q.where(typeColumn, typeValue);

  // Merge autoScope + userScope
  RelationScope? finalScope;
  if (scope != null) {
    finalScope = (q) => scope(autoScope(q));  // autoScope FIRST → then user scope
  } else {
    finalScope = autoScope;
  }

  return hasOne<Parent, Child>(
    child,
    foreignKey,
    localKey,
    finalScope,   // automatically applied
  );
}

Relation<Parent, dynamic> morphTo<Parent extends RelationalModel<Parent>>(
  String typeColumn,
  String uuidColumn,
  Map<String, RelationalModel> map,
) {
  return Relation(
    child: MorphPlaceholder(),     // SAFE dummy, never actually queried
    type: RelationType.morphTo,
    foreignKey: uuidColumn,
    morphTypeColumn: typeColumn,
    morphMap: map,
  );
}