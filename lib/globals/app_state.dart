import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jsonld/globals/themes.dart';
import 'package:jsonld/schema_entity.dart';
import 'package:jsonld/schema_service.dart';
import 'package:jsonld/schema_value.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:jsonld/globals/database_instance.dart';
import 'package:jsonld/database/local_document.dart';

class AppState extends ChangeNotifier {
  AppState();

  factory AppState.of(BuildContext context, {bool listen = true}) {
    return Provider.of<AppState>(context, listen: listen);
  }

  ThemeData _theme = lightTheme;

  ThemeData get theme {
    return _theme;
  }

  final List<SchemaEntity> _documents = [];

  int _selectedDocumentIndex = 0;

  bool _isSchemaLoading = false;

  String? _loadError;

  String _jsonLdOutput = '';

  String _selectedLdVersion = '1.1';

  String get selectedLdVersion => _selectedLdVersion;

  void generateJsonLdOutputWithVersion(String version) {
    _selectedLdVersion = version;
    generateJsonLdOutput();
    notifyListeners();
  }

  Timer? _debounceTimer;
  String _saveStatus = 'Saved';

  String get saveStatus => _saveStatus;

  List<SchemaEntity> get documents {
    return _documents;
  }

  int get selectedDocumentIndex {
    return _selectedDocumentIndex;
  }

  SchemaEntity? get rootEntity {
    return _documents.isNotEmpty ? _documents[_selectedDocumentIndex] : null;
  }

  bool get isSchemaLoading {
    return _isSchemaLoading;
  }

  String? get loadError {
    return _loadError;
  }

