import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';

/// Card displaying a nearby device with avatar, name, status, and action button.
class DeviceCard extends StatelessWidget {
  final NearbyDevice device;
  final VoidCallback? onSend;
  final bool isMyDevice;

  const DeviceCard({
    super.key,
    required this.device,
    this.onSend,
    this.isMyDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isMyDevice
            ? SendSnapTheme.highlight.withValues(alpha: 0.12)
            : SendSnapTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyDevice
              ? SendSnapTheme.highlight.withValues(alpha: 0.3)
              : SendSnapTheme.accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(),
            const SizedBox(width: 14),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isMyDevice) ...[
                        const _PulsingDot(color: SendSnapTheme.success),
                        const SizedBox(width: 6),
                        Text(
                          'broadcasting',
                          style: TextStyle(
                            color: SendSnapTheme.success.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _statusColor(device.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusText(device.status),
                          style: TextStyle(
                            color: SendSnapTheme.accent.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action
            if (!isMyDevice && onSend != null)
              ElevatedButton(
                onPressed: onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SendSnapTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Send',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = device.name.isNotEmpty
        ? device.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '??';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isMyDevice
            ? SendSnapTheme.highlight.withValues(alpha: 0.25)
            : SendSnapTheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: isMyDevice ? SendSnapTheme.highlight : SendSnapTheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _statusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.ready:
        return SendSnapTheme.success;
      case DeviceStatus.busy:
        return SendSnapTheme.warning;
      case DeviceStatus.offline:
        return SendSnapTheme.error;
    }
  }

  String _statusText(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.ready:
        return 'ready to receive';
      case DeviceStatus.busy:
        return 'busy';
      case DeviceStatus.offline:
        return 'offline';
    }
  }
}

/// Small pulsing dot animation for broadcasting status.
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
