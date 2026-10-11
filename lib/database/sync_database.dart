import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'local_document.dart';

class AppProtocol extends DatabaseSerializationManager
    implements DatabaseProtocolDeserializationProvider {
  AppProtocol._();
  static final AppProtocol instance = AppProtocol._();

  final Protocol _syncProtocol = Protocol();

  @override
  String getModuleName() => 'jsonld';

  @override
  ProtocolDeserialization get deserializationMetadata =>
      ProtocolDeserialization.cached(
        this,
        types: [
          () => getType<LocalDocument>(),
          () => getType<LocalDocument?>(),
        ],
        modules: const [],
      );

  @override
  Table? getTableForType(Type t) {
    if (t == LocalDocument) {
      return LocalDocument.t;
    }
    return _syncProtocol.getTableForType(t);
  }

  @override
  List<TableDefinition> getTargetTableDefinitions() {
    return [
      TableDefinition(
        name: 'local_document',
        dartName: 'LocalDocument',
        schema: 'public',
        module: 'jsonld',
        columns: [
          ColumnDefinition(
            name: 'id',
            columnType: ColumnType.uuid,
            isNullable: false,
            dartType: 'UuidValue',
            columnDefault: 'random_v7',
          ),
          ColumnDefinition(
            name: 'name',
            columnType: ColumnType.text,
            isNullable: false,
            dartType: 'String',
          ),
          ColumnDefinition(
            name: 'type',
            columnType: ColumnType.text,
            isNullable: false,
            dartType: 'String',
          ),
          ColumnDefinition(
            name: 'propertiesJson',
            columnType: ColumnType.text,
            isNullable: false,
            dartType: 'String',
          ),
          ColumnDefinition(
            name: 'updatedAt',
            columnType: ColumnType.bigint,
            isNullable: false,
            dartType: 'DateTime',
          ),
          ColumnDefinition(
            name: 'spaceId',
            columnType: ColumnType.bigint,
            isNullable: true,
            dartType: 'int?',
          ),
        ],
        foreignKeys: [
          ForeignKeyDefinition(
            constraintName: 'local_document_fk_0',
            columns: ['spaceId'],
            referenceTable: 'offline_sync_spaces',
            referenceTableSchema: 'public',
            referenceColumns: ['id'],
            onUpdate: ForeignKeyAction.noAction,
            onDelete: ForeignKeyAction.cascade,
            matchType: null,
          ),
        ],
        indexes: [],
        managed: true,
      ),
      ...Protocol.targetTableDefinitions,
    ];
  }

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    if (t == DateTime || t == getType<DateTime?>()) {
      if (data is String) {
        final ms = int.tryParse(data);
        if (ms != null) {
          return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) as T;
        }
      }
    }
    if (t == LocalDocument) {
      return LocalDocument.fromJson(data as Map<String, dynamic>) as T;
    }
    return _syncProtocol.deserialize<T>(data, t);
  }
}

class SyncDatabase {
  SyncDatabase._();
  static final SyncDatabase instance = SyncDatabase._();

  OfflineSyncDatabaseSession? _syncSession;
  UuidValue? _persistentUserId;

  OfflineSyncDatabaseSession get session {
    if (_syncSession == null) {
      throw StateError(
          'SyncDatabase has not been initialized. Call init() first.');
    }
    return _syncSession!;
  }

  UuidValue? get persistentUserId => _persistentUserId;

