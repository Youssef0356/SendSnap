import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../config/constants.dart';
import '../services/file_handler.dart';
import '../services/bidi_helper.dart';
import '../l10n/app_localizations.dart';

/// A multi-file tray container with individual draggable cards per file,
/// support for dragging individual files, dragging the entire container to send all,
/// and adding/removing files dynamically.
class DraggableFileToken extends StatefulWidget {
  final List<File> files;
  final VoidCallback? onClear;
  final VoidCallback? onAddMore;
  final void Function(File file)? onRemoveFile;
  final void Function(Offset globalPosition, {String? fileName})? onDragUpdate;

  const DraggableFileToken({
    super.key,
    required this.files,
    this.onClear,
    this.onAddMore,
    this.onRemoveFile,
    this.onDragUpdate,
  });

  @override
  State<DraggableFileToken> createState() => _DraggableFileTokenState();
}

class _DraggableFileTokenState extends State<DraggableFileToken> {
  bool _isMasterDragging = false;
  String? _activeDraggingPath;

  int _calculateTotalBytes() {
    int total = 0;
    for (final f in widget.files) {
      try {
        if (f.existsSync()) total += f.lengthSync();
      } catch (_) {}
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final count = widget.files.length;
    final totalBytes = _calculateTotalBytes();
    final totalSizeFormatted = totalBytes > 0 ? BidiHelper.isolate(FileHandler.formatFileSize(totalBytes)) : '';

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isMasterDragging
              ? AppColors.primary
              : Colors.white,
          width: _isMasterDragging ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isMasterDragging
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: _isMasterDragging ? 28 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Container Top Bar: Draggable Header ("DRAG ALL" master handle + actions)
          _buildMasterHeader(count, totalSizeFormatted, l10n),

          // Cards Row / Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: count == 1
                ? _buildSingleFileRow(widget.files.first)
                : _buildMultiFileCarousel(),
          ),

          // Micro helper hint
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    count > 1
                        ? (l10n?.homeDropHintMulti ?? 'Drop file per file or drag header to send all')
                        : (l10n?.homeDropHintSingle ?? 'Drag card to nearby device or edge to send'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The master drag handle across the container header
  Widget _buildMasterHeader(int count, String totalSizeFormatted, AppLocalizations? l10n) {
    final dragHandle = MouseRegion(
      cursor: _isMasterDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: Draggable<List<File>>(
        data: widget.files,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () {
          setState(() => _isMasterDragging = true);
          HapticFeedback.mediumImpact();
        },
        onDragUpdate: (details) {
          widget.onDragUpdate?.call(
            details.globalPosition,
            fileName: l10n != null ? l10n.homeFilesCount(count) : '$count files',
          );
        },
        onDragEnd: (details) {
          setState(() => _isMasterDragging = false);
        },
        onDraggableCanceled: (velocity, offset) {
          setState(() => _isMasterDragging = false);
        },
        feedback: Material(
          color: Colors.transparent,
          child: Transform.rotate(
            angle: -0.05,
            child: Transform.scale(
              scale: 1.05,
              child: _buildFeedbackDeck(widget.files, count, totalSizeFormatted),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: _buildMasterPill(count, totalSizeFormatted, isDragging: true, l10n: l10n),
        ),
        child: _buildMasterPill(count, totalSizeFormatted, isDragging: false, l10n: l10n),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          // Drag handle takes available width
          Expanded(child: dragHandle),
          const SizedBox(width: 8),

          // Add more button
          if (widget.onAddMore != null)
            GestureDetector(
              onTap: widget.onAddMore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      l10n?.homeAddFiles ?? 'ADD',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (widget.onClear != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.close_rounded, size: 15, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMasterPill(int count, String totalSize, {required bool isDragging, AppLocalizations? l10n}) {
    final dragAllLabel = l10n?.homeDragAll ?? 'DRAG ALL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: isDragging ? AppColors.sendGradient : null,
        color: !isDragging ? AppColors.primary.withValues(alpha: 0.09) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDragging ? Colors.white : AppColors.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator_rounded,
            size: 15,
            color: isDragging ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              count > 1 ? '$dragAllLabel ($count)' : dragAllLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: isDragging ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          if (totalSize.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '• $totalSize',
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDragging
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Carousel view when multiple files are in the container
  Widget _buildMultiFileCarousel() {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.files.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final file = widget.files[index];
          return _buildDraggableIndividualCard(file);
        },
      ),
    );
  }

  /// Display when exactly 1 file is selected
  Widget _buildSingleFileRow(File file) {
    return _buildDraggableIndividualCard(file, isFullWidth: true);
  }

  /// Wraps an individual file card in `Draggable<List<File>>`
  Widget _buildDraggableIndividualCard(File file, {bool isFullWidth = false}) {
    final isDragging = _activeDraggingPath == file.path;
    final fileName = p.basename(file.path);

    return MouseRegion(
      cursor: isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: Draggable<List<File>>(
        data: [file],
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () {
          setState(() => _activeDraggingPath = file.path);
          HapticFeedback.mediumImpact();
        },
        onDragUpdate: (details) {
          widget.onDragUpdate?.call(
            details.globalPosition,
            fileName: fileName,
          );
        },
        onDragEnd: (details) {
          setState(() => _activeDraggingPath = null);
        },
        onDraggableCanceled: (velocity, offset) {
          setState(() => _activeDraggingPath = null);
        },
        feedback: Material(
          color: Colors.transparent,
          child: Transform.rotate(
            angle: -0.05,
            child: Transform.scale(
              scale: 1.05,
              child: _buildFeedbackSingleCard(file),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _buildFileCardContent(file, isDragging: true, isFullWidth: isFullWidth),
        ),
        child: _buildFileCardContent(file, isDragging: false, isFullWidth: isFullWidth),
      ),
    );
  }

  /// The visual card for each file
  Widget _buildFileCardContent(File file, {required bool isDragging, bool isFullWidth = false}) {
    final l10n = AppLocalizations.of(context);
    final fileName = p.basename(file.path);
    final ext = p.extension(file.path).replaceAll('.', '').toUpperCase();
    final typeInfo = _getFileTypeInfo(ext);
    final fileSize = file.existsSync() ? FileHandler.formatFileSize(file.lengthSync()) : '';
    final isImage = const ['JPG', 'JPEG', 'PNG', 'WEBP', 'GIF', 'HEIC', 'BMP'].contains(ext);

    return Container(
      width: isFullWidth ? double.infinity : 138,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDragging
              ? AppColors.primary
              : Colors.black.withValues(alpha: 0.07),
          width: isDragging ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDragging
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isDragging ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Thumbnail/Icon + Remove Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Thumbnail / Icon
              if (isImage && file.existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    width: 30,
                    height: 30,
                    cacheWidth: 80,
                    cacheHeight: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildIconBadge(typeInfo),
                  ),
                )
              else
                _buildIconBadge(typeInfo),

              // Individual remove button
              if (widget.onRemoveFile != null)
                GestureDetector(
                  onTap: () => widget.onRemoveFile?.call(file),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // File Name & Size
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                fileSize.isNotEmpty ? fileSize : ext,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Bottom DRAG Pill prompt
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 3),
                Text(
                  l10n?.homeDragHandle ?? 'DRAG',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge(_FileTypeInfo typeInfo) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: typeInfo.colors),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(typeInfo.icon, size: 16, color: Colors.white),
      ),
    );
  }

  /// Floating feedback card when dragging an individual file
  Widget _buildFeedbackSingleCard(File file) {
    final fileName = p.basename(file.path);
    final ext = p.extension(file.path).replaceAll('.', '').toUpperCase();
    final typeInfo = _getFileTypeInfo(ext);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconBadge(typeInfo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Drop on device or portal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Floating stacked deck feedback when dragging ALL files
  Widget _buildFeedbackDeck(List<File> files, int count, String totalSize) {
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sending all $count files',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalSize.isNotEmpty ? '$totalSize • Drop to send' : 'Drop to send',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _FileTypeInfo _getFileTypeInfo(String ext) {
    switch (ext) {
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'WEBP':
      case 'GIF':
      case 'HEIC':
      case 'BMP':
        return _FileTypeInfo(
          icon: Icons.image_rounded,
          colors: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
        );
      case 'MP4':
      case 'MKV':
      case 'MOV':
      case 'AVI':
      case 'WEBM':
        return _FileTypeInfo(
          icon: Icons.videocam_rounded,
          colors: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        );
      case 'MP3':
      case 'WAV':
      case 'M4A':
      case 'FLAC':
      case 'AAC':
      case 'OGG':
        return _FileTypeInfo(
          icon: Icons.music_note_rounded,
          colors: const [Color(0xFFEC4899), Color(0xFFF472B6)],
        );
      case 'PDF':
      case 'DOC':
      case 'DOCX':
      case 'TXT':
      case 'XLS':
      case 'XLSX':
      case 'PPT':
      case 'PPTX':
        return _FileTypeInfo(
          icon: Icons.description_rounded,
          colors: const [Color(0xFFEF4444), Color(0xFFF87171)],
        );
      case 'ZIP':
      case 'RAR':
      case '7Z':
      case 'TAR':
      case 'GZ':
      case 'APK':
        return _FileTypeInfo(
          icon: Icons.folder_zip_rounded,
          colors: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        );
      default:
        return _FileTypeInfo(
          icon: Icons.insert_drive_file_rounded,
          colors: const [AppColors.primary, AppColors.accent],
        );
    }
  }
}

class _FileTypeInfo {
  final IconData icon;
  final List<Color> colors;

  const _FileTypeInfo({required this.icon, required this.colors});
}
