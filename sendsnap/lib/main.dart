import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/settings_screen.dart';
import 'config/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait for a better UI experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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

class SendSnapApp extends StatelessWidget {
  const SendSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SendSnap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/transfer': (context) => const TransferScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      // Handle the payload callback from Nearby Service by notifying TransferProvider
      // Note: In a production app, we'd use a higher-level state management synchronization.
      builder: (context, child) {
        final devProv = Provider.of<DeviceProvider>(context, listen: false);
        final transProv = Provider.of<TransferProvider>(context, listen: false);
        
        // Wire up callbacks once
        _setupSynchronization(devProv, transProv);
        
        return child!;
      },
    );
  }

  void _setupSynchronization(DeviceProvider devProv, TransferProvider transProv) {
    devProv.nearbyService.onMetadataReceived = (endpoint, wrapper) {
      transProv.handleIncomingMetadata(endpoint, wrapper, devProv.nearbyService);
    };
    
    devProv.nearbyService.onPayloadUpdate = (endpoint, payloadId, update) {
      transProv.updateTransferProgress(payloadId, update);
    };
  }
}
