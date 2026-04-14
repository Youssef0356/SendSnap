import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom styled progress bar with gradient fill and glow effect.
class SendSnapProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final bool showGlow;

  const SendSnapProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.color,
    this.backgroundColor,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? SendSnapTheme.highlight;
    final bgColor =
        backgroundColor ?? SendSnapTheme.accent.withValues(alpha: 0.1);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);

          return Stack(
            children: [
              // Filled portion
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: fillWidth,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: LinearGradient(
                    colors: [
                      barColor.withValues(alpha: 0.8),
                      barColor,
                    ],
                  ),
                  boxShadow: showGlow
                      ? [
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Large overall progress indicator with percentage, speed, and ETA.
class TransferProgressDisplay extends StatelessWidget {
  final double progress;
  final String speed;
  final String timeRemaining;

  const TransferProgressDisplay({
    super.key,
    required this.progress,
    required this.speed,
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SendSnapTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SendSnapTheme.accent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall',
                style: TextStyle(
                  color: SendSnapTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          SendSnapProgressBar(
            progress: progress,
            height: 10,
          ),
          const SizedBox(height: 14),

          // Speed + ETA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: SendSnapTheme.highlight.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    speed,
                    style: TextStyle(
                      color: SendSnapTheme.highlight.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                timeRemaining,
                style: TextStyle(
                  color: SendSnapTheme.accent.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
