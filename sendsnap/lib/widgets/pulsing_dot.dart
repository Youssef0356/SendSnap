import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated pulsing dots indicator (3 dots, one pulsing at a time).
/// Used on the splash screen to show loading progress.
class PulsingDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double spacing;

  const PulsingDots({
    super.key,
    this.color = SendSnapTheme.highlight,
    this.dotSize = 8,
    this.spacing = 6,
  });

  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Each dot pulses at a different phase
            final phase = (_controller.value + index * 0.33) % 1.0;
            final scale = 0.5 + 0.5 * _pulse(phase);
            final opacity = 0.3 + 0.7 * _pulse(phase);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: opacity * 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _pulse(double t) {
    // Smooth pulse curve: peaks at 0.5, low at 0 and 1
    return (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
  }
}
