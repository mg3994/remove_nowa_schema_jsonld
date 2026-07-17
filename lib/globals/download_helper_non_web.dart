import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:downloadsfolder/downloadsfolder.dart';

/// Downloads a JSON-LD schema file safely and in full compliance with modern
/// Google Play Store scoped storage policies, preferring the 'JSONLD' subdirectory.
Future<String?> downloadFile(String content, String filename) async {
  try {
    // 1. Get the public Downloads folder using downloadsfolder package
    final downloadDir = await getDownloadDirectory();
    final jsonLdSubDir = Directory('${downloadDir.path}/JSONLD');

    // Create the 'JSONLD' subdirectory if it doesn't exist
    if (!await jsonLdSubDir.exists()) {
      await jsonLdSubDir.create(recursive: true);
    }

    // Attempt to write directly to the 'JSONLD' subdirectory in the public Downloads
    final targetFile = File('${jsonLdSubDir.path}/$filename');
    await targetFile.writeAsString(content);
    return targetFile.path;
  } catch (e) {
    // If direct write/creation fails (e.g., due to Android 11+ Scoped Storage restrictions),
    // fallback to using the downloadsfolder package's safe copy API to save it to public Downloads.
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsString(content);

      final success = await copyFileIntoDownloadFolder(tempFile.path, filename);
      if (success == true) {
        final downloadDir = await getDownloadDirectory();
        return '${downloadDir.path}/$filename';
      }
    } catch (e2) {
      // Ignored, fallback to standard path_provider folders
    }
  }

  // 2. Fallback to standard app-specific external files directories
  Directory? directory;
  if (Platform.isAndroid) {
    try {
      final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (extDirs != null && extDirs.isNotEmpty) {
        directory = Directory('${extDirs.first.path}/JSONLD');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  if (directory == null) {
    try {
      final baseDir = await getDownloadsDirectory();
      if (baseDir != null) {
        directory = Directory('${baseDir.path}/JSONLD');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  if (directory == null) {
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (e) {
      directory = await getTemporaryDirectory();
    }
  }

  final file = File('${directory.path}/$filename');
  await file.writeAsString(content);
  return file.path;
}
