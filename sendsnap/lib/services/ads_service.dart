import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  // Test Ad Unit IDs
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Android Test Banner
          : 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner
    }
    // Replace with real IDs for production
    return Platform.isAndroid
        ? 'ca-app-pub-6774620515484669/3808498666' // Real Android Banner
        : 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Android Test Interstitial
          : 'ca-app-pub-3940256099942544/4411468910'; // iOS Test Interstitial
    }
    // Replace with real IDs for production
    return Platform.isAndroid
        ? 'ca-app-pub-6774620515484669/5670589682' // Real Android Interstitial
        : 'ca-app-pub-3940256099942544/4411468910';
  }

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoading = false;

  /// Loads an Interstitial Ad.
  static void loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          debugPrint('InterstitialAd loaded.');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  /// Shows the Interstitial Ad if loaded.
  static void showInterstitialAd({VoidCallback? onAdDismissed}) {
    if (_interstitialAd == null) {
      loadInterstitialAd();
      onAdDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next ad
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }

  /// Disposes the loaded ads.
  static void dispose() {
    _interstitialAd?.dispose();
  }
}
