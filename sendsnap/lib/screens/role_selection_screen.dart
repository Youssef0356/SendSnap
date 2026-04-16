import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/device_provider.dart';
import '../providers/role_provider.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('Choose Your Role', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Local WiFi — fast, reliable, secure.', style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.6), fontSize: 15)),
          const SizedBox(height: 40),
          _roleCard(title: 'Send Files', desc: 'Find devices on your WiFi and send files instantly.', icon: Icons.send_rounded, color: SendSnapTheme.primary, role: TransferRole.sender),
          const SizedBox(height: 16),
          _roleCard(title: 'Receive Files', desc: 'Become visible on the network and receive files.', icon: Icons.download_rounded, color: SendSnapTheme.highlight, role: TransferRole.receiver),
          if (_isLoading) ...[const SizedBox(height: 24), Center(child: CircularProgressIndicator(color: SendSnapTheme.primary))],
        ],
      ))),
    );
  }

  Widget _roleCard({required String title, required String desc, required IconData icon, required Color color, required TransferRole role}) {
    return GestureDetector(
      onTap: () async {
        if (_isLoading) return;
        setState(() => _isLoading = true);
        ref.read(transferRoleProvider.notifier).state = role;
        await _initRole(role);
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      },
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withValues(alpha: 0.3), width: 2)),
        child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]), child: Icon(icon, color: Colors.white, size: 30)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.3)),
          ])),
          Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Future<void> _initRole(TransferRole role) async {
    final discovery = ref.read(discoveryServiceProvider);
    final transfer = ref.read(transferServiceProvider);
    final deviceName = ref.read(deviceNameProvider);

    if (role == TransferRole.receiver) {
      // 1. Start TCP server to listen for files
      final port = await transfer.startServer();
      
      // 2. Broadcast availability via mDNS
      await discovery.startBroadcast(deviceName, port);
      
      ref.read(broadcastStatusProvider.notifier).state = true;
    } else {
      // 1. Start discovering mDNS services
      await discovery.startDiscovery();
      
      ref.read(broadcastStatusProvider.notifier).state = false;
    }
  }
}
