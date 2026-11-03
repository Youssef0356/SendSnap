import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/device.dart';
import 'device_avatar.dart';

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
          return _buildFeatheredPortal(device, isHovered, displayDevices.length);
        }).toList(),
      ),
    );
  }

  Widget _buildFeatheredPortal(NearbyDevice device, bool isHovered, int totalCount) {
    final double portalHeight = totalCount == 1
        ? 280.0
        : totalCount == 2
            ? 180.0
            : totalCount == 3
                ? 130.0
                : 105.0;

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
            // The feathered gradient width deepens significantly and reaches inward when active
            final double glowWidth = active ? 200.0 : (72.0 + (pulse * 14.0));
            final double baseAlpha = active ? 0.75 : (0.22 + (pulse * 0.16));

            final devColor = DeviceAvatar(device: device).accentColor;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: glowWidth,
              height: portalHeight,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  // 1. Organic Feathered Gaussian Aura Bleed (Completely dissolved in all directions, no hard lines or cutoffs)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FeatheredEdgeAuraPainter(
                        color: devColor,
                        alpha: baseAlpha,
                        active: active,
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
    final t = type.toLowerCase();
    if (t.contains('windows')) return Icons.laptop_windows_rounded;
    if (t.contains('mac') || t.contains('ios') || t.contains('apple')) return Icons.apple;
    if (t.contains('linux')) return Icons.terminal_rounded;
    if (t.contains('android')) return Icons.android_rounded;
    return Icons.smartphone_rounded;
  }
}

/// Paints an organic, continuous Gaussian aura that bleeds in all directions
/// with true exponential decay and absolutely zero hard rectangular lines or edge limits.
class _FeatheredEdgeAuraPainter extends CustomPainter {
  final Color color;
  final double alpha;
  final bool active;

  _FeatheredEdgeAuraPainter({
    required this.color,
    required this.alpha,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Broad atmospheric outer Gaussian aura (smoothly dissipates in all directions)
    final outerBlur = active ? 46.0 : 28.0;
    final outerPaint = Paint()
      ..color = color.withValues(alpha: alpha * (active ? 0.70 : 0.45))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, outerBlur);

    final outerOval = Rect.fromCenter(
      center: Offset(w, h / 2),
      width: w * 2.0,
      height: h * 0.92,
    );
    canvas.drawOval(outerOval, outerPaint);

    // 2. Focused inner core glow along the bezel
    final innerBlur = active ? 22.0 : 14.0;
    final innerPaint = Paint()
      ..color = color.withValues(alpha: alpha * (active ? 0.90 : 0.60))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, innerBlur);

    final innerOval = Rect.fromCenter(
      center: Offset(w, h / 2),
      width: w * 1.25,
      height: h * 0.65,
    );
    canvas.drawOval(innerOval, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _FeatheredEdgeAuraPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.alpha != alpha ||
      oldDelegate.active != active;
}
