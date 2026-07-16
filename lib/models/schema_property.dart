import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class SchemaProperty {
  const SchemaProperty({
    required this.id,
    required this.label,
    required this.comment,
    required this.domains,
    required this.ranges,
    this.defaultValue,
    this.isRequired = false,
  });

  factory SchemaProperty.fromJson(Map<String, dynamic> json) {
    return SchemaProperty(
      id: json['id'] as String,
      label: json['label'] as String,
      comment: json['comment'] as String,
      domains: List<String>.from(json['domains'] as List),
      ranges: List<String>.from(json['ranges'] as List),
      defaultValue: json['defaultValue'] as String?,
      isRequired: json['isRequired'] as bool? ?? false,
    );
  }

  final String id;

  final String label;

  final String comment;

  final List<String> domains;

  final List<String> ranges;

  final String? defaultValue;

  final bool isRequired;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'comment': comment,
      'domains': domains,
      'ranges': ranges,
      'defaultValue': defaultValue,
      'isRequired': isRequired,
    };
  }
}
