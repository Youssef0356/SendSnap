import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../config/constants.dart';
import '../models/device.dart';
import '../services/file_handler.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final devProv = Provider.of<DeviceProvider>(context);
    final transProv = Provider.of<TransferProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, devProv),
              const SizedBox(height: AppSpacing.xxl),
              
              // Actions Area (Minimalist & Fast)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      context: context,
                      title: 'SEND',
                      subtitle: 'Choose files to share',
                      icon: Icons.upload_file_rounded,
                      color: AppColors.primary,
                      onTap: () => _handleSend(context, devProv, transProv),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _buildActionButton(
                      context: context,
                      title: 'RECEIVE',
                      subtitle: 'Wait for incoming files',
                      icon: Icons.download_for_offline_rounded,
                      color: AppColors.success,
                      onTap: () => devProv.toggleAdvertising(),
                      isActive: devProv.isAdvertising,
                      activeText: 'LISTENING...',
                    ),
                  ],
                ),
              ),

              if (devProv.isDiscovering && devProv.nearbyDevices.isNotEmpty)
                _buildDeviceDiscovery(context, devProv, transProv),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomTransferStatus(context, transProv),
    );
  }

  Widget _buildHeader(BuildContext context, DeviceProvider devProv) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SendSnap', style: Theme.of(context).textTheme.displayLarge),
            Text(
              devProv.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
    String? activeText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(32),
          boxShadow: isActive ? [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isActive ? Colors.white : color, size: 32),
            ),
            const SizedBox(width: AppSpacing.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? (activeText ?? title) : title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isActive ? Colors.white : color,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  isActive ? 'Tap to stop' : subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive ? Colors.white.withOpacity(0.8) : color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              isActive ? Icons.close : Icons.chevron_right_rounded,
              color: isActive ? Colors.white : color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDiscovery(BuildContext context, DeviceProvider devProv, TransferProvider transProv) {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: AppSpacing.l),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Searching for devices...', style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              TextButton(onPressed: () => devProv.stopAll(), child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: devProv.nearbyDevices.length,
              itemBuilder: (context, index) {
                final device = devProv.nearbyDevices[index];
                return _buildDeviceItem(context, device, devProv, transProv);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, NearbyDevice device, DeviceProvider devProv, TransferProvider transProv) {
    return GestureDetector(
      onTap: () => _initiateTransfer(context, device, devProv, transProv),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              device.endpointName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomTransferStatus(BuildContext context, TransferProvider transProv) {
    if (transProv.activeTransfer == null) return null;
    
    final t = transProv.activeTransfer!;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/transfer'),
      child: Container(
        height: 70,
        margin: const EdgeInsets.all(AppSpacing.m),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sending ${t.fileName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  LinearProgressIndicator(value: t.progress, backgroundColor: Colors.white24, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${(t.progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend(BuildContext context, DeviceProvider devProv, TransferProvider transProv) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null) {
      File file = File(result.files.single.path!);
      
      // Start discovery to find a device to send to
      await devProv.toggleDiscovery();
      
      // We'll store the picked file temporarily or just pass it once a device is selected
      // For speed, let's assume the next device tap will use this file
      _selectedFile = file;
    }
  }

  static File? _selectedFile;

  Future<void> _initiateTransfer(BuildContext context, NearbyDevice target, DeviceProvider devProv, TransferProvider transProv) async {
    if (_selectedFile == null) return;
    
    // Request connection
    bool connected = await devProv.nearbyService.requestConnection(devProv.displayName, target.endpointId);
    if (connected) {
       // TransferProvider handles sending metadata then file
       await transProv.sendFile(target.endpointId, _selectedFile!, devProv.nearbyService);
       Navigator.pushNamed(context, '/transfer');
       _selectedFile = null;
    }
  }
}
