import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/rate_us_dialog.dart';

/// Manages smart "Rate Us" prompting logic based on user engagement milestones.
/// Prompts after moments of delight (e.g. 2nd successful transfer),
/// never during an active transfer, and respects dismissals.
class RatingService {
  static const String _prefKeyCount = 'sendsnap_successful_transfers_count';
  static const String _prefKeyHasRated = 'sendsnap_has_rated_app';
  static const String _prefKeyLastPrompt = 'sendsnap_last_rate_prompt_timestamp';

  /// Records a successful transfer and evaluates whether to show the rating dialog.
  static Future<bool> recordSuccessfulTransfer(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool(_prefKeyHasRated) ?? false;
    if (hasRated) return false;

    final currentCount = (prefs.getInt(_prefKeyCount) ?? 0) + 1;
    await prefs.setInt(_prefKeyCount, currentCount);

    final lastPromptMs = prefs.getInt(_prefKeyLastPrompt);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Trigger on the 2nd transfer, and periodically every 5 subsequent transfers if postponed (at least 3 days apart)
    bool shouldShow = false;
    if (currentCount == 2) {
      shouldShow = true;
    } else if (currentCount > 2 && currentCount % 5 == 0) {
      if (lastPromptMs == null || (now - lastPromptMs) > const Duration(days: 3).inMilliseconds) {
        shouldShow = true;
      }
    }

    if (shouldShow && context.mounted) {
      await prefs.setInt(_prefKeyLastPrompt, now);
      // Wait a moment for the user to celebrate completion before presenting
      await Future.delayed(const Duration(milliseconds: 600));
      if (context.mounted) {
        RateUsDialog.show(context);
        return true;
      }
    }
    return false;
  }

  /// Manually shows the rating dialog (e.g. from Settings).
  static void showManual(BuildContext context) {
    RateUsDialog.show(context);
  }

  /// Marks that the user completed the rating.
  static Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyHasRated, true);
  }

  /// Marks that the user dismissed or postponed the prompt.
  static Future<void> markPostponed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastPrompt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Opens the store review page.
  static Future<void> launchStoreReview() async {
    await markRated();
    Uri? url;
    if (Platform.isAndroid) {
      url = Uri.parse('market://details?id=com.the356company.sendsnap');
    } else if (Platform.isWindows) {
      url = Uri.parse('https://apps.microsoft.com/detail/sendsnap');
    } else if (Platform.isIOS || Platform.isMacOS) {
      url = Uri.parse('https://apps.apple.com/app/sendsnap/id123456789');
    } else {
      url = Uri.parse('https://github.com/Youssef0356/SendSnap');
    }

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && Platform.isAndroid) {
        // Fallback to web browser Play Store link
        await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=com.the356company.sendsnap'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      // Fallback
      await launchUrl(
        Uri.parse('https://github.com/Youssef0356/SendSnap'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// Opens the developer feedback channel for low ratings (< 4 stars).
  static Future<void> launchFeedbackEmail() async {
    await markRated();
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'nejiyoussef081@gmail.com',
      queryParameters: {
        'subject': 'SendSnap User Feedback',
        'body': 'Hi SendSnap team,\n\nHere is how you can improve SendSnap:\n',
      },
    );
    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
