import 'package:jsonld/schema_value.dart';
import 'package:jsonld/schema_service.dart';

class SchemaEntity {
  bool _isEnumerationValue(String value) {
    for (var list in SchemaService.instance.enumerationValues.values) {
      if (list.contains(value)) {
        return true;
      }
    }
    return false;
  }

  SchemaEntity({
    required this.id,
    required this.type,
    required this.properties,
    this.name = 'Untitled Document',
    this.baseUri,
  });

  final String id;

  String type;

  final Map<String, List<SchemaValue>> properties;

  String name;

  String? baseUri;

  static const Map<String, String> _namespaces = {
    'bibo': 'http://purl.org/ontology/bibo/',
    'brick': 'https://brickschema.org/schema/Brick#',
    'cmns-cls': 'https://www.omg.org/spec/Commons/Classifiers/',
    'cmns-col': 'https://www.omg.org/spec/Commons/Collections/',
    'cmns-dt': 'https://www.omg.org/spec/Commons/DatesAndTimes/',
    'cmns-ge': 'https://www.omg.org/spec/Commons/GeopoliticalEntities/',
    'cmns-id': 'https://www.omg.org/spec/Commons/Identifiers/',
    'cmns-loc': 'https://www.omg.org/spec/Commons/Locations/',
    'cmns-q': 'https://www.omg.org/spec/Commons/Quantities/',
    'cmns-txt': 'https://www.omg.org/spec/Commons/Text/',
    'csvw': 'http://www.w3.org/ns/csvw#',
    'dc': 'http://purl.org/dc/elements/1.1/',
    'dcam': 'http://purl.org/dc/dcam/',
    'dcat': 'http://www.w3.org/ns/dcat#',
    'dct': 'http://purl.org/dc/terms/',
    'dctype': 'http://purl.org/dc/dcmitype/',
    'doap': 'http://usefulinc.com/ns/doap#',
    'eli': 'http://data.europa.eu/eli/ontology#',
    'fibo-be-corp-corp': 'https://spec.edmcouncil.org/fibo/ontology/BE/Corporations/Corporations/',
    'fibo-be-ge-ge': 'https://spec.edmcouncil.org/fibo/ontology/BE/GovernmentEntities/GovernmentEntities/',
    'fibo-be-le-cb': 'https://spec.edmcouncil.org/fibo/ontology/BE/LegalEntities/CorporateBodies/',
    'fibo-be-le-lp': 'https://spec.edmcouncil.org/fibo/ontology/BE/LegalEntities/LegalPersons/',
    'fibo-be-nfp-nfp': 'https://spec.edmcouncil.org/fibo/ontology/BE/NotForProfitOrganizations/NotForProfitOrganizations/',
    'fibo-be-oac-cctl': 'https://spec.edmcouncil.org/fibo/ontology/BE/OwnershipAndControl/CorporateControl/',
    'fibo-fbc-dae-dbt': 'https://spec.edmcouncil.org/fibo/ontology/FBC/DebtAndEquities/Debt/',
    'fibo-fbc-pas-fpas': 'https://spec.edmcouncil.org/fibo/ontology/FBC/ProductsAndServices/FinancialProductsAndServices/',
    'fibo-fnd-acc-cur': 'https://spec.edmcouncil.org/fibo/ontology/FND/Accounting/CurrencyAmount/',
    'fibo-fnd-agr-ctr': 'https://spec.edmcouncil.org/fibo/ontology/FND/Agreements/Contracts/',
    'fibo-fnd-arr-doc': 'https://spec.edmcouncil.org/fibo/ontology/FND/Arrangements/Documents/',
    'fibo-fnd-arr-lif': 'https://spec.edmcouncil.org/fibo/ontology/FND/Arrangements/Lifecycles/',
    'fibo-fnd-dt-oc': 'https://spec.edmcouncil.org/fibo/ontology/FND/DatesAndTimes/Occurrences/',
    'fibo-fnd-org-org': 'https://spec.edmcouncil.org/fibo/ontology/FND/Organizations/Organizations/',
    'fibo-fnd-pas-pas': 'https://spec.edmcouncil.org/fibo/ontology/FND/ProductsAndServices/ProductsAndServices/',
    'fibo-fnd-plc-adr': 'https://spec.edmcouncil.org/fibo/ontology/FND/Places/Addresses/',
    'fibo-fnd-plc-fac': 'https://spec.edmcouncil.org/fibo/ontology/FND/Places/Facilities/',
    'fibo-fnd-plc-loc': 'https://spec.edmcouncil.org/fibo/ontology/FND/Places/Locations/',
    'fibo-fnd-pty-pty': 'https://spec.edmcouncil.org/fibo/ontology/FND/Parties/Parties/',
    'fibo-fnd-rel-rel': 'https://spec.edmcouncil.org/fibo/ontology/FND/Relations/Relations/',
    'fibo-pay-ps-ps': 'https://spec.edmcouncil.org/fibo/ontology/PAY/PaymentServices/PaymentServices/',
    'foaf': 'http://xmlns.com/foaf/0.1/',
    'geo': 'http://www.opengis.net/ont/geosparql#',
    'gleif-L1': 'https://www.gleif.org/ontology/L1/',
    'gs1': 'https://ref.gs1.org/voc/',
    'hydra': 'http://www.w3.org/ns/hydra/core#',
    'lcc-3166-1': 'https://www.omg.org/spec/LCC/Countries/ISO3166-1-CountryCodes/',
    'lcc-4217': 'https://www.omg.org/spec/LCC/Countries/ISO4217-CurrencyCodes/',
    'lcc-cr': 'https://www.omg.org/spec/LCC/Countries/CountryRepresentation/',
    'lcc-lr': 'https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/',
    'lrmoo': 'http://iflastandards.info/ns/lrm/lrmoo/',
    'mo': 'http://purl.org/ontology/mo/',
    'odrl': 'http://www.w3.org/ns/odrl/2/',
    'og': 'http://ogp.me/ns#',
    'org': 'http://www.w3.org/ns/org#',
    'owl': 'http://www.w3.org/2002/07/owl#',
    'prof': 'http://www.w3.org/ns/dx/prof/',
    'prov': 'http://www.w3.org/ns/prov#',
    'qb': 'http://purl.org/linked-data/cube#',
    'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
    'sarif': 'http://sarif.info/',
    'schema': 'https://schema.org/',
    'sh': 'http://www.w3.org/ns/shacl#',
    'skos': 'http://www.w3.org/2004/02/skos/core#',
    'snomed': 'http://purl.bioontology.org/ontology/SNOMEDCT/',
    'sosa': 'http://www.w3.org/ns/sosa/',
    'ssn': 'http://www.w3.org/ns/ssn/',
    'time': 'http://www.w3.org/2006/time#',
    'unece': 'http://unece.org/vocab#',
    'vann': 'http://purl.org/vocab/vann/',
    'vcard': 'http://www.w3.org/2006/vcard/ns#',
    'void': 'http://rdfs.org/ns/void#',
    'wgs': 'https://www.w3.org/2003/01/geo/wgs84_pos#',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
  };

