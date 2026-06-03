import 'relational_model.dart';

class Hydrator<T extends RelationalModel<T>> {
  final T model;
  final List<Map<String, dynamic>> rows;
  final List<String> _relations = [];

  Hydrator(this.model, this.rows);

  Hydrator<T> include(List<String> relations) {
    _relations.addAll(relations);
    return this;
  }

  Future<List<T>> get() async {
    var items = model.hydrateMany(rows);
    if (_relations.isNotEmpty) {
      items = await model.loadRelations(items, include: _relations);
    }
    return items;
  }

  Future<T?> first() async {
    if (rows.isEmpty) return null;
    var item = model.hydrateOne(rows.first);
    if (_relations.isNotEmpty) {
      final hydrated = await model.loadRelations([item], include: _relations);
      return hydrated.first;
    }
    return item;
  }
}