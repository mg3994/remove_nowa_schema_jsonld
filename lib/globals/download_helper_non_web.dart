import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:downloadsfolder/downloadsfolder.dart';

/// Appends a zero padding for two-digit date/time strings.
String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Checks if a file exists in the directory, and if so, appends a unique timestamp
/// to the filename to avoid overwriting existing files.
String _getUniqueFileName(Directory dir, String filename) {
  final file = File('${dir.path}/$filename');
  if (!file.existsSync()) {
    return filename;
  }
  final dotIdx = filename.lastIndexOf('.');
  String baseName = filename;
  String extension = '';
  if (dotIdx != -1) {
    baseName = filename.substring(0, dotIdx);
    extension = filename.substring(dotIdx);
  }
  final now = DateTime.now();
  final timestamp = '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
  return '${baseName}_$timestamp$extension';
}

/// Helper method to create a File object with a unique filename in the directory.
File _getUniqueFile(Directory dir, String filename) {
  final uniqueName = _getUniqueFileName(dir, filename);
  return File('${dir.path}/$uniqueName');
}

/// Downloads a JSON-LD schema file safely and in full compliance with modern
/// Google Play Store scoped storage policies, preferring the 'JSONLD' subdirectory.
/// If a file with the same name already exists, appends a unique timestamp to prevent overwriting.
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
    final targetFile = _getUniqueFile(jsonLdSubDir, filename);
    await targetFile.writeAsString(content);
    return targetFile.path;
  } catch (e) {
    // If direct write/creation fails (e.g., due to Android 11+ Scoped Storage restrictions),
    // fallback to using the downloadsfolder package's safe copy API to save it to public Downloads.
    try {
      final tempDir = await getTemporaryDirectory();
      final downloadDir = await getDownloadDirectory();
      final uniqueName = _getUniqueFileName(downloadDir, filename);

      final tempFile = File('${tempDir.path}/$uniqueName');
      await tempFile.writeAsString(content);

      final success = await copyFileIntoDownloadFolder(tempFile.path, uniqueName);
      if (success == true) {
        return '${downloadDir.path}/$uniqueName';
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

  final file = _getUniqueFile(directory, filename);
  await file.writeAsString(content);
  return file.path;
}
