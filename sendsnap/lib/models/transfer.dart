enum TransferStatus { pending, inProgress, completed, failed, cancelled }

class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final int transferredBytes;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.errorMessage,
    DateTime? createdAt,
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
  }) {
    return FileTransfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
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
  };

  factory FileTransfer.fromJson(Map<String, dynamic> json) => FileTransfer(
    id: json['id'],
    fileName: json['fileName'],
    fileSize: json['fileSize'],
    transferredBytes: json['transferredBytes'],
    status: TransferStatus.values[json['status']],
    errorMessage: json['errorMessage'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}
