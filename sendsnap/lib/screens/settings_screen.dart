import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/transfer_provider.dart';

/// S6 — Settings Screen
/// Device name, save location, and about section.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = ref.watch(deviceNameProvider);
    final savePath = ref.watch(savePathProvider);
    final appVersion = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      appBar: AppBar(
        backgroundColor: SendSnapTheme.foundation,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: SendSnapTheme.accent,
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // YOUR DEVICE section
          _SectionHeader(label: 'YOUR DEVICE'),
          _SettingsTile(
            icon: Icons.smartphone_rounded,
            iconColor: SendSnapTheme.primary,
            title: 'Device name',
            subtitle: deviceName,
            trailing: _EditButton(
              onTap: () => _showRenameDialog(context, ref, deviceName),
            ),
          ),

          const SizedBox(height: 24),

          // SAVE LOCATION section
          _SectionHeader(label: 'SAVE LOCATION'),
          _SettingsTile(
            icon: Icons.folder_rounded,
            iconColor: SendSnapTheme.highlight,
            title: 'Files saved to',
            subtitle: savePath,
          ),

          const SizedBox(height: 24),

          // ABOUT section
          _SectionHeader(label: 'ABOUT'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: SendSnapTheme.accent,
            title: 'Version',
            subtitle: appVersion,
          ),
          _SettingsTile(
            icon: Icons.policy_outlined,
            iconColor: SendSnapTheme.accent,
            title: 'Privacy policy',
            onTap: () => _launchUrl('https://the356company.com/privacy'),
          ),
          _SettingsTile(
            icon: Icons.star_outline_rounded,
            iconColor: SendSnapTheme.warning,
            title: 'Rate SendSnap ⭐',
            onTap: () => _launchUrl(
                'https://play.google.com/store/apps/details?id=com.the356company.sendsnap'),
          ),

          // DEVELOPER TOOLS (only in debug/profile)
          if (!kReleaseMode) ...[
            const SizedBox(height: 24),
            _SectionHeader(label: 'DEVELOPER TOOLS'),
            _SettingsTile(
              icon: Icons.bug_report_rounded,
              iconColor: SendSnapTheme.highlight,
              title: 'Simulator Mode',
              subtitle: 'Enable mock devices for testing',
              trailing: Switch(
                value: ref.watch(simulatorModeProvider),
                onChanged: (val) =>
                    ref.read(simulatorModeProvider.notifier).toggle(val),
                activeThumbColor: SendSnapTheme.primary,
              ),
            ),
            if (ref.watch(simulatorModeProvider))
              _SettingsTile(
                icon: Icons.call_received_rounded,
                iconColor: SendSnapTheme.primary,
                title: 'Trigger Mock Incoming',
                subtitle: 'Simulate a request from a peer',
                onTap: () {
                  ref
                      .read(activeTransferProvider.notifier)
                      .triggerMockIncomingRequest();
                  Navigator.pop(context); // Go back home
                },
              ),
          ],
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SendSnapTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Device name',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter device name',
            hintStyle: TextStyle(
              color: SendSnapTheme.accent.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: SendSnapTheme.foundation,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(deviceNameProvider.notifier).updateName(newName);

                // Restart broadcast with new name
                _restartBroadcast(ref, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: SendSnapTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _restartBroadcast(WidgetRef ref, String newName) async {
    try {
      final mode = ref.read(connectionModeProvider);
      
      if (mode == ConnectionMode.wifi) {
        final discovery = ref.read(discoveryServiceProvider);
        final port = discovery.broadcastPort;
        await discovery.stopBroadcast();
        await discovery.startBroadcast(newName, port);
      } else {
        final offline = ref.read(offlineConnectionServiceProvider);
        await offline.stopBroadcast();
        await offline.startBroadcast(newName);
      }
    } catch (e) {
      debugPrint('[SendSnap] Failed to restart broadcast: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Text(
        label,
        style: TextStyle(
          color: SendSnapTheme.accent.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SendSnapTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: SendSnapTheme.accent.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: SendSnapTheme.accent.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (onTap != null && trailing == null)
              Icon(
                Icons.chevron_right_rounded,
                color: SendSnapTheme.accent.withValues(alpha: 0.3),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: SendSnapTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Edit',
          style: TextStyle(
            color: SendSnapTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
