import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:ui';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/permission_service.dart';
import '../config/constants.dart';
import '../models/device.dart';
import '../widgets/radar_widget.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/glass_container.dart';
import '../widgets/bouncing_card.dart';
import '../widgets/ambient_background.dart';
import '../widgets/in_app_file_picker_sheet.dart';
import '../widgets/qr_scanner_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    final devProv = Provider.of<DeviceProvider>(context);
    final transProv = Provider.of<TransferProvider>(context);

    bool isBusy = devProv.isAdvertising || devProv.isDiscovering;

    _showErrorIfNeeded(context, devProv);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(context, devProv),
                          const SizedBox(height: AppSpacing.xl),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: !isBusy
                                ? _buildReadyState(context, devProv, transProv)
                                : _buildBusyState(context, devProv, transProv),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomTransferStatus(context, transProv),
    );
  }

  Widget _buildHeader(BuildContext context, DeviceProvider devProv) {
    return GlassContainer(
      blur: 25,
      opacity: 0.70,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Image.asset('assets/icon/app_icon.png', height: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SendSnap',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  devProv.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          BouncingCard(
            onTap: () => _handleScanQr(devProv, Provider.of<TransferProvider>(context, listen: false)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          BouncingCard(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.tune_rounded, size: 20, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState(BuildContext context, DeviceProvider devProv, TransferProvider transProv) {
    return Column(
      key: const ValueKey('ready_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAppleHeroButton(
          title: 'SEND',
          subtitle: 'Share files with nearby devices',
          icon: Icons.arrow_upward_rounded,
          gradient: AppColors.sendGradient,
          shadowColor: AppColors.primary,
          onTap: () => _handleSend(context, devProv, transProv),
        ),
        const SizedBox(height: AppSpacing.l),
        _buildAppleHeroButton(
          title: 'RECEIVE',
          subtitle: 'Make your device discoverable',
          icon: Icons.arrow_downward_rounded,
          gradient: AppColors.receiveGradient,
          shadowColor: AppColors.receivePrimary,
          onTap: () => devProv.toggleAdvertising(),
        ),
        const SizedBox(height: AppSpacing.l),
        BouncingCard(
          onTap: () => Navigator.pushNamed(context, '/received_files'),
          child: GlassContainer(
            blur: 20,
            opacity: 0.70,
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            borderColor: Colors.white.withValues(alpha: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Received Files',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Browse, view, and manage your transfers',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (devProv.localIp != null)
          GlassContainer(
            blur: 15,
            opacity: 0.5,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connected: ${devProv.localIp}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAppleHeroButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return BouncingCard(
      onTap: onTap,
      scaleFactor: 0.97,
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Top highlight shimmer
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Decorative background ambient orb
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    // Glass Icon Orb
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusyState(BuildContext context, DeviceProvider devProv, TransferProvider transProv) {
    return Column(
      key: const ValueKey('busy_state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        RadarWidget(
          active: true,
          label: devProv.isAdvertising
              ? 'Ready to receive files'
              : 'Searching for nearby devices...',
        ),

        if (devProv.isDiscovering && _selectedFiles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          GlassContainer(
            blur: 16,
            opacity: 0.70,
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} selected to send',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],

        // Receiver IP Glass Card
        if (devProv.isAdvertising && devProv.localIp != null) ...[
          const SizedBox(height: AppSpacing.l),
          GlassContainer(
            blur: 20,
            opacity: 0.75,
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_tethering, size: 22, color: AppColors.success),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOCAL ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text(
                          '${devProv.localIp}:53318',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
                BouncingCard(
                  onTap: () => _showReceiverQrCode(context, devProv),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text('QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Sender Discovered Devices or Manual Connect Action
        if (devProv.isDiscovering) ...[
          const SizedBox(height: AppSpacing.l),
          if (devProv.nearbyDevices.isNotEmpty) ...[
            _buildDeviceDiscovery(context, devProv, transProv),
            const SizedBox(height: AppSpacing.m),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BouncingCard(
                onTap: () => _handleScanQr(devProv, transProv),
                child: GlassContainer(
                  blur: 16,
                  opacity: 0.75,
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Scan QR to Connect',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BouncingCard(
                onTap: () => _showManualIpDialog(context, devProv, transProv),
                child: GlassContainer(
                  blur: 16,
                  opacity: 0.75,
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text(
                        'Enter IP',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // Cancel Button Pill
        BouncingCard(
          onTap: () {
            devProv.stopAll();
            _selectedFiles = [];
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceDiscovery(BuildContext context, DeviceProvider devProv, TransferProvider transProv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'DISCOVERED DEVICES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: devProv.nearbyDevices.length,
            itemBuilder: (context, index) {
              final device = devProv.nearbyDevices[index];
              return _buildDeviceItem(context, device, devProv, transProv);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceItem(BuildContext context, NearbyDevice device, DeviceProvider devProv, TransferProvider transProv) {
    IconData deviceIcon = Icons.smartphone_rounded;
    if (device.deviceType == 'windows' || device.deviceType == 'macos' || device.deviceType == 'linux') {
      deviceIcon = Icons.laptop_rounded;
    } else if (device.deviceType == 'ios') {
      deviceIcon = Icons.phone_iphone_rounded;
    }

    return BouncingCard(
      onTap: () => _initiateTransfer(context, device, devProv, transProv),
      child: GlassContainer(
        blur: 20,
        opacity: 0.75,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(right: 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        child: SizedBox(
          width: 110,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(deviceIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                device.endpointName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                device.ip,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiverQrCode(BuildContext context, DeviceProvider devProv) {
    final ip = devProv.localIp ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Scan to Connect',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect directly to ${devProv.displayName}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 180,
                  width: 180,
                  child: QrImageView(
                    data: 'sendsnap://$ip:53318',
                    version: QrVersions.auto,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ip));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('IP address copied to clipboard!'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ip, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualIpDialog(BuildContext context, DeviceProvider devProv, TransferProvider transProv) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.90),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Colors.white, width: 1.5),
          ),
          title: const Text('Connect by IP', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the receiver IP shown on their screen:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.1.45',
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.wifi_rounded, size: 20),
                ),
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final ip = controller.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                if (ip.isNotEmpty) {
                  final found = await devProv.connectByIp(ip);
                  if (!found && mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Could not reach device at $ip'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleScanQr(DeviceProvider devProv, TransferProvider transProv) async {
    final messenger = ScaffoldMessenger.of(context);
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan QR codes.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final scannedCode = await QrScannerSheet.show(context);
    if (scannedCode == null || scannedCode.isEmpty) return;

    // Parse sendsnap://<ip>:<port> or http://<ip>:<port> or <ip>:<port>
    String host = scannedCode.trim();
    int port = 53318;
    if (host.startsWith('sendsnap://')) host = host.substring('sendsnap://'.length);
    if (host.startsWith('http://')) host = host.substring('http://'.length);
    if (host.contains(':')) {
      final parts = host.split(':');
      host = parts[0];
      port = int.tryParse(parts[1].split('/')[0]) ?? port;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Connecting to $host:$port...'), duration: const Duration(seconds: 1)),
    );

    final targetDevice = await devProv.connectAndGetDevice(host, port: port);
    if (!mounted) return;

    if (targetDevice != null) {
      if (_selectedFiles.isNotEmpty) {
        _initiateTransfer(context, targetDevice, devProv, transProv);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Connected to ${targetDevice.name}! Choose files to send.'),
            backgroundColor: AppColors.success,
          ),
        );
        _handleSend(context, devProv, transProv);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not reach device at $host:$port. Make sure both devices are on the same Wi-Fi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleSend(BuildContext context, DeviceProvider devProv, TransferProvider transProv) async {
    final selected = await InAppFilePickerSheet.show(context, allowMultiple: true);
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedFiles = selected;
      });
      devProv.toggleDiscovery();
    }
  }

  void _initiateTransfer(BuildContext context, NearbyDevice target, DeviceProvider devProv, TransferProvider transProv) async {
    if (_selectedFiles.isEmpty) return;
    
    _showConnectingSheet(context, target.endpointName);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    bool connected = await devProv.requestConnectionAndWait(target.endpointId);
    
    if (nav.canPop()) {
      nav.pop();
    }

    if (connected) {
      final filesToSend = List<File>.from(_selectedFiles);
      setState(() {
        _selectedFiles = [];
      });
      if (mounted) {
        nav.pushNamed('/transfer');
      }
      await transProv.sendFiles(target, filesToSend, devProv.nearbyService);
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to device. Make sure both devices are on the same Wi-Fi or hotspot.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConnectingSheet(BuildContext context, String deviceName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          height: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Connecting to $deviceName...',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text('Connecting over local Wi-Fi...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTransferStatus(BuildContext context, TransferProvider transProv) {
    if (transProv.activeTransfer == null) return const SizedBox.shrink();
    
    final transfer = transProv.activeTransfer!;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: GlassContainer(
          blur: 25,
          opacity: 0.85,
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: transfer.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.l),
              BouncingCard(
                onTap: () => Navigator.pushNamed(context, '/transfer'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
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
}