  void _collectUsedNamespaces(dynamic val, Set<String> used) {
    if (val is SchemaEntity) {
      for (var values in val.properties.values) {
        for (var sv in values) {
          _collectUsedNamespaces(sv.value, used);
        }
      }
    } else if (val is Map) {
      final t = val['@type']?.toString();
      if (t != null && t.contains(':')) {
        final prefix = t.split(':').first;
        if (_namespaces.containsKey(prefix)) {
          used.add(prefix);
        }
      }
      for (var entry in val.entries) {
        _collectUsedNamespaces(entry.value, used);
      }
    } else if (val is List) {
      for (var item in val) {
        _collectUsedNamespaces(item, used);
      }
    }
  }

  Map<String, dynamic> toJsonLd({bool isRoot = false, Map<String, String>? docIdToName}) {
    final Map<String, dynamic> result = {};
    if (isRoot) {
      final Set<String> usedPrefixes = {};
      _collectUsedNamespaces(this, usedPrefixes);

      final Map<String, String> extraContext = {};
      for (var prefix in usedPrefixes) {
        final nsUrl = _namespaces[prefix];
        if (nsUrl != null) {
          extraContext[prefix] = nsUrl;
        }
      }

      if (baseUri == null || baseUri!.trim().isEmpty) {
        if (extraContext.isNotEmpty) {
          result['@context'] = {
            '@vocab': 'https://schema.org/',
            ...extraContext,
          };
        } else {
          result['@context'] = 'https://schema.org';
        }
      } else {
        result['@context'] = {
          '@vocab': 'https://schema.org/',
          '@base': baseUri!.trim(),
          ...extraContext,
        };
      }
    }
    final String typeName =
        type.startsWith('schema:') ? type.substring(7) : type;
    final bool isReverseMap = typeName == '@reverse';

    if (!isReverseMap) {
      result['@type'] = typeName;
    }

    // Helper to check if a name represents a custom renamed node
    bool isNameRenamed(String nameValue) {
      final clean = nameValue.trim();
      return clean.isNotEmpty &&
          clean != 'Untitled Document' &&
          clean != 'Untitled Object' &&
          clean != 'Schema Document' &&
          !clean.startsWith('New ') &&
           !clean.endsWith(' Reference') &&
           !clean.endsWith(' Markup');
    }

    final String effectiveBase = (baseUri != null && baseUri!.trim().isNotEmpty) ? baseUri!.trim() : 'https://example.com/things/';

    // Dynamic @id generation based on renamed name or preserved absolute URIs
    if (!isReverseMap) {
      if (isNameRenamed(name)) {
        final safeId = name.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '-');
        result['@id'] = '#$safeId';
      } else if (id.startsWith(effectiveBase)) {
        // Form relative ID if it matches the base URL
        result['@id'] = id.substring(effectiveBase.length);
      } else if (id.startsWith('http://') || id.startsWith('https://')) {
        result['@id'] = id;
      }
    }

