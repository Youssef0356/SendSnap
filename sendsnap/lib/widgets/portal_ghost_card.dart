import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Represents an incoming ghost file preview peeking in from the opposite edge
/// with a feathered gradient aura and fancy light typography.
class PortalGhostCard extends StatelessWidget {
  final bool isVisible;
  final String fileName;
  final double penetration; // 0.0 (offscreen) to 1.0 (fully inside)
  final double normalizedY;  // 0.0 to 1.0 vertical screen ratio
  final bool isLeftEdge;

  const PortalGhostCard({
    super.key,
    required this.isVisible,
    required this.fileName,
    this.penetration = 0.0,
    this.normalizedY = 0.5,
    this.isLeftEdge = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible && penetration <= 0.01) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 240.0;
    const cardHeight = 76.0;

    final clampedPene = penetration.clamp(0.0, 1.0);
    final targetX = isLeftEdge
        ? (-cardWidth + (clampedPene * (cardWidth + 24)))
        : (screenSize.width - (clampedPene * (cardWidth + 24)));

    final targetY = (normalizedY * screenSize.height) - (cardHeight / 2);

    return Positioned(
      left: targetX,
      top: targetY.clamp(40.0, screenSize.height - cardHeight - 80),
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: clampedPene.clamp(0.15, 1.0),
          child: Stack(
            children: [
              // 1. Ambient Feathered Gradient Aura bleed
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: isLeftEdge ? Alignment.centerLeft : Alignment.centerRight,
                      end: isLeftEdge ? Alignment.centerRight : Alignment.centerLeft,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        AppColors.accent.withValues(alpha: 0.55 * clampedPene),
                        AppColors.primary.withValues(alpha: 0.30 * clampedPene),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Frosted Floating Glass Card with Light Typography
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.28 * clampedPene),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: Offset(isLeftEdge ? 6 : -6, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.primary],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                fileName.isEmpty ? 'Incoming Transfer' : fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400, // Light and crisp
                                  letterSpacing: 0.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'HANDOFF PORTAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300, // Fancy light font
                                  letterSpacing: 2.2,          // Spaced luxury
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
