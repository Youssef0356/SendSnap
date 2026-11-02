import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

class FileHandler {
  /// Gets a safe directory to store downloaded files.
  static Future<Directory> getDownloadsDirectory() async {
    Directory? baseDir;
    try {
      baseDir = await getDownloadsDirectoryPlatform();
    } catch (e) {
      debugPrint('[FileHandler] Error getting platform downloads dir: $e');
    }

    if (baseDir == null) {
      try {
        baseDir = await path_provider.getApplicationDocumentsDirectory();
      } catch (_) {
        baseDir = Directory(p.join(Directory.systemTemp.path, 'SendSnapDownloads'));
      }
    }

    final dir = Directory(p.join(baseDir.path, 'SendSnap'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory?> getDownloadsDirectoryPlatform() async {
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }
      try {
        final extDir = await path_provider.getExternalStorageDirectory();
        if (extDir != null) return extDir;
      } catch (_) {}
    }
    try {
      return await path_provider.getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Generates a unique destination path in the SendSnap downloads folder.
  static Future<String> getAvailableDestinationPath(String fileName) async {
    final destDir = await getDownloadsDirectory();
    String destPath = p.join(destDir.path, fileName);
    int counter = 1;
    while (await File(destPath).exists()) {
      final ext = p.extension(fileName);
      final base = p.basenameWithoutExtension(fileName);
      destPath = p.join(destDir.path, '${base}_$counter$ext');
      counter++;
    }
    return destPath;
  }

  /// Moves or copies a temp file to downloads.
  static Future<File?> moveFileToDownloads(String sourcePath, String fileName) async {
    try {
      final destPath = await getAvailableDestinationPath(fileName);
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('[FileHandler] Source file does not exist: $sourcePath');
        return null;
      }

      final destFile = await sourceFile.copy(destPath);
      try {
        await sourceFile.delete();
      } catch (_) {}
      return destFile;
    } catch (e) {
      debugPrint('[FileHandler] moveFileToDownloads error: $e');
      return null;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Opens a file using the system default application via OpenFilex.
  static Future<bool> openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[FileHandler] Error opening file with OpenFilex: $e');
      return false;
    }
  }

  /// Opens the system file manager at the SendSnap downloads folder.
  static Future<bool> browseDownloadsFolder() async {
    try {
      final dir = await getDownloadsDirectory();
      final result = await OpenFilex.open(dir.path);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[FileHandler] Error opening downloads folder: $e');
      return false;
    }
  }
}
