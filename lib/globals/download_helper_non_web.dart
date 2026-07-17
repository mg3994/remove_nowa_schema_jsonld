import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> downloadFile(String content, String filename) async {
  Directory? directory;
  try {
    directory = await getDownloadsDirectory();
  } catch (e) {
    // getDownloadsDirectory might not be supported on all platforms or configurations
  }

  if (directory == null) {
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (e) {
      // fallback to temporary directory if documents directory is somehow inaccessible
      directory = await getTemporaryDirectory();
    }
  }

  final file = File('${directory.path}/$filename');
  await file.writeAsString(content);
  return file.path;
}
