import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/pulsing_dot.dart';
import '../services/permission_service.dart';
import '../providers/device_provider.dart';

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
      _checkPermissions(),
      _initCoreServices(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);
  }

  Future<void> _checkPermissions() async {
    final permissionService = PermissionService();
    final granted = await permissionService.requestAllPermissions();
    if (!granted && mounted) {
      _showPermissionRequiredDialog();
    } else if (mounted) {
      Navigator.of(context).pushReplacementNamed('/role');
    }
  }

  Future<void> _initCoreServices() async {
    await ref.read(deviceNameProvider.notifier).ensureLoaded();
    // Service activation now happens in RoleSelectionScreen
  }

  void _showPermissionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SendSnapTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'SendSnap needs storage permissions to save received files and WiFi/Bluetooth permissions to discover devices.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // User will be stuck but aware
            child: const Text('I UNDERSTAND'),
          ),
          ElevatedButton(
            onPressed: () async {
              await PermissionService().openSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SendSnapTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
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
