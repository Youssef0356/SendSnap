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
      duration: const Duration(seconds: 3),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final animation = CurvedAnimation(
                        parent: _controller,
                        curve: Interval(index / 3, 1.0, curve: Curves.easeOut),
                      );
                      final progress = animation.value;
                      if (progress == 0) return const SizedBox.shrink();

                      return Container(
                        width: 80 + (progress * 180),
                        height: 80 + (progress * 180),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity((1.0 - progress) * 0.5),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary, blurRadius: 20, spreadRadius: -5),
                  ],
                ),
                child: const Icon(Icons.radar_rounded, color: Colors.white, size: 40),
              ),
            ],
          ),
          if (widget.active) ...[
            const SizedBox(height: AppSpacing.l),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
