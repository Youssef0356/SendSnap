import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/pulsing_dot.dart';
import '../services/permission_service.dart';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/connection_provider.dart';

/// S1 — Splash Screen
/// Brand first impression. Shows logo + tagline while initializing services.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();

    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Run background initialization
    await Future.wait([
      _initPermissions(),
      _initServices(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _initPermissions() async {
    final permissionService = PermissionService();
    await permissionService.requestAllPermissions();
  }

  Future<void> _initServices() async {
    try {
      // Small delay to ensure connectivity_plus completes its first read
      await Future.delayed(const Duration(milliseconds: 300));
      
      final mode = ref.read(connectionModeProvider);
      final deviceName = ref.read(deviceNameProvider);

      if (mode == ConnectionMode.wifi) {
        // Start TCP server & mDNS broadcast
        final transferService = ref.read(transferServiceProvider);
        final port = await transferService.startServer();
        final discoveryService = ref.read(discoveryServiceProvider);
        await discoveryService.startBroadcast(deviceName, port);
        await discoveryService.startDiscovery();
      } else {
        // Start Nearby Connections
        final offlineService = ref.read(offlineConnectionServiceProvider);
        await offlineService.startBroadcast(deviceName);
        await offlineService.startDiscovery();
      }

      // Update broadcast status
      ref.read(broadcastStatusProvider.notifier).state = true;
    } catch (e) {
      debugPrint('[SendSnap] Init error: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      body: Center(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo icon
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            SendSnapTheme.primary,
                            SendSnapTheme.highlight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: SendSnapTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App name
                    const Text(
                      'SendSnap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tagline
                    Text(
                      'SNAP IT.  SEND IT.  DONE.',
                      style: TextStyle(
                        color: SendSnapTheme.accent.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Pulsing dots
                    const PulsingDots(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
