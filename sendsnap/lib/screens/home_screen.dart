import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
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
import '../widgets/segmented_edge_portal_dock.dart';
import '../widgets/draggable_file_token.dart';
import '../widgets/portal_ghost_card.dart';
import '../widgets/network_status_pill.dart';
import '../widgets/network_diagnostics_sheet.dart';
import '../widgets/device_avatar.dart';
import '../services/portal_stream_client.dart';
import '../services/file_handler.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

class HomeScreen extends StatefulWidget {
  final List<File>? initialFiles;
  const HomeScreen({super.key, this.initialFiles});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _selectedFiles = [];
  String _incomingGhostFileName = '';
  double _incomingGhostPenetration = 0.0;
  double _incomingGhostY = 0.5;
  NearbyDevice? _activeHoveredDevice;
  bool _isDesktopDragging = false;
  final PortalStreamClient _portalClient = PortalStreamClient();
  Timer? _discoveryTimer;
  bool _showDiscoveryTroubleshooter = false;
  bool _showEdgePortalHint = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      _selectedFiles = List.from(widget.initialFiles!);
    }
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _showEdgePortalHint = !(prefs.getBool('has_used_edge_portal') ?? false);
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final devProv = Provider.of<DeviceProvider>(context, listen: false);
      devProv.onPortalEvent = _handleIncomingPortalEvent;
      if (_selectedFiles.isNotEmpty && !devProv.isDiscovering) {
        devProv.toggleDiscovery();
      }
      if (Platform.isAndroid) {
        _checkAndroidSharedFiles();
      }
    });
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _portalClient.disconnect();
    super.dispose();
  }

  void _handleIncomingPortalEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type'];
    if (type == 'DRAG_MOVE') {
      setState(() {
        _incomingGhostFileName = (event['fileName'] as String?) ?? '';
        _incomingGhostPenetration = (event['penetration'] as num?)?.toDouble() ?? 0.0;
        _incomingGhostY = (event['y'] as num?)?.toDouble() ?? 0.5;
      });
    } else if (type == 'DRAG_CANCEL') {
      setState(() {
        _incomingGhostFileName = '';
        _incomingGhostPenetration = 0.0;
      });
    } else if (type == 'DRAG_DROP') {
      HapticFeedback.heavyImpact();
      setState(() {
        _incomingGhostPenetration = 1.0;
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _incomingGhostFileName = '';
            _incomingGhostPenetration = 0.0;
          });
        }
      });
    }
  }

  void _onDragUpdate(Offset globalPos, Size screenSize, {String? fileName}) {
    if (_activeHoveredDevice == null || _selectedFiles.isEmpty) return;
    final threshold = screenSize.width - 150.0;
    final name = fileName ?? (_selectedFiles.isNotEmpty ? p.basename(_selectedFiles.first.path) : '');
    if (globalPos.dx >= threshold) {
      final penetration = ((globalPos.dx - threshold) / 150.0).clamp(0.0, 1.0);
      final normalizedY = (globalPos.dy / screenSize.height).clamp(0.0, 1.0);
      _portalClient.sendDragMove(
        fileName: name,
        penetration: penetration,
        normalizedY: normalizedY,
      );
    } else {
      _portalClient.sendDragCancel();
    }
  }

  static const MethodChannel _androidChannel = MethodChannel('com.the356company.sendsnap/file_utils');

  void _checkAndroidSharedFiles() async {
    try {
      _androidChannel.setMethodCallHandler((call) async {
        if (call.method == 'onFilesShared') {
          final List<dynamic>? paths = call.arguments as List<dynamic>?;
          if (paths != null && paths.isNotEmpty) {
            final files = paths
                .map((p) => File(p.toString()))
                .where((f) => f.existsSync())
                .toList();
            if (files.isNotEmpty && mounted) {
              setState(() {
                _selectedFiles = files;
              });
              final devProv = Provider.of<DeviceProvider>(context, listen: false);
              if (!devProv.isDiscovering) {
                devProv.toggleDiscovery();
              }
            }
          }
        }
      });

      final List<dynamic>? initialPaths =
          await _androidChannel.invokeMethod<List<dynamic>>('getInitialSharedFiles');
      if (initialPaths != null && initialPaths.isNotEmpty) {
        final files = initialPaths
            .map((p) => File(p.toString()))
            .where((f) => f.existsSync())
            .toList();
        if (files.isNotEmpty && mounted) {
          setState(() {
            _selectedFiles = files;
          });
          final devProv = Provider.of<DeviceProvider>(context, listen: false);
          if (!devProv.isDiscovering) {
            devProv.toggleDiscovery();
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final devProv = Provider.of<DeviceProvider>(context);
    final transProv = Provider.of<TransferProvider>(context);

    bool isBusy = devProv.isAdvertising || devProv.isDiscovering;

    // Manage zero-device discovery timer for troubleshooting guidance
    if (devProv.isDiscovering) {
      if (devProv.nearbyDevices.isNotEmpty) {
        _discoveryTimer?.cancel();
        _discoveryTimer = null;
        if (_showDiscoveryTroubleshooter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showDiscoveryTroubleshooter = false);
          });
        }
      } else if (_discoveryTimer == null && !_showDiscoveryTroubleshooter) {
        _discoveryTimer = Timer(const Duration(seconds: 7), () {
          if (mounted && devProv.isDiscovering && devProv.nearbyDevices.isEmpty) {
            setState(() {
              _showDiscoveryTroubleshooter = true;
            });
          }
        });
      }
    } else {
      _discoveryTimer?.cancel();
      _discoveryTimer = null;
      if (_showDiscoveryTroubleshooter) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showDiscoveryTroubleshooter = false);
        });
      }
    }

    _showErrorIfNeeded(context, devProv);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          _handleSend(this.context, devProv, transProv);
        },
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () {
          _handleSend(this.context, devProv, transProv);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (isBusy) {
            devProv.stopAll();
            setState(() => _selectedFiles = []);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: DropTarget(
          onDragEntered: (detail) => setState(() => _isDesktopDragging = true),
          onDragExited: (detail) => setState(() => _isDesktopDragging = false),
          onDragDone: (detail) {
            setState(() {
              _isDesktopDragging = false;
              _selectedFiles = detail.files.map((x) => File(x.path)).toList();
            });
            if (_selectedFiles.isNotEmpty && !devProv.isDiscovering) {
              devProv.toggleDiscovery();
            }
          },
          child: Stack(
            children: [
              SafeArea(
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

            // Segmented Edge Portal Dock for Discovered Devices (Option B)
            if (devProv.isDiscovering && devProv.nearbyDevices.isNotEmpty)
              SegmentedEdgePortalDock(
                devices: devProv.nearbyDevices,
                onHoverChanged: (target, penetration, y) {
                  if (target != _activeHoveredDevice) {
                    if (_activeHoveredDevice != null) {
                      _portalClient.sendDragCancel();
                    }
                    _activeHoveredDevice = target;
                  }
                  if (target != null && _selectedFiles.isNotEmpty) {
                    _portalClient.connect(target.ip, port: target.port);
                    _portalClient.sendDragMove(
                      fileName: p.basename(_selectedFiles.first.path),
                      penetration: penetration,
                      normalizedY: y,
                    );
                  }
                },
                onFileDropped: (target, files) {
                  if (files.isNotEmpty) {
                    _portalClient.sendDragDrop(fileName: p.basename(files.first.path));
                  }
                  _activeHoveredDevice = null;
                  if (_showEdgePortalHint) {
                    setState(() => _showEdgePortalHint = false);
                  }
                  SharedPreferences.getInstance().then(
                    (prefs) => prefs.setBool('has_used_edge_portal', true),
                  );
                  _initiateTransfer(context, target, devProv, transProv, files: files);
                },
              ),

            // Incoming Portal Ghost Card for Receiver Mode
            PortalGhostCard(
              isVisible: devProv.isAdvertising && _incomingGhostFileName.isNotEmpty,
              fileName: _incomingGhostFileName,
              penetration: _incomingGhostPenetration,
              normalizedY: _incomingGhostY,
              isLeftEdge: true,
            ),

            // Desktop Drag & Drop Visual Overlay
            if (_isDesktopDragging)
              Positioned.fill(
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  child: Center(
                    child: GlassContainer(
                      blur: 20,
                      opacity: 0.88,
                      borderRadius: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      borderColor: AppColors.primary.withValues(alpha: 0.5),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_rounded, size: 52, color: AppColors.primary),
                          SizedBox(height: 12),
                          Text(
                            'Drop files to share',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Release files to automatically discover nearby devices',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
      bottomNavigationBar: _buildBottomTransferStatus(context, transProv),
    ),
    ),
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
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await FileHandler.openFolder();
              if (!ok && mounted) {
                final dir = await FileHandler.getDownloadsDirectory();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Folder: ${dir.path}'),
                    action: SnackBarAction(
                      label: 'Copy Path',
                      onPressed: () => Clipboard.setData(ClipboardData(text: dir.path)),
                    ),
                  ),
                );
              }
            },
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
              child: const Icon(Icons.folder_open_rounded, size: 20, color: AppColors.primary),
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
                BouncingCard(
                  onTap: () => FileHandler.openFolder(),
                  child: Tooltip(
                    message: 'Open folder in File Manager',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Open Folder',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        if (Platform.isAndroid || Platform.isIOS) ...[
          const SizedBox(height: AppSpacing.m),
          BouncingCard(
            onTap: () async {
              final uri = Uri.parse(AppConstants.websiteUrl);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.laptop_chromebook_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Get SendSnap for PC / Mac',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        NetworkStatusPill(devProv: devProv),
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

        if (devProv.isDiscovering) ...[
          const SizedBox(height: AppSpacing.m),
          if (_selectedFiles.isNotEmpty) ...[
            DraggableFileToken(
              files: _selectedFiles,
              onClear: () {
                setState(() {
                  _selectedFiles = [];
                });
              },
              onAddMore: () => _pickAdditionalFiles(context),
              onRemoveFile: (file) {
                setState(() {
                  _selectedFiles.removeWhere((f) => f.path == file.path);
                });
              },
              onDragUpdate: (globalPos, {fileName}) {
                _onDragUpdate(globalPos, MediaQuery.of(context).size, fileName: fileName);
              },
            ),
            if (_showEdgePortalHint && devProv.nearbyDevices.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildEdgePortalHint(),
            ],
          ] else ...[
            BouncingCard(
              onTap: () => _pickAdditionalFiles(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Choose files to send',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                        const Text('RECEIVER STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        const Text(
                          'Ready to Receive',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
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
          NetworkStatusPill(devProv: devProv),
          const SizedBox(height: AppSpacing.m),
          if (devProv.nearbyDevices.isNotEmpty) ...[
            _buildDeviceDiscovery(context, devProv, transProv),
            const SizedBox(height: AppSpacing.m),
          ],
          if (_showDiscoveryTroubleshooter && devProv.nearbyDevices.isEmpty) ...[
            _buildTroubleshooterBanner(context, devProv),
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

  Widget _buildTroubleshooterBanner(BuildContext context, DeviceProvider devProv) {
    return GlassContainer(
      blur: 16,
      opacity: 0.85,
      borderRadius: 22,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_find_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Looking for nearby devices...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Cannot find the other device? Make sure both devices are on the same Wi-Fi, have SendSnap open, and AP isolation is disabled.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BouncingCard(
                onTap: () async {
                  final uri = Uri.parse(AppConstants.websiteUrl);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.laptop_chromebook_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 5),
                      Text(
                        'Get PC App',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BouncingCard(
                onTap: () {
                  HapticFeedback.selectionClick();
                  NetworkDiagnosticsSheet.show(context, devProv);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.troubleshoot_rounded, size: 15, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Network Diagnostics & Tips',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    return DragTarget<List<File>>(
      onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        _initiateTransfer(context, device, devProv, transProv, files: details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;
        return AnimatedScale(
          scale: isTargeted ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: BouncingCard(
            onTap: () => _initiateTransfer(context, device, devProv, transProv, files: _selectedFiles),
            child: GlassContainer(
              blur: 20,
              opacity: isTargeted ? 0.95 : 0.75,
              borderRadius: 24,
              borderColor: isTargeted ? AppColors.primary : Colors.white,
              borderWidth: isTargeted ? 2.0 : 1.0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              margin: const EdgeInsets.only(right: 14),
              boxShadow: [
                BoxShadow(
                  color: isTargeted
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: isTargeted ? 20 : 14,
                  offset: const Offset(0, 4),
                ),
              ],
              child: SizedBox(
                width: 112,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DeviceAvatar(device: device, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      device.endpointName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isTargeted ? AppColors.primary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTargeted ? 'Drop to send' : _getDeviceFriendlySubtitle(device.deviceType),
                      style: TextStyle(
                        fontSize: 10,
                        color: isTargeted ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isTargeted ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getDeviceFriendlySubtitle(String type) {
    final t = type.toLowerCase();
    if (t.contains('windows')) return 'Windows PC';
    if (t.contains('mac')) return 'Mac';
    if (t.contains('ios') || t.contains('iphone')) return 'iPhone';
    if (t.contains('ipad')) return 'iPad';
    if (t.contains('android')) return 'Android';
    if (t.contains('linux')) return 'Linux PC';
    return 'Nearby';
  }

  Widget _buildEdgePortalHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text(
            'Drag file card to right edge to snap directly',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _showEdgePortalHint = false);
              SharedPreferences.getInstance().then(
                (prefs) => prefs.setBool('has_used_edge_portal', true),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: AppColors.primary),
            ),
          ),
        ],
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
    List<File>? selected;

    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop (Windows & Linux): Open native File Explorer dialog
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && result.paths.isNotEmpty) {
        selected = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
      }
    } else {
      // Mobile (Android & iOS): Use in-app media & storage picker sheet
      selected = await InAppFilePickerSheet.show(context, allowMultiple: true);
    }

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedFiles = selected!;
      });
      if (!devProv.isDiscovering) {
        devProv.toggleDiscovery();
      }
    }
  }

  Future<void> _pickAdditionalFiles(BuildContext context) async {
    List<File>? selected;
    if (!Platform.isAndroid && !Platform.isIOS) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && result.paths.isNotEmpty) {
        selected = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
      }
    } else {
      selected = await InAppFilePickerSheet.show(context, allowMultiple: true);
    }

    if (selected != null && selected.isNotEmpty && mounted) {
      setState(() {
        final existingPaths = _selectedFiles.map((f) => f.path).toSet();
        for (final file in selected!) {
          if (!existingPaths.contains(file.path)) {
            _selectedFiles.add(file);
          }
        }
      });
    }
  }

  void _initiateTransfer(
    BuildContext context,
    NearbyDevice target,
    DeviceProvider devProv,
    TransferProvider transProv, {
    List<File>? files,
  }) async {
    final filesToSend = (files != null && files.isNotEmpty)
        ? List<File>.from(files)
        : List<File>.from(_selectedFiles);
    if (filesToSend.isEmpty) return;
    
    _showConnectingSheet(context, target.endpointName);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    bool connected = await devProv.requestConnectionAndWait(target.endpointId);
    
    if (nav.canPop()) {
      nav.pop();
    }

    if (connected) {
      // Remove only the files being sent, preserving any remaining files!
      final sentPaths = filesToSend.map((f) => f.path).toSet();
      setState(() {
        _selectedFiles.removeWhere((f) => sentPaths.contains(f.path));
      });
      if (mounted) {
        nav.pushNamed('/transfer').then((_) {
          if (!mounted) return;
          // Keep discovery active so the user can continue dropping remaining files
          if (_selectedFiles.isNotEmpty && !devProv.isDiscovering) {
            devProv.toggleDiscovery();
          }
        });
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
                onTap: () async {
                  final result = await Navigator.pushNamed(context, '/transfer');
                  if (!mounted || result != true) return;
                  final dp = Provider.of<DeviceProvider>(this.context, listen: false);
                  final tp = Provider.of<TransferProvider>(this.context, listen: false);
                  _handleSend(this.context, dp, tp);
                },
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
