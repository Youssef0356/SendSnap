import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/permission_service.dart';
import '../config/constants.dart';
import '../models/device.dart';
import '../widgets/radar_widget.dart';
import '../widgets/banner_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedFile;

  @override
  Widget build(BuildContext context) {
    final devProv = Provider.of<DeviceProvider>(context);
    final transProv = Provider.of<TransferProvider>(context);

    bool isBusy = devProv.isAdvertising || devProv.isDiscovering;

    // Show error snackbar if there's a permission/discovery error
    _showErrorIfNeeded(context, devProv);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, devProv),
                    const SizedBox(height: AppSpacing.xxl),
                    
                    SizedBox(
                      height: 420,
                      child: Stack(
                        children: [
                          // READY STATE (Buttons)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: isBusy ? 0 : 1,
                            child: IgnorePointer(
                              ignoring: isBusy,
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
                          ),

                          // BUSY STATE (Radar + Discovery)
                          if (isBusy)
                            Positioned.fill(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RadarWidget(
                                    active: true,
                                    label: devProv.isAdvertising ? 'Waiting for sender...' : 'Searching for devices...',
                                  ),
                                  if (devProv.isDiscovering && devProv.nearbyDevices.isNotEmpty)
                                    _buildDeviceDiscovery(context, devProv, transProv),

                                  const SizedBox(height: AppSpacing.l),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        devProv.stopAll();
                                        _selectedFile = null;
                                      },
                                      icon: const Icon(Icons.close),
                                      label: const Text('Cancel'),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomTransferStatus(context, transProv),
    );
  }

  void _showErrorIfNeeded(BuildContext context, DeviceProvider devProv) {
    if (devProv.lastError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && devProv.lastError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(devProv.lastError!),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'SETTINGS',
                textColor: Colors.white,
                onPressed: () {
                  devProv.clearError();
                  // Open app settings so user can grant permissions
                  PermissionService().openSettings();
                },
              ),
            ),
          );
          devProv.clearError();
        }
      });
    }
  }

  Widget _buildHeader(BuildContext context, DeviceProvider devProv) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Image.asset('assets/icon/app_icon.png', height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SendSnap', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(
                      devProv.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? (activeText ?? title) : title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isActive ? Colors.white : color,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isActive ? 'Tap to stop' : subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isActive ? Colors.white.withOpacity(0.8) : color.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
      height: 160,
      margin: const EdgeInsets.only(top: AppSpacing.l),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DISCOVERED DEVICES', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
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
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              device.endpointName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend(BuildContext context, DeviceProvider devProv, TransferProvider transProv) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFile = file;
      });
      devProv.toggleDiscovery();
    }
  }

  void _initiateTransfer(BuildContext context, NearbyDevice target, DeviceProvider devProv, TransferProvider transProv) async {
    if (_selectedFile == null) return;
    
    _showConnectingSheet(context, target.endpointName);

    // Request connection and wait for full handshake
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool connected = await devProv.requestConnectionAndWait(target.endpointId);
    
    if (connected) {
       await transProv.sendFile(target.endpointId, _selectedFile!, devProv.nearbyService);
       if (mounted) {
         Navigator.pushNamed(context, '/transfer');
       }
       setState(() {
         _selectedFile = null;
       });
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to device. Make sure the other device is in Receive mode.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConnectingSheet(BuildContext context, String deviceName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        height: 250,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.xl),
            Text('Connecting to $deviceName...', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            const Text('Keep both devices nearby', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTransferStatus(BuildContext context, TransferProvider transProv) {
    if (transProv.activeTransfer == null) return const SizedBox.shrink();
    
    final transfer = transProv.activeTransfer!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transfer.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: transfer.progress, backgroundColor: AppColors.primary.withOpacity(0.1)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.l),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/transfer'),
              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
