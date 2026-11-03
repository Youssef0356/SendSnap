import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../config/constants.dart';

/// A draggable card representing one or more selected files.
/// Features tactile lift feedback, tilt physics while moving,
/// and smooth drop targets.
class DraggableFileToken extends StatefulWidget {
  final List<File> files;
  final VoidCallback? onClear;
  final VoidCallback? onAddMore;
  final void Function(Offset globalPosition)? onDragUpdate;

  const DraggableFileToken({
    super.key,
    required this.files,
    this.onClear,
    this.onAddMore,
    this.onDragUpdate,
  });

  @override
  State<DraggableFileToken> createState() => _DraggableFileTokenState();
}

class _DraggableFileTokenState extends State<DraggableFileToken> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) return const SizedBox.shrink();

    final primaryFile = widget.files.first;
    final fileName = p.basename(primaryFile.path);
    final count = widget.files.length;
    final ext = p.extension(primaryFile.path).replaceAll('.', '').toUpperCase();

    return Draggable<List<File>>(
      data: widget.files,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        setState(() => _isDragging = true);
        HapticFeedback.mediumImpact();
      },
      onDragUpdate: (details) {
        widget.onDragUpdate?.call(details.globalPosition);
      },
      onDragEnd: (details) {
        setState(() => _isDragging = false);
      },
      onDraggableCanceled: (velocity, offset) {
        setState(() => _isDragging = false);
      },
      // What stays on screen while dragging
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildCard(fileName, count, ext, isHovered: false),
      ),
      // What flies under the user's finger
      feedback: Material(
        color: Colors.transparent,
        child: Transform.rotate(
          angle: -0.05, // Subtle realistic card tilt
          child: Transform.scale(
            scale: 1.05,
            child: _buildFeedbackCard(fileName, count, ext),
          ),
        ),
      ),
      // Normal state
      child: _buildCard(fileName, count, ext, isHovered: _isDragging),
    );
  }

  Widget _buildCard(String fileName, int count, String ext, {required bool isHovered}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHovered ? AppColors.primary : Colors.white,
          width: isHovered ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isHovered
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isHovered ? 24 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // File Info
          Flexible(
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
                Text(
                  count > 1 ? '$count files ($ext)' : ext,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Drag prompt indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'DRAG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          if (widget.onAddMore != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onAddMore,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
              ),
            ),
          ],
          if (widget.onClear != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(String fileName, int count, String ext) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 30,
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
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                Text(
                  'Drag to portal to send',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
