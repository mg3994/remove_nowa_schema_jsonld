import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

class LocalDocumentTable extends Table<UuidValue> {
  LocalDocumentTable({super.tableRelation})
      : super(tableName: 'local_document') {
    name = ColumnString('name', this);
    type = ColumnString('type', this);
    propertiesJson = ColumnString('propertiesJson', this);
    updatedAt = ColumnDateTime('updatedAt', this);
    spaceId = ColumnInt('spaceId', this, hasDefault: true);
  }

  late final ColumnString name;
  late final ColumnString type;
  late final ColumnString propertiesJson;
  late final ColumnDateTime updatedAt;
  late final ColumnInt spaceId;

  @override
  List<Column> get columns => [
        id,
        name,
        type,
        propertiesJson,
        updatedAt,
        spaceId,
      ];
}

class LocalDocument implements TableRow<UuidValue> {
  LocalDocument({
    UuidValue? id,
    required this.name,
    required this.type,
    required this.propertiesJson,
    required this.updatedAt,
    this.spaceId,
  }) : id = id ?? Uuid().v7obj();

  @override
  final UuidValue id;
  String name;
  String type;
  String propertiesJson;
  DateTime updatedAt;
  int? spaceId;

  static final t = LocalDocumentTable();

  @override
  Table<UuidValue> get table => t;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id.uuid,
      'name': name,
      'type': type,
      'propertiesJson': propertiesJson,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      if (spaceId != null) 'spaceId': spaceId,
    };
  }

  static LocalDocument fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['updatedAt'] is DateTime) {
      parsedDate = json['updatedAt'] as DateTime;
    } else if (json['updatedAt'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int,
        isUtc: true,
      );
    } else {
      final str = json['updatedAt']?.toString() ?? '';
      final ms = int.tryParse(str);
      if (ms != null) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      } else {
        parsedDate = DateTime.tryParse(str) ?? DateTime.now();
      }
    }

    return LocalDocument(
      id: json['id'] != null
          ? UuidValue.fromString(json['id'].toString())
          : Uuid().v7obj(),
      name: json['name'] as String,
      type: json['type'] as String,
      propertiesJson: json['propertiesJson'] as String,
      updatedAt: parsedDate,
      spaceId: json['spaceId'] != null
          ? int.tryParse(json['spaceId'].toString())
          : null,
    );
  }

  LocalDocument copyWith({
    UuidValue? id,
    String? name,
    String? type,
    String? propertiesJson,
    DateTime? updatedAt,
    int? spaceId,
  }) {
    return LocalDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      propertiesJson: propertiesJson ?? this.propertiesJson,
      updatedAt: updatedAt ?? this.updatedAt,
      spaceId: spaceId ?? this.spaceId,
    );
  }
}
