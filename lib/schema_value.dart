class SchemaValue {
  SchemaValue({required this.id, this.value});

  final String id;

  dynamic value;

  SchemaValue copyWith({String? id, dynamic value}) {
    return SchemaValue(id: id ?? this.id, value: value ?? this.value);
  }
}
