import 'package:flutter/material.dart';
import '../services/permission_handler.dart';
import '../services/ads_service.dart';
import '../config/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Initialize Ads
    await AdsService().initialize();

    // 2. Request Permissions
    await PermissionHandler.requestAllPermissions();

    // 3. Navigate to Home
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              'SendSnap',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppColors.primary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
