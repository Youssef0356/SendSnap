import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  bool _initialized = false;

  // Real Ad Unit IDs (from project history) - fallback to Test IDs in debug mode
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/6300978111' 
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-6774620515484669/8936044734'; 
    } else {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-6774620515484669/1376814271';
    } else {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint('[Ads] MobileAds initialized');
    } catch (e) {
      debugPrint('[Ads] Initialization error: $e');
    }
  }

  void loadInterstitial(Function(InterstitialAd) onLoaded) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[Ads] Interstitial loaded');
          onLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] Interstitial failed to load: $error');
        },
      ),
    );
  }
}
