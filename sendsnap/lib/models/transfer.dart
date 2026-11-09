import '../services/bidi_helper.dart';

enum TransferStatus { pending, inProgress, completed, failed, cancelled }

class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final int transferredBytes;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final String? savedPath; // Receiver side
  final String? filePath;  // Sender side
  final double speed;      // bytes per second

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.errorMessage,
    DateTime? createdAt,
    this.savedPath,
    this.filePath,
    this.speed = 0.0,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => fileSize == 0 ? 0 : (transferredBytes / fileSize).clamp(0.0, 1.0);

  String get formattedSpeed {
    final String raw;
    if (speed < 1024) {
      raw = '${speed.toStringAsFixed(0)} B/s';
    } else if (speed < 1024 * 1024) {
      raw = '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      raw = '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return BidiHelper.isolate(raw);
  }

  FileTransfer copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    int? transferredBytes,
    TransferStatus? status,
    String? errorMessage,
    DateTime? createdAt,
    String? savedPath,
    String? filePath,
    double? speed,
  }) {
    return FileTransfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      savedPath: savedPath ?? this.savedPath,
      filePath: filePath ?? this.filePath,
      speed: speed ?? this.speed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'fileSize': fileSize,
    'transferredBytes': transferredBytes,
    'status': status.index,
    'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'savedPath': savedPath,
    'filePath': filePath,
    'speed': speed,
  };

  factory FileTransfer.fromJson(Map<String, dynamic> json) => FileTransfer(
    id: json['id'] as String,
    fileName: BidiHelper.sanitizeFileName(json['fileName'] as String),
    fileSize: json['fileSize'] as int,
    transferredBytes: json['transferredBytes'] as int? ?? 0,
    status: TransferStatus.values[json['status'] as int],
    errorMessage: json['errorMessage'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    savedPath: json['savedPath'] as String?,
    filePath: json['filePath'] as String?,
    speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
  );
}
