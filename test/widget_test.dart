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
    expect(find.text('Json LD Visual Editor'), findsOneWidget);
  });
}
