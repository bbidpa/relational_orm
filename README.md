# relational_orm

A lightweight active record style ORM for Dart and Flutter.

It supports:

- query builder
- eager loading
- `hasOne`, `hasMany`, `belongsTo`, `belongsToMany`
- polymorphic relations
- soft deletes
- timestamps
- SQLite/sqflite adapter support

## Setup

```dart
import 'package:relational_orm/relational_orm.dart';

RelationalOrmConfig.configure(
  database: MyCustomRelationalDatabase(),
);
```