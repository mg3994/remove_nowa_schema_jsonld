import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class SchemaClass {
  const SchemaClass({
    required this.id,
    required this.label,
    required this.comment,
    required this.subClassOf,
  });

  factory SchemaClass.fromJson(Map<String, dynamic> json) {
    return SchemaClass(
      id: json['id'] as String,
      label: json['label'] as String,
      comment: json['comment'] as String,
      subClassOf: List<String>.from(json['subClassOf'] as List),
    );
  }

  final String id;

  final String label;

  final String comment;

  final List<String> subClassOf;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'comment': comment,
      'subClassOf': subClassOf,
    };
  }
}
