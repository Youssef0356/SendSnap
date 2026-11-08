import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendsnap/services/local_storage_service.dart';

void main() {
  test('LocalStorageService local item model & categories', () async {
    final tempDir = Directory.systemTemp.createTempSync('sendsnap_storage_test_');
    final imgFile = File('${tempDir.path}/test_image.png');
    final docFile = File('${tempDir.path}/notes.pdf');
    final vidFile = File('${tempDir.path}/clip.mp4');
    final subDir = Directory('${tempDir.path}/subfolder');

    await imgFile.writeAsBytes([1, 2, 3, 4, 5]);
    await docFile.writeAsString('Test PDF content');
    await vidFile.writeAsBytes([10, 20, 30]);
    await subDir.create();

    final items = await LocalStorageService.getItems(
      category: StorageCategory.files,
      currentDirectoryPath: tempDir.path,
    );

    expect(items.length, 4);

    final folderItem = items.firstWhere((i) => i.name == 'subfolder');
    expect(folderItem.isDirectory, isTrue);

    final imgItem = items.firstWhere((i) => i.name == 'test_image.png');
    expect(imgItem.isImage, isTrue);
    expect(imgItem.isVideo, isFalse);
    expect(imgItem.size, 5);

    final pdfItem = items.firstWhere((i) => i.name == 'notes.pdf');
    expect(pdfItem.isDocument, isTrue);

    final vidItem = items.firstWhere((i) => i.name == 'clip.mp4');
    expect(vidItem.isVideo, isTrue);

    // Verify recent, photos, documents categories load without errors
    final recentItems = await LocalStorageService.getItems(category: StorageCategory.recent);
    expect(recentItems, isA<List<LocalItem>>());

    final photoItems = await LocalStorageService.getItems(category: StorageCategory.photos);
    expect(photoItems, isA<List<LocalItem>>());

    final docItems = await LocalStorageService.getItems(category: StorageCategory.documents);
    expect(docItems, isA<List<LocalItem>>());

    tempDir.deleteSync(recursive: true);
  });
}
