enum TransferStatus { pending, inProgress, completed, failed, cancelled }

class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final int transferredBytes;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final String? savedPath; // Local path after file is saved (receiver side)

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.errorMessage,
    DateTime? createdAt,
    this.savedPath,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => fileSize == 0 ? 0 : transferredBytes / fileSize;

  FileTransfer copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    int? transferredBytes,
    TransferStatus? status,
    String? errorMessage,
    DateTime? createdAt,
    String? savedPath,
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
  };

  factory FileTransfer.fromJson(Map<String, dynamic> json) => FileTransfer(
    id: json['id'],
    fileName: json['fileName'],
    fileSize: json['fileSize'],
    transferredBytes: json['transferredBytes'],
    status: TransferStatus.values[json['status']],
    errorMessage: json['errorMessage'],
    createdAt: DateTime.parse(json['createdAt']),
    savedPath: json['savedPath'],
  );
}