  String get jsonLdOutput {
    return _jsonLdOutput;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void changeTheme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  UuidValue _parseOrConvertUuid(String id) {
    try {
      return UuidValue.fromString(id);
    } catch (_) {
      return UuidValue.fromString(Uuid().v5(Namespace.url.value, 'jsonld:$id'));
    }
  }

  Future<void> initSchemaService() async {
    _isSchemaLoading = true;
    notifyListeners();
    await SchemaService.instance.init();
    _isSchemaLoading = SchemaService.instance.isLoadingFullSchema;
    _loadError = SchemaService.instance.loadError;

    // Load from Serverpod Offline Sync database
    try {
      await syncDb.init();
      final savedDocs = await syncDb.getDocuments();
      if (savedDocs.isNotEmpty) {
        _documents.clear();
        for (var d in savedDocs) {
          try {
            final rawProps =
                json.decode(d.propertiesJson) as Map<String, dynamic>;
            final props = SchemaEntity.deserializeProperties(rawProps);
            _documents.add(SchemaEntity(
              id: d.id.uuid,
              name: d.name,
              type: d.type,
              properties: props,
              baseUri: rawProps['_baseUri']?.toString(),
              customContext: rawProps['_customContext'] != null
                  ? Map<String, dynamic>.from(rawProps['_customContext'] as Map)
                  : null,
              ldVersion: rawProps['_ldVersion'] != null
                  ? double.tryParse(rawProps['_ldVersion'].toString())
                  : null,
            ));
          } catch (rowErr) {
            debugPrint('Error parsing row ID ${d.id}: $rowErr');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading documents from SyncDatabase: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final bool hasInitializedDb = prefs.getBool('has_initialized_db') ?? false;

    if (_documents.isEmpty && !hasInitializedDb) {
      final doc1 = SchemaEntity(
        id: Uuid().v7(),
        name: 'My Personal Profile',
        type: 'schema:Person',
        properties: {
          'schema:name': [SchemaValue(id: 'val_1', value: 'John Doe')],
          'schema:jobTitle': [
            SchemaValue(id: 'val_2', value: 'Software Engineer'),
          ],
        },
      );
      final doc2 = SchemaEntity(
        id: Uuid().v7(),
        name: 'Company Website',
        type: 'schema:WebSite',
        properties: {
          'schema:name': [
            SchemaValue(id: 'val_3', value: 'Acme Corp Portal'),
          ],
          'schema:url': [
            SchemaValue(id: 'val_4', value: 'https://acme.example.com'),
          ],
        },
      );
      _documents.add(doc1);
      _documents.add(doc2);
      await persistDocument(doc1, immediate: true);
      await persistDocument(doc2, immediate: true);
      await prefs.setBool('has_initialized_db', true);
    }
    generateJsonLdOutput();
    notifyListeners();
  }

  Future<void> persistDocument(SchemaEntity entity,
      {bool immediate = false}) async {
    _saveStatus = 'Saving...';
    notifyListeners();
    _debounceTimer?.cancel();

    Future<void> performSave() async {
      try {
        final serialized = json.encode(entity.serializeProperties());
        final docUuid = _parseOrConvertUuid(entity.id);
        await syncDb.saveDocument(
          LocalDocument(
            id: docUuid,
            name: entity.name,
            type: entity.type,
            propertiesJson: serialized,
            updatedAt: DateTime.now(),
          ),
        );
        _saveStatus = 'Saved';
        notifyListeners();
      } catch (e) {
        debugPrint('Error persisting document to SyncDatabase: $e');
        _saveStatus = 'Error saving';
        notifyListeners();
      }
    }

    if (immediate) {
      await performSave();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        await performSave();
      });
    }
  }

  void selectDocument(int index) {
    if (index >= 0 && index < _documents.length) {
      _selectedDocumentIndex = index;
      generateJsonLdOutput();
      notifyListeners();
    }
  }

  void setRootEntity(SchemaEntity entity) {
    if (_documents.isNotEmpty) {
      _documents[_selectedDocumentIndex] = entity;
    } else {
      _documents.add(entity);
      _selectedDocumentIndex = 0;
    }
    persistDocument(entity);
    generateJsonLdOutput();
    notifyListeners();
  }

  void createNewDocument(String name, String typeId) {
    final doc = SchemaEntity(
      id: Uuid().v7(),
      name: name.isEmpty ? '${typeId.split(':').last} Markup' : name,
      type: typeId,
      properties: {},
    );
    _documents.add(doc);
    _selectedDocumentIndex = _documents.length - 1;
    persistDocument(doc);
    generateJsonLdOutput();
    notifyListeners();
  }

  void duplicateDocument(int index) {
    if (index >= 0 && index < _documents.length) {
      final original = _documents[index];
      final doc = SchemaEntity(
        id: Uuid().v7(),
        name: '${original.name} Copy',
        type: original.type,
        properties: original.clone().properties,
        baseUri: original.baseUri,
        customContext: original.customContext != null
            ? Map<String, dynamic>.from(original.customContext!)
            : null,
        ldVersion: original.ldVersion,
      );
      _documents.add(doc);
      _selectedDocumentIndex = _documents.length - 1;
      persistDocument(doc);
      generateJsonLdOutput();
      notifyListeners();
    }
  }

  void renameDocument(int index, String newName) {
    if (index >= 0 && index < _documents.length) {
      final doc = _documents[index];
      doc.name = newName;
      persistDocument(doc);
      generateJsonLdOutput();
      notifyListeners();
    }
  }

  void deleteDocument(int index) async {
    if (_documents.length > 1 && index >= 0 && index < _documents.length) {
      final doc = _documents[index];
      _documents.removeAt(index);
      try {
        final docUuid = _parseOrConvertUuid(doc.id);
        await syncDb.deleteDocument(docUuid);
      } catch (e) {
        debugPrint('Error deleting document from SyncDatabase: $e');
      }
      if (_selectedDocumentIndex >= _documents.length) {
        _selectedDocumentIndex = _documents.length - 1;
      }
      generateJsonLdOutput();
      notifyListeners();
    } else if (_documents.length == 1) {
      final oldDoc = _documents[0];
      try {
        final docUuid = _parseOrConvertUuid(oldDoc.id);
        await syncDb.deleteDocument(docUuid);
      } catch (e) {
        debugPrint('Error deleting document from SyncDatabase: $e');
      }
      final newDoc = SchemaEntity(
        id: Uuid().v7(),
        name: 'Untitled Document',
        type: 'schema:Person',
        properties: {},
      );
      _documents[0] = newDoc;
      _selectedDocumentIndex = 0;
      persistDocument(newDoc);
      generateJsonLdOutput();
      notifyListeners();
    }
  }

  void updateRootType(String type) {
    final root = rootEntity;
    if (root != null) {
      root.type = type;
      root.properties.clear();
      persistDocument(root);
      generateJsonLdOutput();
      notifyListeners();
    }
  }

  void updatePropertyValue(
    SchemaEntity entity,
    String propertyId,
    String valueId,
    dynamic newValue,
  ) {
    final list = entity.properties[propertyId];
    if (list != null) {
      final index = list.indexWhere((val) => val.id == valueId);
      if (index != -1) {
        list[index].value = newValue;
        final root = rootEntity;
        if (root != null) {
          persistDocument(root);
        }
        generateJsonLdOutput();
        notifyListeners();
      }
    }
  }

  void removePropertyValue(
    SchemaEntity entity,
    String propertyId,
    String valueId,
  ) {
    final list = entity.properties[propertyId];
    if (list != null) {
      list.removeWhere((val) => val.id == valueId);
      if (list.isEmpty) {
        entity.properties.remove(propertyId);
      }
      final root = rootEntity;
      if (root != null) {
        persistDocument(root);
      }
      generateJsonLdOutput();
      notifyListeners();
    }
  }

  void removePropertyFromEntity(SchemaEntity entity, String propertyId) {
    entity.properties.remove(propertyId);
    final root = rootEntity;
    if (root != null) {
      persistDocument(root);
    }
    generateJsonLdOutput();
    notifyListeners();
  }

  void generateJsonLdOutput() {
    final root = rootEntity;
    if (root == null) {
      _jsonLdOutput = '{}';
    } else {
      try {
        final Map<String, String> idToName = {};
        for (final doc in _documents) {
          idToName[doc.id] = doc.name;
        }
        final map = root.toJsonLd(
          isRoot: true,
          docIdToName: idToName,
          targetVersion: _selectedLdVersion,
        );
        if (_selectedLdVersion == 'yaml-ld') {
          _jsonLdOutput = root.convertToYaml(map);
        } else {
          final encoder = const JsonEncoder.withIndent('  ');
          _jsonLdOutput = encoder.convert(map);
        }
      } catch (e) {
        _jsonLdOutput = 'Error generating JSON-LD: ${e}';
      }
    }
  }

  bool importJsonLd(String jsonString) {
    try {
      final dynamic decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        final imported = SchemaEntity.fromJsonLd(decoded);
        _documents.add(imported);
        _selectedDocumentIndex = _documents.length - 1;
        persistDocument(imported, immediate: true);
        generateJsonLdOutput();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error importing JSON-LD: ${e}');
      return false;
    }
  }

  void addPropertyToEntity(
    SchemaEntity entity,
    String propertyId,
    dynamic initialValue,
  ) {
    if (entity.properties[propertyId] == null) {
      entity.properties[propertyId] = [];
    }
    final dynamic valueToAdd =
        (initialValue is SchemaEntity) ? initialValue.clone() : initialValue;
    entity.properties[propertyId]?.add(
      SchemaValue(
        id: 'val_${DateTime.now().microsecondsSinceEpoch}',
        value: valueToAdd,
      ),
    );
    final root = rootEntity;
    if (root != null) {
      persistDocument(root);
    }
    generateJsonLdOutput();
    notifyListeners();
  }
}
