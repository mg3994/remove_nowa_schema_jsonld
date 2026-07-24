import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jsonld/main.dart';
import 'package:jsonld/schema_entity.dart';
import 'package:jsonld/globals/app_state.dart';

void main() {
  test('Value Object preservation and custom baseUri compilation test', () {
    final Map<String, dynamic> sourceJson = {
      "@context": {
        "@vocab": "https://schema.org/",
        "@base": "https://antinna.com/things/"
      },
      "@type": "Service",
      "name": {
        "@value": "Plumbing Service",
        "@language": "en"
      },
      "description": {
        "@value": "Professional plumbing.",
        "@language": "en"
      }
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);
    doc.baseUri = "https://antinna.com/things/";

    // Check that we retrieved the properties properly
    expect(doc.type, equals("schema:Service"));

    final compiled = doc.toJsonLd(isRoot: true);

    // Verify @context is structured and contains the custom @base
    expect(compiled['@context'], isMap);
    expect(compiled['@context']['@base'], equals("https://antinna.com/things/"));

    // Verify Value Objects are preserved exactly without adding @id or node @type
    final nameObj = compiled['name'];
    expect(nameObj, isMap);
    expect(nameObj['@value'], equals("Plumbing Service"));
    expect(nameObj['@language'], equals("en"));
    expect(nameObj.containsKey('@id'), isFalse);
    expect(nameObj['@type'], isNull);

    final descObj = compiled['description'];
    expect(descObj, isMap);
    expect(descObj['@value'], equals("Professional plumbing."));
    expect(descObj['@language'], equals("en"));
    expect(descObj.containsKey('@id'), isFalse);
    expect(descObj['@type'], isNull);
  });

  test('Value Object with xsd:date type includes xsd namespace in @context', () {
    final Map<String, dynamic> sourceJson = {
      "@context": "https://schema.org",
      "@type": "Event",
      "startDate": {
        "@value": "2026-07-20",
        "@type": "xsd:date"
      }
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);

    // 1. With baseUri = null (default fallback)
    final compiledNullBase = doc.toJsonLd(isRoot: true);
    expect(compiledNullBase['@context'], isMap);
    expect(compiledNullBase['@context']['@vocab'], equals("https://schema.org/"));
    expect(compiledNullBase['@context']['xsd'], equals("http://www.w3.org/2001/XMLSchema#"));

    // 2. With a custom baseUri
    doc.baseUri = "https://example.com/events/";
    final compiledWithBase = doc.toJsonLd(isRoot: true);
    expect(compiledWithBase['@context'], isMap);
    expect(compiledWithBase['@context']['@vocab'], equals("https://schema.org/"));
    expect(compiledWithBase['@context']['@base'], equals("https://example.com/events/"));
    expect(compiledWithBase['@context']['xsd'], equals("http://www.w3.org/2001/XMLSchema#"));

    // Verify the value object is preserved perfectly
    final dateObj = compiledWithBase['startDate'];
    expect(dateObj, isMap);
    expect(dateObj['@value'], equals("2026-07-20"));
    expect(dateObj['@type'], equals("xsd:date"));
  });

  test('Custom @type and additional Value Object properties are preserved and resolve namespaces', () {
    final Map<String, dynamic> sourceJson = {
      "@context": "https://schema.org",
      "@type": "snomed:50731006",
      "name": {
        "@value": "Plumbing Service",
        "@language": "en",
        "@direction": "rtl",
        "@index": "my-custom-index"
      }
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);

    final compiled = doc.toJsonLd(isRoot: true);

    // Verify context contains snomed mapping
    expect(compiled['@context'], isMap);
    expect(compiled['@context']['snomed'], equals("http://purl.bioontology.org/ontology/SNOMEDCT/"));

    // Verify root type is kept
    expect(compiled['@type'], equals("snomed:50731006"));

    // Verify value object retains direction and index
    final nameObj = compiled['name'];
    expect(nameObj, isMap);
    expect(nameObj['@value'], equals("Plumbing Service"));
    expect(nameObj['@language'], equals("en"));
    expect(nameObj['@direction'], equals("rtl"));
    expect(nameObj['@index'], equals("my-custom-index"));
  });

  test('Custom context mapping and native language map containers are preserved perfectly', () {
    final Map<String, dynamic> sourceJson = {
      "@context": {
        "@vocab": "https://schema.org/",
        "name": {
          "@container": "@language"
        }
      },
      "@type": "LocalBusiness",
      "name": {
        "en": "Antinna Plumbing",
        "hi": "एंटिन्ना प्लंबिंग"
      }
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);

    final compiled = doc.toJsonLd(isRoot: true);

    // Verify context contains custom name mapping block exactly as imported
    expect(compiled['@context'], isMap);
    expect(compiled['@context']['name'], isMap);
    expect(compiled['@context']['name']['@container'], equals("@language"));

    // Verify name value retains original language map without wrong node promotion
    final nameObj = compiled['name'];
    expect(nameObj, isMap);
    expect(nameObj['en'], equals("Antinna Plumbing"));
    expect(nameObj['hi'], equals("एंटिन्ना प्लंबिंग"));
    expect(nameObj.containsKey('@type'), isFalse);
    expect(nameObj.containsKey('@id'), isFalse);
  });

  test('JSON-LD 1.0 down-conversion expands language maps and YAML-LD serialization converts cleanly', () {
    final Map<String, dynamic> sourceJson = {
      "@context": {
        "@vocab": "https://schema.org/",
        "name": {
          "@container": "@language"
        }
      },
      "@type": "LocalBusiness",
      "name": {
        "en": "Antinna Plumbing",
        "hi": "एंटिन्ना प्लंबिंग"
      }
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);

    // 1. Verify JSON-LD 1.0 down-conversion expands container maps
    final compiled10 = doc.toJsonLd(isRoot: true, targetVersion: '1.0');
    expect(compiled10['@context'], isMap);
    expect(compiled10['@context'].containsKey('@version'), isFalse); // Omit @version in 1.0

    final nameList = compiled10['name'];
    expect(nameList, isList); // Should expand to a list of explicit objects
    expect(nameList[0]['@value'], equals("Antinna Plumbing"));
    expect(nameList[0]['@language'], equals("en"));
    expect(nameList[1]['@value'], equals("एंटिन्ना प्लंबिंग"));
    expect(nameList[1]['@language'], equals("hi"));

    // 2. Verify YAML-LD conversion serializes cleanly
    final yamlOutput = doc.convertToYaml(sourceJson);
    expect(yamlOutput, contains("@context:"));
    expect(yamlOutput, contains('@vocab: "https://schema.org/"'));
    expect(yamlOutput, contains("en: Antinna Plumbing"));
  });

  test('Advanced JSON-LD Keywords Support (reverse, included, nest, protected, propagate)', () {
    final Map<String, dynamic> sourceJson = {
      "@context": {
        "@vocab": "https://schema.org/",
        "id": {
          "@id": "https://schema.org/identifier",
          "@protected": true
        },
        "@propagate": false
      },
      "@type": "Person",
      "name": "Alice",
      "@reverse": {
        "employee": {
          "@type": "Organization",
          "name": "Acme Corp"
        }
      },
      "@nest": {
        "telephone": "+1-555-0199",
        "email": "info@example.com"
      },
      "@included": [
        {
          "@type": "Person",
          "@id": "https://example.com/authors/jane",
          "name": "Jane Doe"
        }
      ]
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);

    // Verify properties mapped to internal representation with correct schema prefixing
    expect(doc.type, equals("schema:Person"));
    expect(doc.properties.containsKey("schema:@reverse"), isTrue);
    expect(doc.properties.containsKey("schema:@nest"), isTrue);
    expect(doc.properties.containsKey("schema:@included"), isTrue);

    final compiled = doc.toJsonLd(isRoot: true, targetVersion: '1.1');

    // Verify context contains protected and propagate rules
    expect(compiled['@context'], isMap);
    expect(compiled['@context']['id'], isMap);
    expect(compiled['@context']['id']['@protected'], isTrue);
    expect(compiled['@context']['@propagate'], isFalse);

    // Verify @reverse is compiled back perfectly
    expect(compiled['@reverse'], isMap);
    final employeeVal = compiled['@reverse']['employee'];
    expect(employeeVal, isMap);
    expect(employeeVal['@type'], equals("Organization"));
    expect(employeeVal['name'], equals("Acme Corp"));

    // Verify @nest is compiled back perfectly
    expect(compiled['@nest'], isMap);
    expect(compiled['@nest']['telephone'], equals("+1-555-0199"));
    expect(compiled['@nest']['email'], equals("info@example.com"));

    // Verify @included is compiled back perfectly
    final includedVal = compiled['@included'];
    final Map<String, dynamic> includedNode = (includedVal is List) ? includedVal.first as Map<String, dynamic> : includedVal as Map<String, dynamic>;
    expect(includedNode['@type'], equals("Person"));
    expect(includedNode['name'], equals("Jane Doe"));

    // Verify converting to 1.0 does NOT incorrectly expand @reverse, @nest, or @included into language value/language arrays
    final compiled10 = doc.toJsonLd(isRoot: true, targetVersion: '1.0');

    expect(compiled10['@reverse'], isMap);
    expect(compiled10['@reverse']['employee'], isMap);
    expect(compiled10['@reverse']['employee']['@type'], equals("Organization"));

    expect(compiled10['@nest'], isMap);
    expect(compiled10['@nest']['telephone'], equals("+1-555-0199"));
    expect(compiled10['@nest']['email'], equals("info@example.com"));
  });

  test('Preservation of @list, @set, and @index containers', () {
    final Map<String, dynamic> sourceJson = {
      "@context": "https://schema.org",
      "@type": "HowTo",
      "steps": {
        "@list": [
          "Turn off water supply",
          "Replace washer"
        ]
      },
      "tags": {
        "@set": ["plumbing", "repairs"]
      },
      "customField": {
        "@value": "Stashed value",
        "@index": "draft-v1"
      }
    };

    final doc = SchemaEntity.fromJsonLd(sourceJson);

    final compiled = doc.toJsonLd(isRoot: true);

    // Verify @list is preserved
    expect(compiled['steps'], isMap);
    expect(compiled['steps']['@list'], isList);
    expect(compiled['steps']['@list'][0], equals("Turn off water supply"));

    // Verify @set is preserved
    expect(compiled['tags'], isMap);
    expect(compiled['tags']['@set'], isList);
    expect(compiled['tags']['@set'][0], equals("plumbing"));

    // Verify @index is preserved
    expect(compiled['customField'], isMap);
    expect(compiled['customField']['@value'], equals("Stashed value"));
    expect(compiled['customField']['@index'], equals("draft-v1"));
  });

  test('Importing @graph with multiple entities creates a single root graph document and serializes perfectly', () {
    final Map<String, dynamic> sourceJson = {
      "@context": "https://schema.org",
      "@graph": [
        {
          "@type": "Person",
          "name": "Alice"
        },
        {
          "@type": "Organization",
          "name": "Tech Corp"
        }
      ]
    };

    // Call fromJsonLd directly
    final importedDoc = SchemaEntity.fromJsonLd(sourceJson);

    // Verify a single document of type schema:@graph is imported
    expect(importedDoc.type, equals("schema:@graph"));
    expect(importedDoc.properties.containsKey("schema:@graph"), isTrue);

    // Verify compiling back to JSON-LD outputs the exact original structure
    final compiled = importedDoc.toJsonLd(isRoot: true, targetVersion: '1.1');
    expect(compiled['@context'], isMap);
    expect(compiled['@context']['@vocab'], equals("https://schema.org/"));
    expect(compiled['@graph'], isList);
    expect(compiled['@graph'].length, equals(2));
    expect(compiled['@graph'][0]['@type'], equals("Person"));
    expect(compiled['@graph'][0]['name'], equals("Alice"));
    expect(compiled['@graph'][1]['@type'], equals("Organization"));
    expect(compiled['@graph'][1]['name'], equals("Tech Corp"));
  });

  testWidgets('Visual Editor loads smoke test', (WidgetTester tester) async {
    // Initialize SharedPreferences with mock values
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Pump a few frames to let initialization microtasks run
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the main visual editor title is displayed.
    expect(find.text('Schema.org Visual Editor'), findsOneWidget);
  });
}
