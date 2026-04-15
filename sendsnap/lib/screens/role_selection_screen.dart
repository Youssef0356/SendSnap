import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/role_provider.dart';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/connection_provider.dart';

/// S1.5 — Role Selection Screen
/// Allows user to choose between Sender and Receiver roles.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              
              // Header
              const Text(
                'What would you\nlike to do?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your role to start sharing',
                style: TextStyle(
                  color: SendSnapTheme.accent.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
              
              const Spacer(flex: 1),
              
              // Role Cards
              _buildRoleCard(
                context,
                ref,
                title: 'Send Files',
                description: 'Discover nearby devices and send photos, videos, or files.',
                icon: Icons.unarchive_rounded,
                color: SendSnapTheme.primary,
                role: TransferRole.sender,
              ),
              
              const SizedBox(height: 20),
              
              _buildRoleCard(
                context,
                ref,
                title: 'Receive Files',
                description: 'Make your device visible to others and receive files.',
                icon: Icons.downloading_rounded,
                color: SendSnapTheme.highlight,
                role: TransferRole.receiver,
              ),
              
              const Spacer(flex: 2),
              
              // Footer
              Center(
                child: Text(
                  'Connected to: ${ref.watch(connectionModeProvider) == ConnectionMode.wifi ? "WiFi" : "Offline"}',
                  style: TextStyle(
                    color: SendSnapTheme.accent.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required TransferRole role,
  }) {
    return GestureDetector(
      onTap: () async {
        ref.read(transferRoleProvider.notifier).state = role;
        await _initializeRole(ref, role);
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeRole(WidgetRef ref, TransferRole role) async {
    final deviceName = ref.read(deviceNameProvider);
    final transferService = ref.read(transferServiceProvider);
    final discoveryService = ref.read(discoveryServiceProvider);
    final mode = ref.read(connectionModeProvider);

    if (role == TransferRole.receiver) {
      if (mode == ConnectionMode.wifi) {
        final port = await transferService.startServer();
        await discoveryService.startBroadcast(deviceName, port);
      } else {
        final offlineService = ref.read(offlineConnectionServiceProvider);
        await offlineService.startBroadcast(deviceName);
      }
      ref.read(broadcastStatusProvider.notifier).state = true;
    } else {
      // Sender role: start discovery only
      if (mode == ConnectionMode.wifi) {
        await discoveryService.startDiscovery();
      } else {
        final offlineService = ref.read(offlineConnectionServiceProvider);
        await offlineService.startDiscovery();
      }
      ref.read(broadcastStatusProvider.notifier).state = false;
    }
  }
}
