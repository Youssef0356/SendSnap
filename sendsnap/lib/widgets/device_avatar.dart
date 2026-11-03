import 'package:flutter/material.dart';
import '../models/device.dart';

/// Renders a distinctive device avatar with:
/// 1. A unique, deterministic accent color ring based on the device name.
/// 2. Specific hardware silhouette icon (laptop, phone, tablet).
/// 3. A platform emblem mini-badge (Windows, Apple, Android, Linux).
class DeviceAvatar extends StatelessWidget {
  final NearbyDevice device;
  final double size;
  final bool showBadge;

  const DeviceAvatar({
    super.key,
    required this.device,
    this.size = 48,
    this.showBadge = true,
  });

  static const List<Color> _palette = [
    Color(0xFF007AFF), // iOS / Electric Blue
    Color(0xFF34C759), // Emerald Green
    Color(0xFFAF52DE), // Royal Violet
    Color(0xFFFF9500), // Amber Sunset
    Color(0xFFFF2D55), // Vibrant Coral
    Color(0xFF00C7BE), // Cyan / Teal
    Color(0xFF5856D6), // Deep Indigo
  ];

  Color get accentColor {
    if (device.name.isEmpty) return _palette[0];
    final hash = device.name.codeUnits.fold(0, (acc, c) => acc + c);
    return _palette[hash % _palette.length];
  }

  IconData get _deviceIcon {
    final type = device.deviceType.toLowerCase();
    if (type.contains('windows') || type.contains('win')) {
      return Icons.laptop_windows_rounded;
    } else if (type.contains('mac') || type.contains('osx')) {
      return Icons.laptop_mac_rounded;
    } else if (type.contains('linux')) {
      return Icons.computer_rounded;
    } else if (type.contains('ios') || type.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    } else if (type.contains('ipad')) {
      return Icons.tablet_mac_rounded;
    }
    return Icons.smartphone_rounded;
  }

  Widget _buildPlatformBadge() {
    final type = device.deviceType.toLowerCase();
    Color badgeColor;
    IconData badgeIcon;

    if (type.contains('windows') || type.contains('win')) {
      badgeColor = const Color(0xFF0078D4);
      badgeIcon = Icons.window_rounded;
    } else if (type.contains('ios') || type.contains('mac') || type.contains('apple')) {
      badgeColor = const Color(0xFF1F1F24);
      badgeIcon = Icons.apple;
    } else if (type.contains('android')) {
      badgeColor = const Color(0xFF3DDC84);
      badgeIcon = Icons.android_rounded;
    } else if (type.contains('linux')) {
      badgeColor = const Color(0xFFE95420);
      badgeIcon = Icons.terminal_rounded;
    } else {
      badgeColor = const Color(0xFF6B7280);
      badgeIcon = Icons.devices_rounded;
    }

    final double badgeSize = size * 0.40;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          badgeIcon,
          size: badgeSize * 0.60,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor;
    final iconSize = size * 0.48;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glowing Ambient Ring + Avatar Body
          Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.8),
                  ],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _deviceIcon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ),

          // OS Platform Badge in Bottom-Right
          if (showBadge)
            Positioned(
              right: -1,
              bottom: -1,
              child: _buildPlatformBadge(),
            ),
        ],
      ),
    );
  }
}
