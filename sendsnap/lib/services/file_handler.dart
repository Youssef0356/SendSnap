import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileHandler {
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

  static Future<File> moveFileToDownloads(String sourcePath, String fileName) async {
    final destDir = await getDownloadsDirectory();
    final destPath = p.join(destDir.path, fileName);
    final sourceFile = File(sourcePath);
    
    // Copy then delete is safer than rename across partitions
    final destFile = await sourceFile.copy(destPath);
    await sourceFile.delete();
    return destFile;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
