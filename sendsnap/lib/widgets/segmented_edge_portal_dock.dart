import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/device.dart';

/// An ethereal, borderless edge portal dock that uses a feathered gradient aura.
/// Replaces boxy cards and harsh borders with an organic ambient light bleed
/// and elegant light typography along the bezel.
class SegmentedEdgePortalDock extends StatefulWidget {
  final List<NearbyDevice> devices;
  final void Function(NearbyDevice target, List<File> files) onFileDropped;
  final void Function(NearbyDevice? target, double penetration, double normalizedY)? onHoverChanged;

  const SegmentedEdgePortalDock({
    super.key,
    required this.devices,
    required this.onFileDropped,
    this.onHoverChanged,
  });

  @override
  State<SegmentedEdgePortalDock> createState() => _SegmentedEdgePortalDockState();
}

class _SegmentedEdgePortalDockState extends State<SegmentedEdgePortalDock>
    with SingleTickerProviderStateMixin {
  String? _hoveredDeviceId;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
    if (widget.devices.isEmpty) return const SizedBox.shrink();

    final displayDevices = widget.devices.take(4).toList();

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: displayDevices.map((device) {
          final isHovered = _hoveredDeviceId == device.id;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildFeatheredPortal(device, isHovered, displayDevices.length),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatheredPortal(NearbyDevice device, bool isHovered, int totalCount) {
    final double portalHeight = totalCount == 1
        ? 200.0
        : totalCount == 2
            ? 140.0
            : totalCount == 3
                ? 110.0
                : 90.0;

    return DragTarget<List<File>>(
      onWillAcceptWithDetails: (details) {
        if (_hoveredDeviceId != device.id) {
          setState(() => _hoveredDeviceId = device.id);
          HapticFeedback.selectionClick();
          widget.onHoverChanged?.call(device, 1.0, 0.5);
        }
        return true;
      },
      onLeave: (data) {
        if (_hoveredDeviceId == device.id) {
          setState(() => _hoveredDeviceId = null);
          widget.onHoverChanged?.call(null, 0.0, 0.0);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() => _hoveredDeviceId = null);
        HapticFeedback.heavyImpact();
        widget.onHoverChanged?.call(null, 0.0, 0.0);
        widget.onFileDropped(device, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final active = isHovered || candidateData.isNotEmpty;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final pulse = _pulseAnimation.value;
            // The feathered gradient width deepens significantly when active
            final double glowWidth = active ? 130.0 : (52.0 + (pulse * 12.0));
            final double baseAlpha = active ? 0.70 : (0.22 + (pulse * 0.16));

            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: glowWidth,
              height: portalHeight,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  // 1. Organic Feathered Gradient Bleed (No borders, dissolves into screen)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          stops: const [0.0, 0.35, 0.70, 1.0],
                          colors: [
                            (active ? AppColors.accent : AppColors.primary)
                                .withValues(alpha: baseAlpha),
                            (active ? AppColors.primary : AppColors.primary)
                                .withValues(alpha: baseAlpha * 0.65),
                            AppColors.primary.withValues(alpha: baseAlpha * 0.20),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Floating Ethereal Content with Fancy Light Typography
                  Positioned(
                    right: 12,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minimalist Floating Icon with soft glow
                        Icon(
                          _getDeviceIcon(device.deviceType),
                          color: Colors.white.withValues(alpha: active ? 1.0 : 0.85),
                          size: active ? 18 : 15,
                          shadows: [
                            Shadow(
                              color: AppColors.primary.withValues(alpha: active ? 0.8 : 0.4),
                              blurRadius: active ? 16 : 8,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Fancy Light Rotated Typography
                        RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            device.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: active ? 1.0 : 0.88),
                              fontSize: 10,
                              fontWeight: FontWeight.w300, // Elegant light font
                              letterSpacing: 2.4,          // Spaced luxury feel
                              fontFeatures: const [FontFeature.enable('smcp')],
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: active ? 0.6 : 0.2),
                                  blurRadius: active ? 12 : 6,
                                ),
                                Shadow(
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (active) ...[
                          const SizedBox(height: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 11,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
        return Icons.laptop_mac_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.smartphone_rounded;
    }
  }
}
