import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/role_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/banner_ad_widget.dart';
import 'incoming_screen.dart';

/// S2 — Home Screen
/// Core screen showing your device broadcasting + nearby devices list.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmulator();
    });
  }

  void _checkEmulator() {
    final devices = ref.read(nearbyDevicesProvider);
    for (final device in devices) {
      if (device.ip.startsWith('10.0.2.') || device.ip.startsWith('10.0.3.')) {
        _showEmulatorWarning();
        break;
      }
    }
  }

  void _showEmulatorWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Potential Emulator detected. Network transfers may fail due to NAT.')),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _switchRole() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    final transferService = ref.read(transferServiceProvider);
    final offlineService = ref.read(offlineConnectionServiceProvider);
    
    // Stop everything
    await discoveryService.stopDiscovery();
    await discoveryService.stopBroadcast();
    await transferService.dispose();
    await offlineService.stopDiscovery();
    await offlineService.stopBroadcast();
    
    ref.read(broadcastStatusProvider.notifier).state = false;
    ref.read(transferRoleProvider.notifier).state = TransferRole.unset;
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/role');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = ref.watch(deviceNameProvider);
    final nearbyDevices = ref.watch(nearbyDevicesProvider);
    final isBroadcasting = ref.watch(broadcastStatusProvider);
    final connectionMode = ref.watch(connectionModeProvider);
    final role = ref.watch(transferRoleProvider);

    // Listen for incoming requests
    ref.listen<dynamic>(incomingRequestProvider, (prev, next) {
      if (next != null) {
        IncomingRequestSheet.show(context, next, ref);
      }
    });

    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      appBar: AppBar(
        backgroundColor: SendSnapTheme.foundation,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SendSnapTheme.primary, SendSnapTheme.highlight],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'SendSnap',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _switchRole,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Switch Role', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: SendSnapTheme.accent.withValues(alpha: 0.8),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_rounded, size: 22),
            color: SendSnapTheme.accent.withValues(alpha: 0.7),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Mode Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: connectionMode == ConnectionMode.wifi
                ? SendSnapTheme.primary.withValues(alpha: 0.1)
                : SendSnapTheme.success.withValues(alpha: 0.1),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  connectionMode == ConnectionMode.wifi
                      ? Icons.wifi_rounded
                      : Icons.bluetooth_rounded,
                  color: connectionMode == ConnectionMode.wifi
                      ? SendSnapTheme.primary
                      : SendSnapTheme.success,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  connectionMode == ConnectionMode.wifi
                      ? 'High-Speed WiFi Mode Active'
                      : 'Offline Mode Active (Bluetooth)',
                  style: TextStyle(
                    color: connectionMode == ConnectionMode.wifi
                        ? SendSnapTheme.primary
                        : SendSnapTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 12),

          // Your device card
          DeviceCard(
            device: NearbyDevice(
              id: 'self',
              name: deviceName,
              ip: '',
              port: 0,
              status: isBroadcasting ? DeviceStatus.ready : DeviceStatus.offline,
            ),
            isMyDevice: true,
          ),

          const SizedBox(height: 24),

          // Nearby section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'NEARBY',
                  style: TextStyle(
                    color: SendSnapTheme.accent.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                if (nearbyDevices.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: SendSnapTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${nearbyDevices.length}',
                      style: const TextStyle(
                        color: SendSnapTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Device list or empty state
          Expanded(
            child: role == TransferRole.receiver
                ? _buildReceiverState(isBroadcasting)
                : nearbyDevices.isEmpty
                    ? _buildEmptyState(connectionMode)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: nearbyDevices.length,
                        itemBuilder: (context, index) {
                          final device = nearbyDevices[index];
                          return DeviceCard(
                            device: device,
                            onSend: () {
                              Navigator.pushNamed(
                                context,
                                '/pick',
                                arguments: device,
                              );
                            },
                          );
                        },
                      ),
          ),

          // AdMob banner
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ConnectionMode mode) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated pulse rings
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    _buildPulseRing(0.0),
                    _buildPulseRing(0.33),
                    _buildPulseRing(0.66),
                    // Center icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: SendSnapTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_find_rounded,
                        color: SendSnapTheme.primary.withValues(alpha: 0.7),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Waiting for nearby devices…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              mode == ConnectionMode.wifi 
                ? 'Make sure others have SendSnap open\non the same WiFi network'
                : 'Make sure others have SendSnap open\nnearby for Offline sharing',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverState(bool isBroadcasting) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SendSnapTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: SendSnapTheme.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isBroadcasting ? 'Waiting for files...' : 'Starting receiver...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Other devices can now see "${ref.watch(deviceNameProvider)}" and send files to you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRing(double delay) {
    final value = (_pulseController.value + delay) % 1.0;
    final scale = 0.4 + value * 0.6;
    final opacity = (1.0 - value).clamp(0.0, 0.4);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: SendSnapTheme.primary.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}
