import 'package:dio/dio.dart';
import 'package:jsonld/models/schema_class.dart';
import 'package:jsonld/models/schema_property.dart';
import 'package:flutter/material.dart';
import 'package:jsonld/main.dart';
import 'dart:convert';

class SchemaService {
  SchemaService._internal();

  final Dio _dio = Dio();

  bool isLoadingFullSchema = false;

  bool isFullSchemaLoaded = false;

  String? loadError;

  Map<String, SchemaClass> _classes = {};

  Map<String, SchemaProperty> _properties = {};

  Map<String, List<String>> _enumerationValues = {};

  Map<String, SchemaClass> get classes {
    return _classes.isEmpty ? _popularClasses : _classes;
  }

  Map<String, SchemaProperty> get properties {
    return _properties.isEmpty ? _popularProperties : _properties;
  }

  Map<String, List<String>> get enumerationValues {
    return _enumerationValues;
  }

  static final SchemaService instance = SchemaService._internal();

  static const Map<String, SchemaClass> _popularClasses = {
    'schema:Thing': const SchemaClass(
      id: 'schema:Thing',
      label: 'Thing',
      comment: 'The most generic type of item.',
      subClassOf: const [],
    ),
    'schema:Person': const SchemaClass(
      id: 'schema:Person',
      label: 'Person',
      comment: 'A person (alive, dead, undead, or fictional).',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:Organization': const SchemaClass(
      id: 'schema:Organization',
      label: 'Organization',
      comment: 'An organization such as a school, NGO, corporation, club, etc.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:LocalBusiness': const SchemaClass(
      id: 'schema:LocalBusiness',
      label: 'LocalBusiness',
      comment: 'A particular physical business or branch of an organization.',
      subClassOf: const ['schema:Organization', 'schema:Place'],
    ),
    'schema:FoodEstablishment': const SchemaClass(
      id: 'schema:FoodEstablishment',
      label: 'FoodEstablishment',
      comment: 'A food-related business.',
      subClassOf: const ['schema:LocalBusiness'],
    ),
    'schema:Restaurant': const SchemaClass(
      id: 'schema:Restaurant',
      label: 'Restaurant',
      comment: 'A restaurant.',
      subClassOf: const ['schema:FoodEstablishment'],
    ),
    'schema:FinancialService': const SchemaClass(
      id: 'schema:FinancialService',
      label: 'FinancialService',
      comment: 'Financial services business.',
      subClassOf: const ['schema:LocalBusiness'],
    ),
    'schema:BankOrCreditUnion': const SchemaClass(
      id: 'schema:BankOrCreditUnion',
      label: 'BankOrCreditUnion',
      comment: 'A bank or credit union.',
      subClassOf: const ['schema:FinancialService'],
    ),
    'schema:Store': const SchemaClass(
      id: 'schema:Store',
      label: 'Store',
      comment: 'A retail store.',
      subClassOf: const ['schema:LocalBusiness'],
    ),
    'schema:Product': const SchemaClass(
      id: 'schema:Product',
      label: 'Product',
      comment: 'Any offered product or service.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:Event': const SchemaClass(
      id: 'schema:Event',
      label: 'Event',
      comment: 'An event happening at a certain time and location.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:BusinessEvent': const SchemaClass(
      id: 'schema:BusinessEvent',
      label: 'BusinessEvent',
      comment: 'An event of interest to businesses.',
      subClassOf: const ['schema:Event'],
    ),
    'schema:Festival': const SchemaClass(
      id: 'schema:Festival',
      label: 'Festival',
      comment: 'An event representing a festival.',
      subClassOf: const ['schema:Event'],
    ),
    'schema:Place': const SchemaClass(
      id: 'schema:Place',
      label: 'Place',
      comment: 'Entities that have a somewhat fixed, physical extension.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:PostalAddress': const SchemaClass(
      id: 'schema:PostalAddress',
      label: 'PostalAddress',
      comment: 'The mailing address.',
      subClassOf: const ['schema:Place'],
    ),
    'schema:Offer': const SchemaClass(
      id: 'schema:Offer',
      label: 'Offer',
      comment:
          'An offer to transfer some rights to an item or to provide a service.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:GeoShape': const SchemaClass(
      id: 'schema:GeoShape',
      label: 'GeoShape',
      comment: 'The geographic shape of a place.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:GeoCircle': const SchemaClass(
      id: 'schema:GeoCircle',
      label: 'GeoCircle',
      comment: 'A geographic circle of a place.',
      subClassOf: const ['schema:GeoShape'],
    ),
    'schema:AdministrativeArea': const SchemaClass(
      id: 'schema:AdministrativeArea',
      label: 'AdministrativeArea',
      comment:
          'A geographical region, typically under the jurisdiction of a particular government.',
      subClassOf: const ['schema:Place'],
    ),
    'schema:City': const SchemaClass(
      id: 'schema:City',
      label: 'City',
      comment: 'A city or town.',
      subClassOf: const ['schema:AdministrativeArea'],
    ),
    'schema:State': const SchemaClass(
      id: 'schema:State',
      label: 'State',
      comment: 'A state or province.',
      subClassOf: const ['schema:AdministrativeArea'],
    ),
    'schema:Country': const SchemaClass(
      id: 'schema:Country',
      label: 'Country',
      comment: 'A country.',
      subClassOf: const ['schema:AdministrativeArea'],
    ),
    'schema:GeoCoordinates': const SchemaClass(
      id: 'schema:GeoCoordinates',
      label: 'GeoCoordinates',
      comment: 'The geographic coordinates of a place or event.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:Service': const SchemaClass(
      id: 'schema:Service',
      label: 'Service',
      comment: 'A service provided by an organization or business person.',
      subClassOf: const ['schema:Thing'],
    ),
    'schema:GovernmentService': const SchemaClass(
      id: 'schema:GovernmentService',
      label: 'GovernmentService',
      comment: 'A service provided by a government.',
      subClassOf: const ['schema:Service'],
    ),
  };

  static const Map<String, SchemaProperty> _popularProperties = {
    'schema:name': const SchemaProperty(
      id: 'schema:name',
      label: 'name',
      comment: 'The name of the item.',
      domains: const ['schema:Thing'],
      ranges: const ['schema:Text'],
    ),
    'schema:description': const SchemaProperty(
      id: 'schema:description',
      label: 'description',
      comment: 'A description of the item.',
      domains: const ['schema:Thing'],
      ranges: const ['schema:Text'],
    ),
    'schema:url': const SchemaProperty(
      id: 'schema:url',
      label: 'url',
      comment: 'URL of the item.',
      domains: const ['schema:Thing'],
      ranges: const ['schema:URL'],
    ),
    'schema:image': const SchemaProperty(
      id: 'schema:image',
      label: 'image',
      comment: 'An image of the item.',
      domains: const ['schema:Thing'],
      ranges: const ['schema:URL', 'schema:ImageObject'],
    ),
    'schema:email': const SchemaProperty(
      id: 'schema:email',
      label: 'email',
      comment: 'Email address.',
      domains: const ['schema:Person', 'schema:Organization'],
      ranges: const ['schema:Text'],
    ),
    'schema:telephone': const SchemaProperty(
      id: 'schema:telephone',
      label: 'telephone',
      comment: 'The telephone number.',
      domains: const ['schema:Person', 'schema:Organization', 'schema:Place'],
      ranges: const ['schema:Text'],
    ),
    'schema:jobTitle': const SchemaProperty(
      id: 'schema:jobTitle',
      label: 'jobTitle',
      comment: 'The job title of the person.',
      domains: const ['schema:Person'],
      ranges: const ['schema:Text'],
    ),
    'schema:address': const SchemaProperty(
      id: 'schema:address',
      label: 'address',
      comment: 'Physical address of the item.',
      domains: const ['schema:Person', 'schema:Organization', 'schema:Place'],
      ranges: const ['schema:PostalAddress', 'schema:Text'],
    ),
    'schema:worksFor': const SchemaProperty(
      id: 'schema:worksFor',
      label: 'worksFor',
      comment: 'Organizations that the person works for.',
      domains: const ['schema:Person'],
      ranges: const ['schema:Organization'],
    ),
    'schema:birthDate': const SchemaProperty(
      id: 'schema:birthDate',
      label: 'birthDate',
      comment: 'Date of birth.',
      domains: const ['schema:Person'],
      ranges: const ['schema:Date'],
    ),
    'schema:foundingDate': const SchemaProperty(
      id: 'schema:foundingDate',
      label: 'foundingDate',
      comment: 'The date that this organization was founded.',
      domains: const ['schema:Organization'],
      ranges: const ['schema:Date'],
    ),
    'schema:logo': const SchemaProperty(
      id: 'schema:logo',
      label: 'logo',
      comment: 'An associated logo.',
      domains: const ['schema:Organization', 'schema:Place'],
      ranges: const ['schema:URL', 'schema:ImageObject'],
    ),
    'schema:priceRange': const SchemaProperty(
      id: 'schema:priceRange',
      label: 'priceRange',
      comment:
          'The price range of the business represented by relative number of dollar signs.',
      domains: const ['schema:LocalBusiness'],
      ranges: const ['schema:Text'],
    ),
    'schema:brand': const SchemaProperty(
      id: 'schema:brand',
      label: 'brand',
      comment: 'The brand or manufacturer associated with the product.',
      domains: const ['schema:Product'],
      ranges: const ['schema:Organization', 'schema:Brand'],
    ),
    'schema:offers': const SchemaProperty(
      id: 'schema:offers',
      label: 'offers',
      comment:
          'An offer to provide this item—for example, an offer to sell a product.',
      domains: const ['schema:Product', 'schema:Event'],
      ranges: const ['schema:Offer'],
    ),
    'schema:sku': const SchemaProperty(
      id: 'schema:sku',
      label: 'sku',
      comment: 'Stock Keeping Unit (SKU).',
      domains: const ['schema:Product'],
      ranges: const ['schema:Text'],
    ),
    'schema:price': const SchemaProperty(
      id: 'schema:price',
      label: 'price',
      comment: 'The offer price.',
      domains: const ['schema:Offer'],
      ranges: const ['schema:Number', 'schema:Text'],
    ),
    'schema:priceCurrency': const SchemaProperty(
      id: 'schema:priceCurrency',
      label: 'priceCurrency',
      comment: 'The currency of the price, in 3-letter ISO 4217 format.',
      domains: const ['schema:Offer'],
      ranges: const ['schema:Text'],
    ),
    'schema:availability': const SchemaProperty(
      id: 'schema:availability',
      label: 'availability',
      comment: 'The availability of this item (e.g. InStock, OutOfStock).',
      domains: const ['schema:Offer'],
      ranges: const ['schema:ItemAvailability', 'schema:Text'],
    ),
    'schema:streetAddress': const SchemaProperty(
      id: 'schema:streetAddress',
      label: 'streetAddress',
      comment: 'The street address.',
      domains: const ['schema:PostalAddress'],
      ranges: const ['schema:Text'],
    ),
    'schema:addressLocality': const SchemaProperty(
      id: 'schema:addressLocality',
      label: 'addressLocality',
      comment:
          'The locality in which the street address is, and which is in the region. For example, Mountain View.',
      domains: const ['schema:PostalAddress'],
      ranges: const ['schema:Text'],
    ),
    'schema:addressRegion': const SchemaProperty(
      id: 'schema:addressRegion',
      label: 'addressRegion',
      comment:
          'The region in which the locality is, and which is in the country. For example, California.',
      domains: const ['schema:PostalAddress'],
      ranges: const ['schema:Text'],
    ),
    'schema:postalCode': const SchemaProperty(
      id: 'schema:postalCode',
      label: 'postalCode',
      comment: 'The postal code. For example, 94043.',
      domains: const ['schema:PostalAddress'],
      ranges: const ['schema:Text'],
    ),
    'schema:addressCountry': const SchemaProperty(
      id: 'schema:addressCountry',
      label: 'addressCountry',
      comment: 'The country. For example, USA.',
      domains: const ['schema:PostalAddress'],
      ranges: const ['schema:Text'],
    ),
    'schema:areaServed': const SchemaProperty(
      id: 'schema:areaServed',
      label: 'areaServed',
      comment:
          'The geographic area where a service or offered item is provided.',
      domains: const [
        'schema:LocalBusiness',
        'schema:Service',
        'schema:Organization'
      ],
      ranges: const [
        'schema:Place',
        'schema:AdministrativeArea',
        'schema:GeoShape',
        'schema:Text'
      ],
    ),
    'schema:geoMidpoint': const SchemaProperty(
      id: 'schema:geoMidpoint',
      label: 'geoMidpoint',
      comment: 'Indicates the geographic midpoint of the areaServed.',
      domains: const ['schema:GeoCircle'],
      ranges: const ['schema:GeoCoordinates'],
    ),
    'schema:geoRadius': const SchemaProperty(
      id: 'schema:geoRadius',
      label: 'geoRadius',
      comment: 'Indicates the geoRadius of the GeoCircle.',
      domains: const ['schema:GeoCircle'],
      ranges: const ['schema:Distance', 'schema:Number', 'schema:Text'],
    ),
    'schema:latitude': const SchemaProperty(
      id: 'schema:latitude',
      label: 'latitude',
      comment: 'The latitude of a location.',
      domains: const ['schema:GeoCoordinates'],
      ranges: const ['schema:Number', 'schema:Text'],
    ),
    'schema:longitude': const SchemaProperty(
      id: 'schema:longitude',
      label: 'longitude',
      comment: 'The longitude of a location.',
      domains: const ['schema:GeoCoordinates'],
      ranges: const ['schema:Number', 'schema:Text'],
    ),
  };

  static const Map<String, List<String>> _popularEnumerations = {
    'schema:ItemAvailability': const [
      'schema:Discontinued',
      'schema:InStock',
      'schema:InStoreOnly',
      'schema:LimitedAvailability',
      'schema:OnlineOnly',
      'schema:OutOfStock',
      'schema:PreOrder',
      'schema:PreSale',
      'schema:SoldOut',
    ],
    'schema:DayOfWeek': const [
      'schema:Monday',
      'schema:Tuesday',
      'schema:Wednesday',
      'schema:Thursday',
      'schema:Friday',
      'schema:Saturday',
      'schema:Sunday',
    ],
    'schema:BookFormatType': const [
      'schema:AudiobookFormat',
      'schema:EBook',
      'schema:Hardcover',
      'schema:GraphicNovel',
      'schema:Paperback',
    ],
    'schema:PaymentMethod': const [
      'schema:CreditCard',
      'schema:Cash',
      'schema:CheckInAdvance',
      'schema:COD',
      'schema:DirectDebit',
      'schema:PayPal',
    ],
  };

  Future<void> init() async {
    _classes = Map.from(_popularClasses);
    _properties = Map.from(_popularProperties);
    _enumerationValues = Map.from(_popularEnumerations);
    final hasCache = await _loadFromCache();
    if (hasCache) {
      isFullSchemaLoaded = true;
      debugPrint(
        'Loaded all ${classes.length} classes, ${properties.length} properties, and ${_enumerationValues.length} enums from local cache!',
      );
    }
    _fetchAndCacheLatestSchema();
  }

  Future<bool> _loadFromCache() async {
    try {
      final String? cachedClassesJson = sharedPrefs.getString(
        'schemaorg_classes_cached',
      );
      final String? cachedPropsJson = sharedPrefs.getString(
        'schemaorg_properties_cached',
      );
      final String? cachedEnumsJson = sharedPrefs.getString(
        'schemaorg_enums_cached',
      );
      if (cachedClassesJson != null && cachedPropsJson != null) {
        final List<dynamic> decodedClasses = json.decode(cachedClassesJson);
        final List<dynamic> decodedProps = json.decode(cachedPropsJson);
        final Map<String, SchemaClass> tempClasses = {};
        final Map<String, SchemaProperty> tempProps = {};
        for (var item in decodedClasses) {
          final cls = SchemaClass.fromJson(item as Map<String, dynamic>);
          tempClasses[cls.id] = cls;
        }
        for (var item in decodedProps) {
          final prop = SchemaProperty.fromJson(item as Map<String, dynamic>);
          tempProps[prop.id] = prop;
        }
        if (cachedEnumsJson != null) {
          final Map<String, dynamic> decodedEnums = json.decode(
            cachedEnumsJson,
          );
          _enumerationValues = decodedEnums.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          );
        }
        if (tempClasses.isNotEmpty && tempProps.isNotEmpty) {
          _classes = tempClasses;
          _properties = tempProps;
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error reading schema cache from SharedPreferences: ${e}');
    }
    return false;
  }

  Future<void> _fetchAndCacheLatestSchema() async {
    if (isLoadingFullSchema) {
      return;
    }
    isLoadingFullSchema = true;
    loadError = null;
    try {
      final response = await _dio.get(
        'https://schema.org/version/latest/schemaorg-current-https.jsonld',
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.data as String);
        final List<dynamic> graph = data['@graph'] as List<dynamic>? ?? [];
        final Map<String, SchemaClass> parsedClasses = {};
        final Map<String, SchemaProperty> parsedProperties = {};
        final Map<String, List<String>> parsedEnums = {};
        for (var item in graph) {
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final String id = item['@id'] as String? ?? '';
          if (id.isEmpty) {
            continue;
          }
          final dynamic typeVal = item['@type'];
          final List<String> types = _extractIds(typeVal);
          final String label = _extractString(
            item['rdfs:label'] ?? id.split(':').last,
          );
          final String comment = _extractString(item['rdfs:comment'] ?? '');
          if (types.contains('rdfs:Class')) {
            final List<String> subClasses = _extractIds(
              item['rdfs:subClassOf'],
            );
            parsedClasses[id] = SchemaClass(
              id: id,
              label: label,
              comment: comment,
              subClassOf: subClasses,
            );
          } else if (types.contains('rdf:Property')) {
            final List<String> domains = _extractIds(
              item['schema:domainIncludes'],
            );
            final List<String> ranges = _extractIds(
              item['schema:rangeIncludes'],
            );
            parsedProperties[id] = SchemaProperty(
              id: id,
              label: label,
              comment: comment,
              domains: domains,
              ranges: ranges,
            );
          } else {
            for (var typeId in types) {
              if (typeId != 'rdfs:Class' && typeId != 'rdf:Property') {
                if (!parsedEnums.containsKey(typeId)) {
                  parsedEnums[typeId] = [];
                }
                if (!parsedEnums[typeId]!.contains(id)) {
                  parsedEnums[typeId]?.add(id);
                }
              }
            }
          }
        }
        if (parsedClasses.isNotEmpty && parsedProperties.isNotEmpty) {
          _classes = parsedClasses;
          _properties = parsedProperties;
          _enumerationValues = parsedEnums;
          isFullSchemaLoaded = true;
          final List<Map<String, dynamic>> serializedClasses =
              parsedClasses.values.map((c) => clsToJson(c)).toList();
          final List<Map<String, dynamic>> serializedProps =
              parsedProperties.values.map((p) => propToJson(p)).toList();
          await sharedPrefs.setString(
            'schemaorg_classes_cached',
            json.encode(serializedClasses),
          );
          await sharedPrefs.setString(
            'schemaorg_properties_cached',
            json.encode(serializedProps),
          );
          await sharedPrefs.setString(
            'schemaorg_enums_cached',
            json.encode(parsedEnums),
          );
          debugPrint(
            'Successfully fetched and cached latest ${parsedClasses.length} Schema.org classes, ${parsedProperties.length} properties, and ${parsedEnums.length} enums!',
          );
        } else {
          throw Exception(
            'No classes or properties found in the downloaded JSON-LD schema.',
          );
        }
      } else {
        throw Exception('Failed to load. Status code: ${response.statusCode}');
      }
    } catch (e) {
      loadError = e.toString();
      debugPrint('Error loading full Schema.org schema from network: ${e}');
    } finally {
      isLoadingFullSchema = false;
    }
  }

  String _normalizeId(String id) {
    var normalized = id.trim();
    if (normalized.startsWith('https://schema.org/')) {
      normalized = normalized.substring('https://schema.org/'.length);
    } else if (normalized.startsWith('http://schema.org/')) {
      normalized = normalized.substring('http://schema.org/'.length);
    } else if (normalized.startsWith('schema:')) {
      normalized = normalized.substring('schema:'.length);
    }
    return normalized;
  }

  bool isSubclassOf(String childId, String parentId) {
    final normChild = _normalizeId(childId);
    final normParent = _normalizeId(parentId);
    if (normChild == normParent) {
      return true;
    }
    if (normParent == 'Thing') {
      return true;
    }

    // Find the class in classes using prefix-agnostic lookup
    SchemaClass? cls;
    for (var entry in classes.entries) {
      if (_normalizeId(entry.key) == normChild) {
        cls = entry.value;
        break;
      }
    }
    if (cls == null) {
      return false;
    }
    for (var parent in cls.subClassOf) {
      if (isSubclassOf(parent, parentId)) {
        return true;
      }
    }
    return false;
  }

  List<String> getEnumOptions(List<String> ranges) {
    final List<String> options = [];
    for (var rangeId in ranges) {
      final values = _enumerationValues[rangeId];
      if (values != null) {
        options.addAll(values);
      }
    }
    options.sort();
    return options;
  }

  Map<String, dynamic> clsToJson(SchemaClass cls) {
    return {
      'id': cls.id,
      'label': cls.label,
      'comment': cls.comment,
      'subClassOf': cls.subClassOf,
    };
  }

  Map<String, dynamic> propToJson(SchemaProperty prop) {
    return {
      'id': prop.id,
      'label': prop.label,
      'comment': prop.comment,
      'domains': prop.domains,
      'ranges': prop.ranges,
    };
  }

  String _extractString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      if (value.containsKey('@value')) {
        return value['@value'].toString();
      }
    }
    if (value is List && value.isNotEmpty) {
      return _extractString(value.first);
    }
    return value.toString();
  }

  List<String> _extractIds(dynamic value) {
    if (value == null) {
      return [];
    }
    if (value is String) {
      return [value];
    }
    if (value is Map<String, dynamic>) {
      if (value.containsKey('@id')) {
        return [value['@id'].toString()];
      }
    }
    if (value is List) {
      final List<String> result = [];
      for (var item in value) {
        result.addAll(_extractIds(item));
      }
      return result;
    }
    return [];
  }

  List<SchemaProperty> getPropertiesForClass(String classId) {
    final List<String> ancestorClasses = _getAncestors(classId);
    ancestorClasses.add(classId);
    if (!ancestorClasses.contains('schema:Thing')) {
      ancestorClasses.add('schema:Thing');
    }
    final List<SchemaProperty> matchingProperties = [];
    for (var prop in properties.values) {
      for (var domain in prop.domains) {
        if (ancestorClasses.contains(domain)) {
          matchingProperties.add(prop);
          break;
        }
      }
    }
    matchingProperties.sort((a, b) => a.label.compareTo(b.label));
    return matchingProperties;
  }

  List<String> _getAncestors(String classId) {
    final List<String> ancestors = [];
    final queue = <String>[classId];
    final visited = <String>{};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final normCurrent = _normalizeId(current);
      if (visited.contains(normCurrent)) {
        continue;
      }
      visited.add(normCurrent);

      SchemaClass? cls;
      for (var entry in classes.entries) {
        if (_normalizeId(entry.key) == normCurrent) {
          cls = entry.value;
          break;
        }
      }

      if (cls != null) {
        for (var parent in cls.subClassOf) {
          final normParent = _normalizeId(parent);
          if (!ancestors.any((anc) => _normalizeId(anc) == normParent)) {
            ancestors.add(parent);
            queue.add(parent);
          }
        }
      }
    }
    return ancestors;
  }
}
