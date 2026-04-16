import 'dart:math';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';

/// Animated radar that shows a scanning sweep and discovered device blips.
class RadarWidget extends StatefulWidget {
  final List<NearbyDevice> devices;
  final void Function(NearbyDevice)? onDeviceTap;

  const RadarWidget({super.key, required this.devices, this.onDeviceTap});

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(280, 280),
          painter: _RadarPainter(
            sweepAngle: _ctrl.value * 2 * pi,
            devices: widget.devices,
            onDeviceTap: widget.onDeviceTap,
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<NearbyDevice> devices;
  final void Function(NearbyDevice)? onDeviceTap;

  _RadarPainter({required this.sweepAngle, required this.devices, this.onDeviceTap});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2 - 20;

    // Background circles
    final ringPaint = Paint()
      ..color = SendSnapTheme.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(cx, cy), maxR * i / 3, ringPaint);
    }

    // Cross lines
    final linePaint = Paint()
      ..color = SendSnapTheme.accent.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), linePaint);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), linePaint);

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        colors: [
          SendSnapTheme.primary.withValues(alpha: 0.0),
          SendSnapTheme.primary.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
    canvas.drawCircle(Offset(cx, cy), maxR, sweepPaint..style = PaintingStyle.fill);

    // Sweep line
    final sweepLinePaint = Paint()
      ..color = SendSnapTheme.primary.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + maxR * cos(sweepAngle), cy + maxR * sin(sweepAngle)),
      sweepLinePaint,
    );

    // Center dot
    final centerPaint = Paint()..color = SendSnapTheme.primary;
    canvas.drawCircle(Offset(cx, cy), 5, centerPaint);

    // Device blips
    for (int i = 0; i < devices.length; i++) {
      final d = devices[i];
      // Distribute devices around the radar at different angles/radii
      final angle = (i * 2.4) + 0.8; // golden-angle-ish spacing
      final radius = maxR * (0.35 + (i % 3) * 0.22);
      final dx = cx + radius * cos(angle);
      final dy = cy + radius * sin(angle);

      // Glow
      final glowPaint = Paint()
        ..color = SendSnapTheme.highlight.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(dx, dy), 12, glowPaint);

      // Dot
      final dotPaint = Paint()..color = SendSnapTheme.highlight;
      canvas.drawCircle(Offset(dx, dy), 6, dotPaint);

      // Ring
      final ringP = Paint()
        ..color = SendSnapTheme.highlight.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(dx, dy), 10, ringP);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      sweepAngle != old.sweepAngle || devices != old.devices;
}
