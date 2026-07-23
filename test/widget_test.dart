import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jsonld/main.dart';
import 'package:jsonld/schema_entity.dart';

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
