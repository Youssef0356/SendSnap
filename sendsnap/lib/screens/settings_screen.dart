import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../config/constants.dart';

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
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DISPLAY NAME', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      onChanged: (val) => devProv.updateDisplayName(val),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const Text('SendSnap v2.0', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
