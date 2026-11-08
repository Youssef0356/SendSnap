import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';

class EcosystemService {
  static const MethodChannel _channel = MethodChannel('com.the356company.sendsnap/file_utils');

  /// Checks if Pagelit is installed on the current device.
  static Future<bool> isPagelitInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      final installed = await _channel.invokeMethod<bool>(
        'isPackageInstalled',
        {'package': AppConstants.pagelitPackageName},
      );
      return installed ?? false;
    } catch (e) {
      debugPrint('[EcosystemService] Error checking Pagelit installation: $e');
      return false;
    }
  }

  /// Opens a document file directly with Pagelit.
  static Future<bool> openWithPagelit(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>(
        'openFileWithPackage',
        {
          'path': filePath,
          'package': AppConstants.pagelitPackageName,
        },
      );
      return success ?? false;
    } catch (e) {
      debugPrint('[EcosystemService] Error opening file with Pagelit: $e');
      return false;
    }
  }

  /// Opens the Google Play Store page for Pagelit.
  static Future<void> openPagelitStore() async {
    try {
      final marketUri = Uri.parse('market://details?id=${AppConstants.pagelitPackageName}');
      final webUri = Uri.parse(AppConstants.pagelitPlayStoreUrl);

      if (Platform.isAndroid && await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[EcosystemService] Error opening Pagelit in store: $e');
    }
  }
}
