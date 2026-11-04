import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'providers/transfer_provider.dart';
import 'services/tray_and_window_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/received_files_screen.dart';
import 'config/theme.dart';

List<File> _initialLaunchFiles = [];

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final isAutostart = args.contains('--autostart');
  if (TrayAndWindowService.isDesktop) {
    await TrayAndWindowService.instance.init(isAutostartLaunch: isAutostart);
  }

  // If launched via "Open With..." on Windows or Linux, grab the passed files
  if (args.isNotEmpty) {
    _initialLaunchFiles = args
        .where((arg) => !arg.startsWith('-') && File(arg).existsSync())
        .map((path) => File(path))
        .toList();
  }
  
  // Support portrait and landscape across phones, tablets, and foldables
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
      ],
      child: const SendSnapApp(),
    ),
  );
}

class SendSnapApp extends StatefulWidget {
  const SendSnapApp({super.key});

  @override
  State<SendSnapApp> createState() => _SendSnapAppState();
}

class _SendSnapAppState extends State<SendSnapApp> {
  bool _syncSetup = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SendSnap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      navigatorKey: _navigatorKey,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => HomeScreen(initialFiles: _initialLaunchFiles),
        '/transfer': (context) => const TransferScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/received_files': (context) => const ReceivedFilesScreen(),
      },
      // Wire up the payload callbacks between providers ONCE
      builder: (context, child) {
        if (!_syncSetup) {
          final devProv = Provider.of<DeviceProvider>(context, listen: false);
          final transProv = Provider.of<TransferProvider>(context, listen: false);
          _setupSynchronization(devProv, transProv);
          _syncSetup = true;
        }
        return child!;
      },
    );
  }

  void _setupSynchronization(DeviceProvider devProv, TransferProvider transProv) {
    // Wire up nearby service callbacks to transfer provider
    devProv.nearbyService.onIncomingTransfer = (sender, transfer) {
      transProv.handleIncomingTransfer(sender, transfer);
    };
    
    devProv.nearbyService.onTransferProgress = (transferId, bytesTransferred, totalBytes, speed) {
      transProv.updateTransferProgress(
        transferId: transferId,
        bytesTransferred: bytesTransferred,
        totalBytes: totalBytes,
        speed: speed,
      );
    };

    devProv.nearbyService.onTransferCompleted = (transferId, savedPath) {
      transProv.markTransferCompleted(
        transferId: transferId,
        savedPath: savedPath,
      );
    };

    devProv.nearbyService.onTransferFailed = (transferId, error) {
      transProv.markTransferFailed(
        transferId: transferId,
        error: error,
      );
    };

    // Auto-navigate receiver to transfer screen when an incoming transfer starts
    transProv.onTransferStarted = () {
      debugPrint('[SendSnapApp] Transfer started — navigating to transfer screen');
      if (TrayAndWindowService.isDesktop) {
        TrayAndWindowService.instance.showWindow();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.pushNamed('/transfer');
      });
    };

    transProv.onTransferCompleted = () {
      debugPrint('[SendSnapApp] Transfer completed!');
    };
  }
}
