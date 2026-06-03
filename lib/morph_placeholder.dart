import 'relational_model.dart';

class MorphPlaceholder extends RelationalModel<MorphPlaceholder> {
  @override
  String get table => '__never_used__'; // no such table

  @override
  MorphPlaceholder fromJson(Map<String, dynamic> json) => MorphPlaceholder();

  @override
  Map<String, dynamic> toJson() => {};
}