    properties.forEach((propId, values) {
      if (values.isEmpty) {
        return;
      }
      final propName =
          propId.startsWith('schema:') ? propId.substring(7) : propId;
      final List<dynamic> jsonValues = [];
      for (var val in values) {
        if (val.value is SchemaEntity) {
          jsonValues.add((val.value as SchemaEntity).toJsonLd(isRoot: false, docIdToName: docIdToName));
        } else if (val.value is Map && (val.value as Map).containsKey('@value')) {
          // Rule 1: Preserve Value Objects exactly as imported, do NOT add node metadata!
          jsonValues.add(val.value);
        } else if (val.value is Map && (val.value as Map).containsKey('@id')) {
          final targetDocId = (val.value as Map)['@id'] as String;
          final targetDocName = docIdToName?[targetDocId] ?? (val.value as Map)['docName'] ?? '';
          if (isNameRenamed(targetDocName)) {
            final safeLinkedId = targetDocName.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(RegExp(r'\s+'), '-');
            jsonValues.add({'@id': '#$safeLinkedId'});
          } else {
            // Keep absolute URLs and pre-anchored IDs exactly as-is without adding '#' double prefixes
            if (targetDocId.startsWith(effectiveBase)) {
              jsonValues.add({'@id': targetDocId.substring(effectiveBase.length)});
            } else if (targetDocId.startsWith('http://') || targetDocId.startsWith('https://') || targetDocId.startsWith('#')) {
              jsonValues.add({'@id': targetDocId});
            } else {
              jsonValues.add({'@id': '#$targetDocId'});
            }
          }
        } else if (val.value is String) {
          final String strVal = val.value as String;
          if (strVal.startsWith('schema:') && _isEnumerationValue(strVal)) {
            jsonValues.add('https://schema.org/${strVal.substring(7)}');
          } else {
            jsonValues.add(val.value);
          }
        } else {
          jsonValues.add(val.value);
        }
      }
      if (jsonValues.isNotEmpty) {
        result[propName] =
            jsonValues.length == 1 ? jsonValues.first : jsonValues;
      }
    });
    return result;
  }

  SchemaEntity clone() {
    final Map<String, List<SchemaValue>> clonedProps = {};
    properties.forEach((key, list) {
      clonedProps[key] = list.map((v) {
        final val = v.value;
        return SchemaValue(
          id: v.id,
          value: val is SchemaEntity
              ? val.clone()
              : (val is Map ? Map.from(val) : val),
        );
      }).toList();
    });
    return SchemaEntity(
      id: 'nest_${DateTime.now().microsecondsSinceEpoch}_${id}',
      type: type,
      properties: clonedProps,
      name: name,
      baseUri: baseUri,
    );
  }

  Map<String, dynamic> serializeProperties() {
    final Map<String, dynamic> serialized = {};
    if (baseUri != null) {
      serialized['_baseUri'] = baseUri;
    }
    properties.forEach((propId, values) {
      final List<dynamic> listData = [];
      for (var val in values) {
        if (val.value is SchemaEntity) {
          listData.add({
            'type': 'entity',
            'id': (val.value as SchemaEntity).id,
            'name': (val.value as SchemaEntity).name,
            'schemaType': (val.value as SchemaEntity).type,
            'properties': (val.value as SchemaEntity).serializeProperties(),
          });
        } else if (val.value is Map) {
          listData.add({
            'type': 'map',
            'value': Map<String, dynamic>.from(val.value as Map),
          });
        } else {
          listData.add({
            'type': 'primitive',
            'value': val.value,
          });
        }
      }
      serialized[propId] = listData;
    });
    return serialized;
  }

  static Map<String, List<SchemaValue>> deserializeProperties(
      Map<String, dynamic> data) {
    final Map<String, List<SchemaValue>> parsed = {};
    data.forEach((propId, valList) {
      if (valList is List) {
        final List<SchemaValue> sValues = [];
        for (var item in valList) {
          if (item is Map<String, dynamic>) {
            final type = item['type']?.toString();
            if (type == 'entity') {
              final nested = SchemaEntity(
                id: item['id']?.toString() ??
                    'nest_${DateTime.now().microsecondsSinceEpoch}',
                name: item['name']?.toString() ?? 'Untitled Nested',
                type: item['schemaType']?.toString() ?? 'schema:Thing',
                properties: deserializeProperties(
                    item['properties'] as Map<String, dynamic>? ?? {}),
              );
              sValues.add(SchemaValue(
                id: 'val_${DateTime.now().microsecondsSinceEpoch}_${item.hashCode}',
                value: nested,
              ));
            } else if (type == 'map') {
              sValues.add(SchemaValue(
                id: 'val_${DateTime.now().microsecondsSinceEpoch}_${item.hashCode}',
                value: item['value'],
              ));
            } else {
              sValues.add(SchemaValue(
                id: 'val_${DateTime.now().microsecondsSinceEpoch}_${item.hashCode}',
                value: item['value'],
              ));
            }
          }
        }
        if (sValues.isNotEmpty) {
          parsed[propId] = sValues;
        }
      }
    });
    return parsed;
  }

  static SchemaEntity fromJsonLd(
    Map<String, dynamic> json, {
    String? defaultType,
    String? docName,
  }) {
    final String type =
        json['@type']?.toString() ?? defaultType ?? 'schema:Thing';
    final String normalizedType = type.contains(':') ? type : 'schema:${type}';
    final Map<String, List<SchemaValue>> properties = {};
    json.forEach((key, val) {
      if (key == '@context' || key == '@type') {
        return;
      }
      final String propId = key == '@reverse' ? 'schema:@reverse' : (key.contains(':') ? key : 'schema:${key}');
      final List<SchemaValue> values = [];
      void parseValue(dynamic singleVal) {
        if (singleVal is Map<String, dynamic>) {
          if (singleVal.containsKey('@value')) {
            // Rule 3: Detect Value Objects (contains @value)
            // Preserve the Value Object exactly as imported!
            values.add(
              SchemaValue(
                id: DateTime.now().microsecondsSinceEpoch.toString() +
                    '_' +
                    singleVal.hashCode.toString(),
                value: Map<String, dynamic>.from(singleVal),
              ),
            );
          } else if (singleVal.containsKey('@id')) {
            final refId = singleVal['@id'].toString().replaceAll('#', '');
            values.add(
              SchemaValue(
                id: DateTime.now().microsecondsSinceEpoch.toString() +
                    '_' +
                    singleVal.hashCode.toString(),
                value: {
                  '@id': refId,
                  'docName':
                      '${refId.replaceAll('doc_', 'Document ')} Reference',
                },
              ),
            );
          } else {
            values.add(
              SchemaValue(
                id: DateTime.now().microsecondsSinceEpoch.toString() +
                    '_' +
                    singleVal.hashCode.toString(),
                value: SchemaEntity.fromJsonLd(singleVal, defaultType: key == '@reverse' ? 'schema:@reverse' : null),
              ),
            );
          }
        } else if (singleVal != null) {
          var parsedVal = singleVal;
          if (singleVal is String) {
            final String s = singleVal.trim();
            if (s.startsWith('https://schema.org/') ||
                s.startsWith('http://schema.org/')) {
              final String suffix = s.substring(s.lastIndexOf('/') + 1);
              final String candidate = 'schema:$suffix';
              // Check if we can find this candidate in enumerationValues
              // If empty, fall back to matching by parsing
              bool matched = false;
              for (var list
                  in SchemaService.instance.enumerationValues.values) {
                if (list.contains(candidate)) {
                  matched = true;
                  break;
                }
              }
              if (matched || suffix.isNotEmpty) {
                // If it looks like a capital letter enum value (e.g. InStock, Monday, CreditCard), convert to schema: format
                if (suffix.isNotEmpty && suffix[0] == suffix[0].toUpperCase()) {
                  parsedVal = candidate;
                }
              }
            }
          }
          values.add(
            SchemaValue(
              id: DateTime.now().microsecondsSinceEpoch.toString() +
                  '_' +
                  singleVal.hashCode.toString(),
              value: parsedVal,
            ),
          );
        }
      }

      if (val is List) {
        for (var item in val) {
          parseValue(item);
        }
      } else {
        parseValue(val);
      }
      if (values.isNotEmpty) {
        properties[propId] = values;
      }
    });
    return SchemaEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString() +
          '_' +
          json.hashCode.toString(),
      type: normalizedType,
      properties: properties,
      name: docName ?? '${type.split(':').last} Markup',
    );
  }
}
