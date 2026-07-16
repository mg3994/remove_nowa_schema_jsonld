import 'package:flutter/material.dart';
import 'package:jsonld/globals/themes.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:jsonld/schema_entity.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jsonld/schema_service.dart';
import 'package:jsonld/schema_value.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:jsonld/globals/database_instance.dart';
import 'package:jsonld/database/database.dart';

@NowaGenerated()
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

  InterstitialAd? _interstitialAd;

  bool _isInterstitialAdLoading = false;

  void changeTheme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  Future<void> initSchemaService() async {
    _isSchemaLoading = true;
    notifyListeners();
    await SchemaService.instance.init();
    _isSchemaLoading = SchemaService.instance.isLoadingFullSchema;
    _loadError = SchemaService.instance.loadError;

    // Load from Drift database
    try {
      final savedDocs = await db.select(db.localDocuments).get();
      if (savedDocs.isNotEmpty) {
        _documents.clear();
        for (var d in savedDocs) {
          final props = SchemaEntity.deserializeProperties(
            json.decode(d.propertiesJson) as Map<String, dynamic>,
          );
          _documents.add(SchemaEntity(
            id: d.id,
            name: d.name,
            type: d.type,
            properties: props,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error loading documents from Drift: $e');
    }

    if (_documents.isEmpty) {
      final doc1 = SchemaEntity(
        id: 'doc_1',
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
        id: 'doc_2',
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
    }
    generateJsonLdOutput();
    loadInterstitialAd();
    notifyListeners();
  }

  Future<void> persistDocument(SchemaEntity entity, {bool immediate = false}) async {
    _saveStatus = 'Saving...';
    notifyListeners();
    _debounceTimer?.cancel();

    Future<void> performSave() async {
      try {
        final serialized = json.encode(entity.serializeProperties());
        await db.into(db.localDocuments).insertOnConflictUpdate(
          LocalDocument(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            propertiesJson: serialized,
            updatedAt: DateTime.now(),
          ),
        );
        _saveStatus = 'Saved';
        notifyListeners();
      } catch (e) {
        debugPrint('Error persisting document to Drift: $e');
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
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? '${typeId.split(':').last} Markup' : name,
      type: typeId,
      properties: {},
    );
    _documents.add(doc);
    _selectedDocumentIndex = _documents.length - 1;
    persistDocument(doc);
    generateJsonLdOutput();
    showInterstitialAd();
    notifyListeners();
  }

  void duplicateDocument(int index) {
    if (index >= 0 && index < _documents.length) {
      final doc = _documents[index].clone();
      _documents.add(doc);
      _selectedDocumentIndex = _documents.length - 1;
      persistDocument(doc);
      generateJsonLdOutput();
      showInterstitialAd();
      notifyListeners();
    }
  }

  void renameDocument(int index, String newName) {
    if (index >= 0 && index < _documents.length) {
      final doc = _documents[index];
      doc.name = newName;
      persistDocument(doc);
      notifyListeners();
    }
  }

  void deleteDocument(int index) async {
    if (_documents.length > 1 && index >= 0 && index < _documents.length) {
      final doc = _documents[index];
      _documents.removeAt(index);
      try {
        final stmt = db.delete(db.localDocuments);
        stmt.where((tbl) => tbl.id.equals(doc.id));
        await stmt.go();
      } catch (e) {
        debugPrint('Error deleting document from Drift: $e');
      }
      if (_selectedDocumentIndex >= _documents.length) {
        _selectedDocumentIndex = _documents.length - 1;
      }
      generateJsonLdOutput();
      notifyListeners();
    } else if (_documents.length == 1) {
      final oldDoc = _documents[0];
      try {
        final stmt = db.delete(db.localDocuments);
        stmt.where((tbl) => tbl.id.equals(oldDoc.id));
        await stmt.go();
      } catch (e) {
        debugPrint('Error deleting document from Drift: $e');
      }
      final newDoc = SchemaEntity(
        id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
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
        final map = root.toJsonLd(isRoot: true);
        final encoder = const JsonEncoder.withIndent('  ');
        _jsonLdOutput = encoder.convert(map);
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
        showInterstitialAd();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error importing JSON-LD: ${e}');
      return false;
    }
  }

  void loadInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialAdLoading) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _isInterstitialAdLoading = true;
    String adUnitId = '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      adUnitId = 'ca-app-pub-3940256099942544/1033173712';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      adUnitId = 'ca-app-pub-3940256099942544/4411468910';
    }
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          debugPrint('InterstitialAd loaded.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
          debugPrint('InterstitialAd failed to load: ${error}');
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final ad = _interstitialAd;
    if (ad != null) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd();
        },
      );
      ad.show();
    } else {
      loadInterstitialAd();
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
    final dynamic valueToAdd = (initialValue is SchemaEntity)
        ? initialValue.clone()
        : initialValue;
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
