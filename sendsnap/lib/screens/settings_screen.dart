import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../config/constants.dart';
import '../widgets/glass_container.dart';
import '../widgets/ambient_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final devProv = Provider.of<DeviceProvider>(context, listen: false);
    _controller = TextEditingController(text: devProv.displayName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devProv = Provider.of<DeviceProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        centerTitle: true,
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                GlassContainer(
                  blur: 25,
                  opacity: 0.75,
                  borderRadius: 28,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEVICE DISPLAY NAME',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Enter your device name',
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.devices_rounded, size: 20),
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        onChanged: (val) => devProv.updateDisplayName(val),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('SendSnap v2.1 (Apple Edition)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
