import 'dart:math';
import 'package:flutter/material.dart';
import '../config/constants.dart';

class RadarWidget extends StatefulWidget {
  final bool active;
  final String label;

  const RadarWidget({
    super.key,
    required this.active,
    this.label = 'Searching...',
  });

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(RadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Isolate all 60 FPS radar animations within its own RepaintBoundary
        RepaintBoundary(
          child: SizedBox(
            height: 220,
            width: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fast GPU Canvas for ripple waves and sweep beam
                if (widget.active)
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: _RadarCanvasPainter(animation: _controller),
                  ),

                // Center Core Orb
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.wifi_tethering_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.m),

        // Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ultra-lightweight Skia/Impeller hardware canvas painter for radar ripples & beam.
/// Zero widget allocation per frame.
class _RadarCanvasPainter extends CustomPainter {
  final Animation<double> animation;

  _RadarCanvasPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final val = animation.value;

    // 1. Paint 3 concentric ripple waves
    for (int i = 0; i < 3; i++) {
      final progress = (val + (i * 0.33)) % 1.0;
      final curve = Curves.easeOutCubic.transform(progress);
      final radius = 35 + (curve * (maxRadius - 35));
      final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

      final wavePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawCircle(center, radius, wavePaint);
    }

    // 2. Paint rotating sweep beam
    final sweepAngle = val * 2 * pi;
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius - 10);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * pi,
        transform: GradientRotation(sweepAngle),
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.0),
          AppColors.primary.withValues(alpha: 0.16),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(sweepRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius - 10, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarCanvasPainter oldDelegate) => false;
}
