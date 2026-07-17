import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Downloads a JSON-LD schema file safely and in full compliance with modern
/// Google Play Store scoped storage policies.
Future<String?> downloadFile(String content, String filename) async {
  Directory? directory;

  if (Platform.isAndroid) {
    // 1. Try public Download folder on Android. Under Scoped Storage (Android 10+),
    // apps can create and write files directly inside the shared /storage/emulated/0/Download
    // directory without requiring broad READ/WRITE_EXTERNAL_STORAGE permissions.
    final publicDownloadDir = Directory('/storage/emulated/0/Download');
    try {
      if (publicDownloadDir.existsSync()) {
        final file = File('${publicDownloadDir.path}/$filename');
        await file.writeAsString(content);
        return file.path;
      }
    } catch (e) {
      // If direct public storage access fails on some Android configurations,
      // fallback to the modern app-specific Scoped Storage downloads directory.
    }

    // 2. Try app-specific Scoped Storage external downloads directory
    // (requires zero runtime permissions and is fully Play Console policy compliant).
    try {
      final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (extDirs != null && extDirs.isNotEmpty) {
        directory = extDirs.first;
      }
    } catch (e) {
      // Ignored, fallback to internal storage
    }
  }

  // 3. Fallback for iOS/macOS/Linux or if external storage is inaccessible
  if (directory == null) {
    try {
      directory = await getDownloadsDirectory();
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
