import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/file_picker_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads
  MobileAds.instance.initialize();

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: SendSnapApp()));
}

class SendSnapApp extends StatelessWidget {
  const SendSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SendSnap',
      debugShowCheckedModeBanner: false,
      theme: SendSnapTheme.darkTheme(),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/role': (context) => const RoleSelectionScreen(),
        '/home': (context) => const HomeScreen(),
        '/pick': (context) => const FilePickerScreen(),
        '/transfer': (context) => const TransferScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
