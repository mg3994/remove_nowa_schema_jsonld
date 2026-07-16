import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();
  final webDir = Directory('web');
  if (!webDir.existsSync()) {
    webDir.createSync();
  }

  // Download sqlite3.wasm
  try {
    final name = 'sqlite3.wasm';
    final tag = 'sqlite3-2.9.4';
    final uri = Uri.parse(
        'https://github.com/simolus3/sqlite3.dart/releases/download/$tag/$name');
    print('Downloading $name from $uri...');
    final response = await client.get(uri);
    if (response.statusCode == 200) {
      await File('web/$name').writeAsBytes(response.bodyBytes);
      print('Successfully saved $name into web/ directory!');
    } else {
      print('Failed to download $name: Status ${response.statusCode}');
    }
  } catch (e) {
    print('Error downloading sqlite3.wasm: $e');
  }

  // Download drift_worker.js
  try {
    final name = 'drift_worker.js';
    final tag = 'drift-2.31.0';
    final uri = Uri.parse(
        'https://github.com/simolus3/drift/releases/download/$tag/$name');
    print('Downloading $name from $uri...');
    final response = await client.get(uri);
    if (response.statusCode == 200) {
      await File('web/$name').writeAsBytes(response.bodyBytes);
      print('Successfully saved $name into web/ directory!');
    } else {
      // fallback drift_worker.js URL
      final fallbackUri = Uri.parse('https://raw.githubusercontent.com/simolus3/drift/main/drift/lib/src/web/drift_worker.js');
      print('Trying fallback download for drift_worker.js from $fallbackUri...');
      final fallbackResponse = await client.get(fallbackUri);
      if (fallbackResponse.statusCode == 200) {
        await File('web/$name').writeAsBytes(fallbackResponse.bodyBytes);
        print('Successfully saved fallback $name into web/ directory!');
      } else {
        print('Failed fallback download for $name: Status ${fallbackResponse.statusCode}');
      }
    }
  } catch (e) {
    print('Error downloading drift_worker.js: $e');
  }

  client.close();
}