  Future<void> init() async {
    if (_syncSession != null) return;

    final prefs = await SharedPreferences.getInstance();
    String? userIdStr = prefs.getString('persistent_user_id');
    if (userIdStr == null) {
      userIdStr = Uuid().v7();
      await prefs.setString('persistent_user_id', userIdStr);
    }
    _persistentUserId = UuidValue.fromString(userIdStr);

    String dbPath = 'jsonld_database.db';
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        dbPath = p.join(dir.path, 'jsonld_database.db');
      } catch (e) {
        dbPath = p.join(Directory.systemTemp.path, 'jsonld_database.db');
      }
    }

    var retry = true;
    while (true) {
      try {
        final clientSession = await ClientDatabaseSession.open(
          dbPath,
          AppProtocol.instance,
          clientMigrations: [
            MigrationVersionSql(
              moduleName: 'jsonld',
              version: '20260101000000',
              definitionSql: _initialSqlSchema,
              migrationSql: _initialSqlSchema,
            ),
          ],
          runMigrations: true,
          isDebugMode: false,
        );

        _syncSession = OfflineSyncDatabaseSession.wraps(
          clientSession,
          syncTables: [LocalDocument.t],
          persistentUserId: _persistentUserId,
        );

        await _syncSession!.db.initialize();
        break;
      } catch (e) {
        if (!retry || kIsWeb) rethrow;
        retry = false;
        for (final suffix in const ['', '-wal', '-shm']) {
          final file = File('$dbPath$suffix');
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
        debugPrint('SyncDatabase: discarded stale database file and retrying.');
      }
    }
  }

  Future<void> resetSpace() async {
    if (_syncSession == null || _persistentUserId == null) return;
    final space = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(_persistentUserId!),
    );
    final spaceId = space?.id;
    if (spaceId != null) {
      await session.db.transaction((transaction) async {
        await session.db.unsafeExecute(
          'PRAGMA defer_foreign_keys = ON',
          transaction: transaction,
        );
        await OfflineSyncSpace.db.deleteWhere(
          session,
          where: (t) => t.id.equals(spaceId),
          transaction: transaction,
        );
      });
    }
    await session.db.initialize();
  }

  static const String _initialSqlSchema = '''
CREATE TABLE IF NOT EXISTS "serverpod_sqlite_schema" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "module" TEXT NOT NULL,
  "version" TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS "serverpod_migrations" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "module" TEXT NOT NULL,
  "version" TEXT NOT NULL,
  "timestamp" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "local_document" (
  "id" TEXT PRIMARY KEY,
  "name" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "propertiesJson" TEXT NOT NULL,
  "updatedAt" INTEGER NOT NULL,
  "spaceId" INTEGER,
  FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "crdt_nodes" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "uuidNodeId" TEXT NOT NULL UNIQUE,
  "lastHlc" TEXT
);

CREATE TABLE IF NOT EXISTS "offline_sync_spaces" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "uuidSpaceId" TEXT NOT NULL UNIQUE,
  "currentNodeId" INTEGER
);

CREATE TABLE IF NOT EXISTS "crdt_schema_tables" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS "crdt_schema_columns" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "tblId" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "columnType" TEXT NOT NULL,
  "dartType" TEXT NOT NULL,
  "isNullable" INTEGER NOT NULL,
  UNIQUE("tblId", "name")
);

CREATE TABLE IF NOT EXISTS "crdt_data_rows" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "hlcDatetime" INTEGER NOT NULL,
  "hlcCounter" INTEGER NOT NULL,
  "spaceId" INTEGER NOT NULL,
  "tblId" INTEGER NOT NULL,
  "uuidRowId" TEXT NOT NULL,
  "nodeId" INTEGER NOT NULL,
  "visibility" INTEGER NOT NULL DEFAULT 0,
  UNIQUE("spaceId", "tblId", "uuidRowId")
);

CREATE TABLE IF NOT EXISTS "crdt_data_fields" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "hlcDatetime" INTEGER NOT NULL,
  "hlcCounter" INTEGER NOT NULL,
  "rowId" INTEGER NOT NULL,
  "columnId" INTEGER NOT NULL,
  "nodeId" INTEGER NOT NULL,
  UNIQUE("rowId", "columnId")
);

CREATE TABLE IF NOT EXISTS "crdt_data_tombstone" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "hlcDatetime" INTEGER NOT NULL,
  "hlcCounter" INTEGER NOT NULL,
  "rowId" INTEGER NOT NULL UNIQUE,
  "nodeId" INTEGER NOT NULL,
  "clFlag" INTEGER NOT NULL,
  "reason" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "crdt_data_attempted_value" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "fieldId" INTEGER NOT NULL UNIQUE,
  "value" TEXT NOT NULL,
  "projectionReason" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "offline_sync_space_members" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "spaceId" INTEGER NOT NULL,
  "userUuid" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  UNIQUE("userUuid", "spaceId")
);

CREATE TABLE IF NOT EXISTS "offline_sync_space_nodes" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "spaceId" INTEGER NOT NULL,
  "nodeId" INTEGER NOT NULL,
  "lastReceivedHlc" TEXT,
  UNIQUE("spaceId", "nodeId")
);

CREATE TABLE IF NOT EXISTS "offline_sync_integrity_violations" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "type" TEXT NOT NULL,
  "domainTableName" TEXT NOT NULL,
  "uuidRowId" TEXT NOT NULL,
  "ownerSpaceUuid" TEXT,
  "incomingSpaceUuid" TEXT NOT NULL,
  "operation" TEXT NOT NULL,
  "uuidNodeId" TEXT,
  "crdtDataRowId" INTEGER,
  "hlcDatetime" INTEGER,
  "hlcCounter" INTEGER,
  "firstSeenAt" INTEGER NOT NULL,
  "lastSeenAt" INTEGER NOT NULL,
  "occurrences" INTEGER NOT NULL,
  UNIQUE("type", "operation", "domainTableName", "uuidRowId", "ownerSpaceUuid", "incomingSpaceUuid")
);
''';

  Future<List<LocalDocument>> getDocuments() async {
    return await session.db.find<LocalDocument>();
  }

  Future<LocalDocument?> getDocumentById(UuidValue id) async {
    return await session.db.findById<LocalDocument>(id);
  }

  Future<void> saveDocument(LocalDocument doc) async {
    await session.db.upsertRow<LocalDocument>(
      doc,
      conflictColumns: [LocalDocument.t.id],
    );
  }

  Future<void> deleteDocument(UuidValue id) async {
    await session.db.deleteWhere<LocalDocument>(
      where: LocalDocument.t.id.equals(id),
    );
  }
}
