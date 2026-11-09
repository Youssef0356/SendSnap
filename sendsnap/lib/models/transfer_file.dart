import 'device.dart';
import '../services/bidi_helper.dart';

enum FileTransferStatus { waiting, transferring, completed, failed }

enum TransferDirection { sending, receiving }

class TransferFile {
  final String name;
  final String path;
  final int size;
  final String? mimeType;
  final FileTransferStatus status;
  final double progress;

  const TransferFile({
    required this.name,
    required this.path,
    required this.size,
    this.mimeType,
    this.status = FileTransferStatus.waiting,
    this.progress = 0.0,
  });

  TransferFile copyWith({
    String? name,
    String? path,
    int? size,
    String? mimeType,
    FileTransferStatus? status,
    double? progress,
  }) {
    return TransferFile(
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'size': size,
        'mimeType': mimeType,
      };

  factory TransferFile.fromJson(Map<String, dynamic> json) {
    return TransferFile(
      name: json['name'] as String,
      path: json['path'] as String? ?? '',
      size: json['size'] as int,
      mimeType: json['mimeType'] as String?,
    );
  }

  String get formattedSize {
    final String raw;
    if (size < 1024) {
      raw = '$size B';
    } else if (size < 1024 * 1024) {
      raw = '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      raw = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      raw = '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return BidiHelper.isolate(raw);
  }
}

class TransferSession {
  final String id;
  final NearbyDevice targetDevice;
  final List<TransferFile> files;
  final TransferDirection direction;
  final double overallProgress;
  final double speed; // bytes per second
  final Duration? timeRemaining;
  final TransferSessionStatus status;
  final String? errorMessage;

  const TransferSession({
    required this.id,
    required this.targetDevice,
    required this.files,
    required this.direction,
    this.overallProgress = 0.0,
    this.speed = 0.0,
    this.timeRemaining,
    this.status = TransferSessionStatus.waitingForAccept,
    this.errorMessage,
  });

  TransferSession copyWith({
    String? id,
    NearbyDevice? targetDevice,
    List<TransferFile>? files,
    TransferDirection? direction,
    double? overallProgress,
    double? speed,
    Duration? timeRemaining,
    TransferSessionStatus? status,
    String? errorMessage,
  }) {
    return TransferSession(
      id: id ?? this.id,
      targetDevice: targetDevice ?? this.targetDevice,
      files: files ?? this.files,
      direction: direction ?? this.direction,
      overallProgress: overallProgress ?? this.overallProgress,
      speed: speed ?? this.speed,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  int get totalSize => files.fold(0, (sum, f) => sum + f.size);

  int get transferredSize =>
      files.fold(0, (sum, f) => sum + (f.progress * f.size).round());

  int get completedFiles =>
      files.where((f) => f.status == FileTransferStatus.completed).length;

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedTimeRemaining {
    if (timeRemaining == null) return '--';
    final seconds = timeRemaining!.inSeconds;
    if (seconds < 60) return '~${seconds}s left';
    if (seconds < 3600) {
      return '~${seconds ~/ 60}m ${seconds % 60}s left';
    }
    return '~${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m left';
  }
}

enum TransferSessionStatus {
  waitingForAccept,
  transferring,
  completed,
  cancelled,
  connectionLost,
  error,
}

class IncomingRequest {
  final String senderName;
  final String senderIp;
  final int senderPort;
  final List<TransferFile> files;
  final dynamic socket; // Raw socket reference

  const IncomingRequest({
    required this.senderName,
    required this.senderIp,
    required this.senderPort,
    required this.files,
    this.socket,
  });

  int get totalSize => files.fold(0, (sum, f) => sum + f.size);

  String get formattedTotalSize {
    final size = totalSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
