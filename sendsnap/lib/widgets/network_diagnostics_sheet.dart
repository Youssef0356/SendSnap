import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../providers/device_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/bidi_helper.dart';
import 'bouncing_card.dart';

/// Modal bottom sheet presenting clear network diagnostics, connection status,
/// and actionable troubleshooting steps for new users.
class NetworkDiagnosticsSheet extends StatelessWidget {
  final DeviceProvider devProv;

  const NetworkDiagnosticsSheet({super.key, required this.devProv});

  static Future<void> show(BuildContext context, DeviceProvider devProv) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => NetworkDiagnosticsSheet(devProv: devProv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ip = devProv.localIp;
    final isConnected = ip != null && ip != '0.0.0.0' && ip.isNotEmpty;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned Handle Bar & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isConnected ? AppColors.success : AppColors.warning)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: isConnected ? AppColors.success : AppColors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.networkDiagTitle ?? 'Network Diagnostics',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              l10n?.networkDiagSubtitle ?? 'Local Wi-Fi & P2P connection status',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Connection Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected
                                ? (l10n?.networkLocalIp ?? 'Local IP Address')
                                : (l10n?.networkNotConnected ?? 'No Local Network'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isConnected)
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: ip));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('IP address copied to clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'COPY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        BidiHelper.isolate(ip),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active P2P Ports:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '53317 (UDP) • 53318 (TCP)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isConnected ? AppColors.success : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Troubleshooting Steps Section
            const Text(
              'TROUBLESHOOTING TIPS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            _buildTipItem(
              icon: Icons.wifi_find_rounded,
              title: '1. Connect to the Same Wi-Fi',
              description: 'Ensure both devices are connected to the exact same Wi-Fi router. Disable VPNs or guest networks which isolate devices.',
            ),
            const SizedBox(height: 10),

            _buildTipItem(
              icon: Icons.phone_android_rounded,
              title: '2. No Wi-Fi? Use Personal Hotspot',
              description: 'Outdoors or without a router? Turn on Personal Hotspot on one device and connect the other. SendSnap transfers at gigabit speed with zero internet data.',
            ),
            const SizedBox(height: 10),

            _buildTipItem(
              icon: Icons.qr_code_scanner_rounded,
              title: '3. Scan QR Code for Instant Connect',
              description: 'If automatic discovery is blocked by your router, tap the QR scanner to pair directly without broadcast discovery.',
            ),
            const SizedBox(height: 10),

            _buildTipItem(
              icon: Icons.laptop_chromebook_rounded,
              title: '4. Download SendSnap for PC / Mac',
              description: 'To share files with your computer, visit our official website to download the desktop application for Windows, Mac, or Linux.',
              onTap: () {
                final uri = Uri.parse(AppConstants.websiteUrl);
                launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 20),

            // Action Button
            BouncingCard(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Got It',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),
),
);
}

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(Icons.arrow_outward_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return BouncingCard(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}
