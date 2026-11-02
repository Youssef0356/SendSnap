import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendsnap/models/device.dart';
import 'package:sendsnap/models/transfer.dart';
import 'package:sendsnap/services/http_transfer_server.dart';
import 'package:sendsnap/services/http_transfer_client.dart';
import 'package:sendsnap/services/network_info_service.dart';

void main() {
  HttpOverrides.global = null;

  test('End-to-End HTTP Transfer Engine Test', () async {
    final server = HttpTransferServer();
    final client = HttpTransferClient();

    final localDevice = NearbyDevice(
      id: 'test-receiver-id',
      name: 'Receiver Phone',
      ip: '127.0.0.1',
      port: 0,
      deviceType: NetworkInfoService.getPlatformName(),
    );

    // 1. Start Server on ephemeral port
    final boundPort = await server.startServer(localDevice: localDevice, port: 0);
    expect(boundPort, isNotNull);
    expect(boundPort! > 0, isTrue);

    final receiverDevice = localDevice.copyWith(port: boundPort);

    // 2. Client ping
    final pingResult = await client.ping('127.0.0.1', boundPort);
    expect(pingResult, isNotNull);
    expect(pingResult!.name, 'Receiver Phone');

    // 3. Create dummy file to send
    final tempDir = Directory.systemTemp.createTempSync('sendsnap_test_');
    final dummyFile = File('${tempDir.path}/hello.txt');
    final fileContent = 'Hello, SendSnap High Speed Architecture!' * 100;
    await dummyFile.writeAsString(fileContent);

    final fileTransfer = FileTransfer(
      id: 'transfer-1',
      fileName: 'hello.txt',
      fileSize: await dummyFile.length(),
    );

    bool requestReceived = false;
    server.onRequestReceived = ({required sessionId, required sender, required files}) async {
      requestReceived = true;
      expect(files.first.fileName, 'hello.txt');
      return true;
    };

    int lastProgress = 0;
    double lastSpeed = 0.0;
    server.onProgress = ({required sessionId, required fileId, required bytesReceived, required totalBytes, required speed}) {
      lastProgress = bytesReceived;
      lastSpeed = speed;
    };

    String? completedSavedPath;
    server.onFileCompleted = ({required sessionId, required fileId, required savedPath}) {
      completedSavedPath = savedPath;
    };

    // 4. Client prepares transfer
    final senderDevice = NearbyDevice(
      id: 'test-sender-id',
      name: 'Sender Laptop',
      ip: '127.0.0.1',
      port: 53319,
    );

    final prepared = await client.prepareTransfer(
      target: receiverDevice,
      sender: senderDevice,
      sessionId: 'sess-001',
      files: [fileTransfer],
    );
    expect(prepared, isTrue);
    expect(requestReceived, isTrue);

    // 5. Client uploads file stream
    final uploadSuccess = await client.uploadFile(
      target: receiverDevice,
      sessionId: 'sess-001',
      fileTransfer: fileTransfer,
      file: dummyFile,
      onProgress: (sent, total, speed) {},
    );

    expect(uploadSuccess, isTrue);
    expect(lastProgress, dummyFile.lengthSync());
    expect(lastSpeed >= 0.0, isTrue);
    expect(completedSavedPath, isNotNull);

    // 6. Verify file content on disk
    final receivedFile = File(completedSavedPath!);
    expect(await receivedFile.exists(), isTrue);
    expect(await receivedFile.readAsString(), fileContent);

    // Clean up
    await server.stopServer();
    try {
      await receivedFile.delete();
      await dummyFile.delete();
      await tempDir.delete();
    } catch (_) {}
  });
}
