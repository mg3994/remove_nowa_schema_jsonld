import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jsonld/main.dart';

void main() {
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
