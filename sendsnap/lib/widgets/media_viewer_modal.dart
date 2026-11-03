import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/file_handler.dart';
import '../services/local_storage_service.dart';

/// Fullscreen in-app media previewer for images and files.
/// Features interactive pinch/wheel zoom, pan physics, metadata inspection,
/// and quick actions (Share via SendSnap, Open with System App).
class MediaViewerModal extends StatelessWidget {
  final LocalItem item;
  final VoidCallback? onShare;

  const MediaViewerModal({
    super.key,
    required this.item,
    this.onShare,
  });

  /// Displays the media viewer as a full-screen frosted glass overlay.
  static Future<void> show(
    BuildContext context, {
    required LocalItem item,
    VoidCallback? onShare,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      useSafeArea: false,
      builder: (ctx) => MediaViewerModal(item: item, onShare: onShare),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImg = item.isImage;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Frosted Ambient Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),

          // 2. Interactive Media Content
          Center(
            child: isImg
                ? _buildInteractiveImage()
                : _buildNonImagePreview(context),
          ),

          // 3. Top Floating Glass App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Close Button
                    _buildGlassCircleButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),

                    // File Title & Size
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.formattedSize,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Share via SendSnap Button
                    if (onShare != null) ...[
                      _buildGlassCircleButton(
                        icon: Icons.send_rounded,
                        tooltip: 'Share via SendSnap',
                        onTap: () {
                          Navigator.of(context).pop();
                          onShare?.call();
                        },
                      ),
                      const SizedBox(width: 10),
                    ],

                    // Open with System Default App
                    _buildGlassCircleButton(
                      icon: Icons.open_in_new_rounded,
                      tooltip: 'Open with default app',
                      onTap: () => FileHandler.openFile(item.path),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Hint Pill for Images
          if (isImg)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pinch_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pinch or scroll to zoom',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveImage() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      panEnabled: true,
      scaleEnabled: true,
      child: Image.file(
        File(item.path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'Could not load image preview',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonImagePreview(BuildContext context) {
    IconData icon = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.primary;

    if (item.isVideo) {
      icon = Icons.video_file_rounded;
      iconColor = Colors.pinkAccent;
    } else if (item.isAudio) {
      icon = Icons.audio_file_rounded;
      iconColor = Colors.amber;
    } else if (item.isDocument) {
      icon = Icons.description_rounded;
      iconColor = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.2),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Icon(icon, size: 54, color: iconColor),
          ),
          const SizedBox(height: 20),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.extension.toUpperCase().replaceAll('.', '')} • ${item.formattedSize}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open with System App', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => FileHandler.openFile(item.path),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    Widget btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}
