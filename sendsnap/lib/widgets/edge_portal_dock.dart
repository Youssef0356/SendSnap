import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/device.dart';

/// A glowing interactive edge portal dock that lives on the border of the screen.
/// When files are dragged near/into it, it provides magnetic haptics, expands,
/// and accepts the file drop to trigger the transfer.
class EdgePortalDock extends StatefulWidget {
  final NearbyDevice device;
  final Alignment edgeAlignment; // Typically Alignment.centerRight or Alignment.centerLeft
  final void Function(List<File> files) onFileDropped;
  final void Function(double progress, Offset position)? onDragHover;

  const EdgePortalDock({
    super.key,
    required this.device,
    this.edgeAlignment = Alignment.centerRight,
    required this.onFileDropped,
    this.onDragHover,
  });

  @override
  State<EdgePortalDock> createState() => _EdgePortalDockState();
}

class _EdgePortalDockState extends State<EdgePortalDock> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _isRightEdge => widget.edgeAlignment.x > 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRight = _isRightEdge;

    return DragTarget<List<File>>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isHovered = true);
        HapticFeedback.selectionClick();
        return true;
      },
      onLeave: (data) {
        setState(() => _isHovered = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isHovered = false);
        HapticFeedback.heavyImpact();
        widget.onFileDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final active = _isHovered || candidateData.isNotEmpty;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final pulseScale = 0.95 + (_pulseAnimation.value * 0.1);
            final glowAlpha = active ? 0.8 : (0.25 + (_pulseAnimation.value * 0.25));

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: active ? 68 : 36,
              height: active ? 220 : 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                  left: isRight ? const Radius.circular(34) : Radius.zero,
                  right: !isRight ? const Radius.circular(34) : Radius.zero,
                ),
                gradient: LinearGradient(
                  begin: isRight ? Alignment.centerRight : Alignment.centerLeft,
                  end: isRight ? Alignment.centerLeft : Alignment.centerRight,
                  colors: active
                      ? [
                          AppColors.primary,
                          AppColors.accent.withValues(alpha: 0.9),
                        ]
                      : [
                          AppColors.primary.withValues(alpha: 0.8),
                          AppColors.primary.withValues(alpha: 0.15),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: glowAlpha),
                    blurRadius: active ? 36 : 18,
                    spreadRadius: active ? 8 : 2,
                    offset: Offset(isRight ? -4 : 4, 0),
                  ),
                  if (active)
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: isRight ? const Radius.circular(34) : Radius.zero,
                  right: !isRight ? const Radius.circular(34) : Radius.zero,
                ),
                child: BackdropFilter(
                  filter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.1),
                    BlendMode.srcOver,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner ripple light
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: isRight ? Alignment.centerRight : Alignment.centerLeft,
                              radius: 1.2,
                              colors: [
                                Colors.white.withValues(alpha: active ? 0.35 : 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Content Column
                      Padding(
                        padding: EdgeInsets.only(
                          left: isRight ? 10 : 4,
                          right: isRight ? 4 : 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Arrow Indicator
                            Transform.scale(
                              scale: active ? 1.2 : pulseScale,
                              child: Icon(
                                isRight ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: active ? 22 : 16,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Device Icon
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Icon(
                                _getDeviceIcon(widget.device.deviceType),
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Rotated Name
                            Flexible(
                              child: RotatedBox(
                                quarterTurns: isRight ? 3 : 1,
                                child: Text(
                                  widget.device.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: active ? 1.0 : 0.85),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'windows':
      case 'macos':
      case 'linux':
        return Icons.laptop_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.smartphone_rounded;
    }
  }
}
