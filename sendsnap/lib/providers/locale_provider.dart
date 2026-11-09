import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageOption {
  final String code; // 'system', 'en', 'fr', 'ar', 'es'
  final String nativeName;
  final String englishName;

  const AppLanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}

class LocaleProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String prefKey = 'selected_language';

  static const List<AppLanguageOption> supportedLanguages = [
    AppLanguageOption(code: 'system', nativeName: 'System Default', englishName: 'System Default'),
    AppLanguageOption(code: 'en', nativeName: 'English', englishName: 'English'),
    AppLanguageOption(code: 'fr', nativeName: 'Français', englishName: 'French'),
    AppLanguageOption(code: 'ar', nativeName: 'العربية', englishName: 'Arabic'),
    AppLanguageOption(code: 'es', nativeName: 'Español', englishName: 'Spanish'),
  ];

  Locale? _locale;
  bool _isInitialized = false;

  Locale? get locale => _locale;
  bool get isInitialized => _isInitialized;

  /// Returns true if the active language is Arabic (either explicitly selected
  /// or inherited from the host system OS).
  bool get isRTL {
    if (_locale != null) {
      return _locale!.languageCode == 'ar';
    }
    try {
      return WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar';
    } catch (_) {
      return false;
    }
  }

  String get currentCode {
    if (_locale == null) return 'system';
    return _locale!.languageCode;
  }

  LocaleProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadFromPrefs();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // If user is using system default, react to device system language change
    if (_locale == null) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefKey);
      if (code != null && code.isNotEmpty && code != 'system') {
        _locale = Locale(code);
      } else {
        _locale = null; // Follow system OS
      }
    } catch (e) {
      debugPrint('[LocaleProvider] Error loading saved locale: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == 'system') {
      _locale = null;
      await prefs.setString(prefKey, 'system');
    } else {
      _locale = Locale(code);
      await prefs.setString(prefKey, code);
    }
    notifyListeners();
  }
}
