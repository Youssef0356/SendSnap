import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'file_handler.dart';

enum StorageCategory {
  files,
  downloads,
  photos,
  videos,
  audio,
  documents,
  received,
}

class LocalItem {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final bool isDirectory;
  final String extension;

  LocalItem({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.isDirectory,
    required this.extension,
  });

  String get formattedSize => isDirectory ? '' : FileHandler.formatFileSize(size);

  bool get isImage => const ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp', '.svg']
      .contains(extension.toLowerCase());

  bool get isVideo => const ['.mp4', '.mkv', '.mov', '.avi', '.3gp', '.webm', '.flv']
      .contains(extension.toLowerCase());

  bool get isAudio => const ['.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus', '.wma']
      .contains(extension.toLowerCase());

  bool get isDocument => const [
        '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt',
        '.csv', '.rtf', '.zip', '.rar', '.7z', '.tar', '.gz', '.apk', '.json'
      ].contains(extension.toLowerCase());
}

class LocalStorageService {
  static const List<String> _imageExts = [
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'
  ];
  static const List<String> _videoExts = [
    '.mp4', '.mkv', '.mov', '.avi', '.3gp', '.webm', '.flv'
  ];
  static const List<String> _audioExts = [
    '.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus'
  ];
  static const List<String> _docExts = [
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt',
    '.csv', '.zip', '.rar', '.7z', '.apk', '.json'
  ];

  static Future<String> getRootStoragePath() async {
    if (Platform.isAndroid) {
      final emulated = Directory('/storage/emulated/0');
      if (await emulated.exists()) return emulated.path;
    } else if (Platform.isWindows) {
      final user = Platform.environment['USERPROFILE'];
      if (user != null && await Directory(user).exists()) return user;
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && await Directory(home).exists()) return home;
    }
    try {
      final docDir = await path_provider.getApplicationDocumentsDirectory();
      return docDir.path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  static List<String> _getPlatformFolders(String folderName, List<String> androidDefaults) {
    if (Platform.isWindows) {
      final user = Platform.environment['USERPROFILE'] ?? '';
      return [
        p.join(user, folderName),
        p.join(user, 'Downloads'),
        p.join(user, 'Desktop'),
      ];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return [
        p.join(home, folderName),
        p.join(home, 'Downloads'),
        p.join(home, 'Desktop'),
      ];
    }
    return androidDefaults;
  }

  static Future<String> getDownloadsPath() async {
    if (Platform.isAndroid) {
      final dl = Directory('/storage/emulated/0/Download');
      if (await dl.exists()) return dl.path;
    }
    try {
      final dl = await path_provider.getDownloadsDirectory();
      if (dl != null) return dl.path;
    } catch (_) {}
    return await getRootStoragePath();
  }

  /// Lists items according to the selected category or path.
  static Future<List<LocalItem>> getItems({
    required StorageCategory category,
    String? currentDirectoryPath,
  }) async {
    try {
      switch (category) {
        case StorageCategory.files:
          final targetPath = currentDirectoryPath ?? await getRootStoragePath();
          return await _listDirectory(targetPath);

        case StorageCategory.downloads:
          final dlPath = await getDownloadsPath();
          return await _listDirectory(dlPath);

        case StorageCategory.received:
          final sendSnapDir = await FileHandler.getDownloadsDirectory();
          return await _listDirectory(sendSnapDir.path);

        case StorageCategory.photos:
          return await _scanForFiles(
            extensions: _imageExts,
            targetFolders: _getPlatformFolders('Pictures', [
              '/storage/emulated/0/DCIM/Camera',
              '/storage/emulated/0/DCIM',
              '/storage/emulated/0/Pictures',
              '/storage/emulated/0/Download',
            ]),
          );

        case StorageCategory.videos:
          return await _scanForFiles(
            extensions: _videoExts,
            targetFolders: _getPlatformFolders('Videos', [
              '/storage/emulated/0/DCIM/Camera',
              '/storage/emulated/0/Movies',
              '/storage/emulated/0/Download',
              '/storage/emulated/0/DCIM',
            ]),
          );

        case StorageCategory.audio:
          return await _scanForFiles(
            extensions: _audioExts,
            targetFolders: _getPlatformFolders('Music', [
              '/storage/emulated/0/Music',
              '/storage/emulated/0/Download',
              '/storage/emulated/0/Audio',
              '/storage/emulated/0/Podcasts',
            ]),
          );

        case StorageCategory.documents:
          return await _scanForFiles(
            extensions: _docExts,
            targetFolders: _getPlatformFolders('Documents', [
              '/storage/emulated/0/Documents',
              '/storage/emulated/0/Download',
            ]),
          );
      }
    } catch (e) {
      debugPrint('[LocalStorageService] Error loading category $category: $e');
      return [];
    }
  }

  /// Lists a specific directory, separating folders and files.
  static Future<List<LocalItem>> _listDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final folders = <LocalItem>[];
    final files = <LocalItem>[];

    try {
      final entries = dir.listSync(followLinks: false);
      for (final entity in entries) {
        final name = p.basename(entity.path);
        // Ignore hidden files and system android data restricted paths
        if (name.startsWith('.')) continue;

        try {
          final stat = entity.statSync();
          final isDir = stat.type == FileSystemEntityType.directory;
          final item = LocalItem(
            path: entity.path,
            name: name,
            size: isDir ? 0 : stat.size,
            modified: stat.modified,
            isDirectory: isDir,
            extension: isDir ? '' : p.extension(entity.path).toLowerCase(),
          );

          if (isDir) {
            folders.add(item);
          } else {
            files.add(item);
          }
        } catch (_) {
          // Skip inaccessible entities
        }
      }
    } catch (e) {
      debugPrint('[LocalStorageService] Directory list error ($dirPath): $e');
    }

    folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return [...folders, ...files];
  }

  /// Scans known media/documents folders for files matching given extensions.
  static Future<List<LocalItem>> _scanForFiles({
    required List<String> extensions,
    required List<String> targetFolders,
  }) async {
    final results = <LocalItem>[];
    final visitedPaths = <String>{};

    for (final folderPath in targetFolders) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;

      try {
        final entities = dir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          if (entity is File && !visitedPaths.contains(entity.path)) {
            final ext = p.extension(entity.path).toLowerCase();
            if (extensions.contains(ext)) {
              try {
                final stat = entity.statSync();
                results.add(LocalItem(
                  path: entity.path,
                  name: p.basename(entity.path),
                  size: stat.size,
                  modified: stat.modified,
                  isDirectory: false,
                  extension: ext,
                ));
                visitedPaths.add(entity.path);
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('[LocalStorageService] Scan error in $folderPath: $e');
      }
    }

    // Sort newest first
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }
}
