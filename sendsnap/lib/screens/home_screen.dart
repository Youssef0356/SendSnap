import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/role_provider.dart';
import '../widgets/radar_widget.dart';
import '../widgets/banner_ad_widget.dart';
import 'incoming_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenIncoming());
  }

  void _listenIncoming() {
    ref.listen<IncomingRequest?>(incomingRequestProvider, (prev, next) {
      if (next != null && mounted) IncomingRequestSheet.show(context, next, ref);
    });
  }

  Future<void> _switchRole() async {
    final discovery = ref.read(discoveryServiceProvider);
    final transfer = ref.read(transferServiceProvider);
    
    await discovery.dispose();
    await transfer.dispose();
    
    ref.read(broadcastStatusProvider.notifier).state = false;
    ref.read(transferRoleProvider.notifier).state = TransferRole.unset;
    if (mounted) Navigator.of(context).pushReplacementNamed('/role');
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = ref.watch(deviceNameProvider);
    final nearby = ref.watch(nearbyDevicesProvider);
    final isBroadcasting = ref.watch(broadcastStatusProvider);
    final role = ref.watch(transferRoleProvider);

    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      appBar: AppBar(
        backgroundColor: SendSnapTheme.foundation,
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(gradient: const LinearGradient(colors: [SendSnapTheme.primary, SendSnapTheme.highlight]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Text('SendSnap', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
        ]),
        actions: [
          TextButton.icon(onPressed: _switchRole, icon: const Icon(Icons.sync_rounded, size: 18), label: const Text('Switch Role', style: TextStyle(fontSize: 12)), style: TextButton.styleFrom(foregroundColor: SendSnapTheme.accent.withValues(alpha: 0.8))),
          IconButton(onPressed: () => Navigator.pushNamed(context, '/settings'), icon: const Icon(Icons.settings_rounded, size: 22), color: SendSnapTheme.accent.withValues(alpha: 0.7)),
        ],
      ),
      body: Column(children: [
        // Mode banner
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: SendSnapTheme.primary.withValues(alpha: 0.1),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_rounded, color: SendSnapTheme.primary, size: 16),
            const SizedBox(width: 8),
            Text(role == TransferRole.receiver ? 'Receiving — Local WiFi Mode Active' : 'Scanning — Local WiFi Mode Active', style: TextStyle(color: SendSnapTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]))),
        const SizedBox(height: 16),

        // Radar
        Center(child: RadarWidget(devices: nearby, onDeviceTap: (d) {
          if (role == TransferRole.sender) Navigator.pushNamed(context, '/pick', arguments: d);
        })),
        const SizedBox(height: 8),

        // Device name
        Text(deviceName, style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),

        // Status
        if (role == TransferRole.receiver)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isBroadcasting ? Icons.check_circle : Icons.hourglass_top, color: isBroadcasting ? SendSnapTheme.success : Colors.orange, size: 16),
            const SizedBox(width: 6),
            Text(isBroadcasting ? 'Ready to receive' : 'Setting up...', style: TextStyle(color: isBroadcasting ? SendSnapTheme.success : Colors.orange, fontSize: 12)),
          ]),

        const SizedBox(height: 16),

        // Nearby count + list
        if (nearby.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            Text('DETECTED', style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: SendSnapTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Text('${nearby.length}', style: const TextStyle(color: SendSnapTheme.primary, fontSize: 11, fontWeight: FontWeight.w700))),
          ])),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(padding: const EdgeInsets.only(bottom: 80), itemCount: nearby.length, itemBuilder: (_, i) {
            final d = nearby[i];
            return ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: SendSnapTheme.highlight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.phone_android_rounded, color: SendSnapTheme.highlight, size: 20)),
              title: Text(d.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(d.id.length > 12 ? d.id.substring(0, 12) : d.id, style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.5), fontSize: 11)),
              trailing: role == TransferRole.sender ? IconButton(icon: Icon(Icons.send_rounded, color: SendSnapTheme.primary), onPressed: () => Navigator.pushNamed(context, '/pick', arguments: d)) : null,
            );
          })),
        ] else
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.radar_rounded, size: 48, color: SendSnapTheme.accent.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Scanning for devices...', style: TextStyle(color: SendSnapTheme.accent.withValues(alpha: 0.5), fontSize: 14)),
          ]))),

        const BannerAdWidget(),
      ]),
    );
  }
}
