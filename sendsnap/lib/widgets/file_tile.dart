import 'package:flutter/material.dart';
import '../models/transfer_file.dart';
import '../theme/app_theme.dart';
import 'progress_bar.dart';

/// Row displaying a file with icon, name, size, and transfer status.
class FileTile extends StatelessWidget {
  final TransferFile file;
  final VoidCallback? onRemove;
  final bool showProgress;

  const FileTile({
    super.key,
    required this.file,
    this.onRemove,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SendSnapTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SendSnapTheme.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // File type icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _iconColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _fileIcon(),
                  color: _iconColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Name + size / progress text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusText(),
                      style: TextStyle(
                        color: _statusColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Status icon or remove button
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: SendSnapTheme.accent.withValues(alpha: 0.5),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                )
              else
                _buildStatusIcon(),
            ],
          ),

          // Progress bar
          if (showProgress && file.status == FileTransferStatus.transferring) ...[
            const SizedBox(height: 10),
            SendSnapProgressBar(
              progress: file.progress,
              height: 4,
              showGlow: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (file.status) {
      case FileTransferStatus.completed:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: SendSnapTheme.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: SendSnapTheme.success,
            size: 16,
          ),
        );
      case FileTransferStatus.failed:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: SendSnapTheme.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: SendSnapTheme.error,
            size: 16,
          ),
        );
      case FileTransferStatus.transferring:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: file.progress,
            strokeWidth: 2.5,
            color: SendSnapTheme.highlight,
            backgroundColor: SendSnapTheme.accent.withValues(alpha: 0.1),
          ),
        );
      case FileTransferStatus.waiting:
        return Text(
          'waiting',
          style: TextStyle(
            color: SendSnapTheme.accent.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        );
    }
  }

  String _statusText() {
    switch (file.status) {
      case FileTransferStatus.completed:
        return file.formattedSize;
      case FileTransferStatus.failed:
        return 'Failed';
      case FileTransferStatus.transferring:
        final transferred = (file.progress * file.size).round();
        final tf = TransferFile(name: '', path: '', size: transferred);
        return '${tf.formattedSize} / ${file.formattedSize}';
      case FileTransferStatus.waiting:
        return file.formattedSize;
    }
  }

  Color _statusColor() {
    switch (file.status) {
      case FileTransferStatus.completed:
        return SendSnapTheme.success;
      case FileTransferStatus.failed:
        return SendSnapTheme.error;
      case FileTransferStatus.transferring:
        return SendSnapTheme.highlight;
      case FileTransferStatus.waiting:
        return SendSnapTheme.accent.withValues(alpha: 0.5);
    }
  }

  IconData _fileIcon() {
    final ext = file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_rounded;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
        return Icons.videocam_rounded;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
      case 'ogg':
        return Icons.music_note_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _iconColor() {
    final ext = file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return const Color(0xFF10b981);
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return const Color(0xFF8b5cf6);
      case 'mp3':
      case 'wav':
      case 'aac':
        return const Color(0xFFf59e0b);
      case 'pdf':
        return const Color(0xFFef4444);
      case 'apk':
        return const Color(0xFF22c55e);
      default:
        return SendSnapTheme.primary;
    }
  }
}
