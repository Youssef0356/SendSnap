import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

class FileHandler {
  static const _channel = MethodChannel('com.the356company.sendsnap/file_utils');
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

  /// Opens the system file manager at the SendSnap downloads folder,
  /// or at a specific folder or highlights a file.
  static Future<bool> openFolder({String? folderPath, String? filePath}) async {
    try {
      final String targetPath;
      if (folderPath != null && folderPath.isNotEmpty) {
        targetPath = folderPath;
      } else if (filePath != null && filePath.isNotEmpty) {
        targetPath = p.dirname(filePath);
      } else {
        final dir = await getDownloadsDirectory();
        targetPath = dir.path;
      }

      final dir = Directory(targetPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Android: Native intent via method channel
      if (Platform.isAndroid) {
        try {
          final success = await _channel.invokeMethod<bool>('openFileManager', {
            'path': targetPath,
            'filePath': filePath,
          });
          if (success == true) return true;
        } catch (e) {
          debugPrint('[FileHandler] Android openFileManager error: $e');
        }
      } else if (Platform.isWindows) {
        try {
          if (filePath != null && await File(filePath).exists()) {
            await Process.run('explorer.exe', ['/select,', p.normalize(filePath)]);
          } else {
            await Process.run('explorer.exe', [p.normalize(targetPath)]);
          }
          return true;
        } catch (e) {
          debugPrint('[FileHandler] Windows explorer error: $e');
        }
      } else if (Platform.isMacOS) {
        try {
          if (filePath != null && await File(filePath).exists()) {
            await Process.run('open', ['-R', filePath]);
          } else {
            await Process.run('open', [targetPath]);
          }
          return true;
        } catch (e) {
          debugPrint('[FileHandler] macOS open error: $e');
        }
      } else if (Platform.isLinux) {
        try {
          await Process.run('xdg-open', [targetPath]);
          return true;
        } catch (e) {
          debugPrint('[FileHandler] Linux xdg-open error: $e');
        }
      }

      // Universal fallback
      final result = await OpenFilex.open(targetPath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[FileHandler] Error opening folder: $e');
      return false;
    }
  }

  /// Opens the system file manager at the SendSnap downloads folder.
  static Future<bool> browseDownloadsFolder() => openFolder();
}
