import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileHandler {
  static const _channel = MethodChannel('com.the356company.sendsnap/file_utils');

  static Future<Directory> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/SendSnap');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDocDir.path, 'SendSnap'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  }

  /// Copies a file from a content:// URI to a destination path using native code.
  static Future<String?> copyFromContentUri(String contentUri, String destPath) async {
    try {
      final result = await _channel.invokeMethod<String>('copyFromContentUri', {
        'uri': contentUri,
        'destPath': destPath,
      });
      debugPrint('[FileHandler] Copied from content URI to: $result');
      return result;
    } catch (e) {
      debugPrint('[FileHandler] Error copying from content URI: $e');
      return null;
    }
  }

  /// Moves a received file to Downloads/SendSnap.
  /// Handles both regular file paths and content:// URIs.
  static Future<File?> moveFileToDownloads(String sourcePath, String fileName) async {
    final destDir = await getDownloadsDirectory();
    // Avoid overwriting existing files by appending a counter
    String destPath = p.join(destDir.path, fileName);
    int counter = 1;
    while (await File(destPath).exists()) {
      final ext = p.extension(fileName);
      final base = p.basenameWithoutExtension(fileName);
      destPath = p.join(destDir.path, '${base}_$counter$ext');
      counter++;
    }

    // Check if it's a content:// URI (from Nearby Connections on Android 11+)
    if (sourcePath.startsWith('content://')) {
      debugPrint('[FileHandler] Source is content URI, using native copy');
      final copiedPath = await copyFromContentUri(sourcePath, destPath);
      if (copiedPath != null) {
        return File(copiedPath);
      }
      debugPrint('[FileHandler] Native copy failed');
      return null;
    }

    // Regular file path
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      debugPrint('[FileHandler] Source file does not exist: $sourcePath');
      return null;
    }
    
    // Copy then delete is safer than rename across partitions
    final destFile = await sourceFile.copy(destPath);
    try { await sourceFile.delete(); } catch (_) {}
    return destFile;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Opens a file using the system's default app via native intent with proper MIME type.
  static Future<void> openFile(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('openFile', {'path': path});
      debugPrint('[FileHandler] Open file result: $result');
    } catch (e) {
      debugPrint('[FileHandler] Error opening file: $e');
    }
  }

  /// Opens the system file manager at the SendSnap downloads folder.
  static Future<void> browseDownloadsFolder() async {
    try {
      final dir = await getDownloadsDirectory();
      final result = await _channel.invokeMethod<bool>('openFileManager', {'path': dir.path});
      debugPrint('[FileHandler] Browse folder result: $result');
    } catch (e) {
      debugPrint('[FileHandler] Error browsing folder: $e');
    }
  }
}
