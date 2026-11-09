import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SendSnap'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Fast Offline P2P File Sharing'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get navTransfers;

  /// No description provided for @navReceived.
  ///
  /// In en, this message translates to:
  /// **'Received Files'**
  String get navReceived;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @homeSendButton.
  ///
  /// In en, this message translates to:
  /// **'SEND'**
  String get homeSendButton;

  /// No description provided for @homeSendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share files with nearby devices'**
  String get homeSendSubtitle;

  /// No description provided for @homeReceiveButton.
  ///
  /// In en, this message translates to:
  /// **'RECEIVE'**
  String get homeReceiveButton;

  /// No description provided for @homeReceiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make your device discoverable'**
  String get homeReceiveSubtitle;

  /// No description provided for @homeReceiverStatus.
  ///
  /// In en, this message translates to:
  /// **'RECEIVER STATUS'**
  String get homeReceiverStatus;

  /// No description provided for @homeWifiConnected.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Connected'**
  String get homeWifiConnected;

  /// No description provided for @homeWifiDisconnected.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi (Tap for help)'**
  String get homeWifiDisconnected;

  /// No description provided for @homeDragHandle.
  ///
  /// In en, this message translates to:
  /// **'DRAG'**
  String get homeDragHandle;

  /// No description provided for @homeQrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get homeQrCode;

  /// No description provided for @homeConnectingWifi.
  ///
  /// In en, this message translates to:
  /// **'Connecting over local Wi-Fi...'**
  String get homeConnectingWifi;

  /// No description provided for @homeIpCopied.
  ///
  /// In en, this message translates to:
  /// **'IP address copied to clipboard!'**
  String get homeIpCopied;

  /// No description provided for @homeCameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan QR codes.'**
  String get homeCameraPermission;

  /// No description provided for @homeScanToConnect.
  ///
  /// In en, this message translates to:
  /// **'Scan to Connect'**
  String get homeScanToConnect;

  /// No description provided for @homeConnectDirectly.
  ///
  /// In en, this message translates to:
  /// **'Connect directly to {name}'**
  String homeConnectDirectly(String name);

  /// No description provided for @homeRadarSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for nearby devices...'**
  String get homeRadarSearching;

  /// No description provided for @homeRadarReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to send and receive'**
  String get homeRadarReady;

  /// No description provided for @homeTroubleshoot.
  ///
  /// In en, this message translates to:
  /// **'Troubleshoot'**
  String get homeTroubleshoot;

  /// No description provided for @homeNoDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found yet'**
  String get homeNoDevicesFound;

  /// No description provided for @homeNoDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'Ensure SendSnap is open on the other device and connected to the same Wi-Fi or hotspot.'**
  String get homeNoDevicesHint;

  /// No description provided for @homeConnectManual.
  ///
  /// In en, this message translates to:
  /// **'Connect by IP'**
  String get homeConnectManual;

  /// No description provided for @homeScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get homeScanQr;

  /// No description provided for @homeDropHintSingle.
  ///
  /// In en, this message translates to:
  /// **'Drag card to nearby device or edge to send'**
  String get homeDropHintSingle;

  /// No description provided for @homeDropHintMulti.
  ///
  /// In en, this message translates to:
  /// **'Drop file per file or drag header to send all'**
  String get homeDropHintMulti;

  /// No description provided for @homeDragAll.
  ///
  /// In en, this message translates to:
  /// **'DRAG ALL'**
  String get homeDragAll;

  /// No description provided for @homeAddFiles.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get homeAddFiles;

  /// No description provided for @homeFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No files} =1{1 file} other{{count} files}}'**
  String homeFilesCount(int count);

  /// No description provided for @homeEdgePortalHint.
  ///
  /// In en, this message translates to:
  /// **'Push files towards screen edge to send'**
  String get homeEdgePortalHint;

  /// No description provided for @homeDropToShare.
  ///
  /// In en, this message translates to:
  /// **'Drop to share'**
  String get homeDropToShare;

  /// No description provided for @homeSendingViaPortal.
  ///
  /// In en, this message translates to:
  /// **'Sending via Edge Portal...'**
  String get homeSendingViaPortal;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transferTitle;

  /// No description provided for @transferNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active transfers'**
  String get transferNoActive;

  /// No description provided for @transferConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {deviceName}...'**
  String transferConnecting(String deviceName);

  /// No description provided for @transferSending.
  ///
  /// In en, this message translates to:
  /// **'Sending {fileName}...'**
  String transferSending(String fileName);

  /// No description provided for @transferReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving {fileName}...'**
  String transferReceiving(String fileName);

  /// No description provided for @transferCompleted.
  ///
  /// In en, this message translates to:
  /// **'Transfer completed successfully'**
  String get transferCompleted;

  /// No description provided for @transferFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed'**
  String get transferFailed;

  /// No description provided for @transferCanceled.
  ///
  /// In en, this message translates to:
  /// **'Transfer canceled'**
  String get transferCanceled;

  /// No description provided for @transferSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed}/s'**
  String transferSpeed(String speed);

  /// No description provided for @transferRemaining.
  ///
  /// In en, this message translates to:
  /// **'{time} remaining'**
  String transferRemaining(String time);

  /// No description provided for @transferViewFiles.
  ///
  /// In en, this message translates to:
  /// **'View Received Files'**
  String get transferViewFiles;

  /// No description provided for @transferCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transferCancel;

  /// No description provided for @transferRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transferRetry;

  /// No description provided for @receivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Received Files'**
  String get receivedTitle;

  /// No description provided for @receivedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search received files...'**
  String get receivedSearchHint;

  /// No description provided for @receivedNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files received yet'**
  String get receivedNoFiles;

  /// No description provided for @receivedNoFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Files you receive from nearby devices will show up here.'**
  String get receivedNoFilesHint;

  /// No description provided for @receivedOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get receivedOpenFolder;

  /// No description provided for @receivedDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete File?'**
  String get receivedDeleteTitle;

  /// No description provided for @receivedDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{fileName}\"? This cannot be undone.'**
  String receivedDeleteConfirm(String fileName);

  /// No description provided for @receivedFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get receivedFilterAll;

  /// No description provided for @receivedFilterPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get receivedFilterPhotos;

  /// No description provided for @receivedFilterVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get receivedFilterVideos;

  /// No description provided for @receivedFilterDocs.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get receivedFilterDocs;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDeviceName.
  ///
  /// In en, this message translates to:
  /// **'DEVICE DISPLAY NAME'**
  String get settingsDeviceName;

  /// No description provided for @settingsDeviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your device name'**
  String get settingsDeviceNameHint;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'APP LANGUAGE'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'STORAGE & DOWNLOADS'**
  String get settingsStorageTitle;

  /// No description provided for @settingsSendSnapFolder.
  ///
  /// In en, this message translates to:
  /// **'SendSnap Folder'**
  String get settingsSendSnapFolder;

  /// No description provided for @settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsOpen;

  /// No description provided for @settingsWindowsSettings.
  ///
  /// In en, this message translates to:
  /// **'WINDOWS & TASKBAR SETTINGS'**
  String get settingsWindowsSettings;

  /// No description provided for @settingsLaunchStartup.
  ///
  /// In en, this message translates to:
  /// **'Launch on Windows Startup'**
  String get settingsLaunchStartup;

  /// No description provided for @settingsLaunchStartupDesc.
  ///
  /// In en, this message translates to:
  /// **'Start SendSnap automatically in the background on PC boot'**
  String get settingsLaunchStartupDesc;

  /// No description provided for @settingsTaskbarTray.
  ///
  /// In en, this message translates to:
  /// **'Taskbar System Tray Icon'**
  String get settingsTaskbarTray;

  /// No description provided for @settingsTaskbarTrayDesc.
  ///
  /// In en, this message translates to:
  /// **'Closing the window hides SendSnap to the tray so you can always receive files'**
  String get settingsTaskbarTrayDesc;

  /// No description provided for @settingsTrayEnabled.
  ///
  /// In en, this message translates to:
  /// **'ENABLED'**
  String get settingsTrayEnabled;

  /// No description provided for @settingsRateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate SendSnap'**
  String get settingsRateApp;

  /// No description provided for @settingsRateAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave a review to support continuous development'**
  String get settingsRateAppDesc;

  /// No description provided for @settingsGetDesktop.
  ///
  /// In en, this message translates to:
  /// **'Get SendSnap for Desktop'**
  String get settingsGetDesktop;

  /// No description provided for @settingsGetDesktopDesc.
  ///
  /// In en, this message translates to:
  /// **'Transfer gigabytes between PC and Android at 100 MB/s'**
  String get settingsGetDesktopDesc;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Feature suggestions and bug reports directly to the team'**
  String get settingsFeedbackDesc;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'SendSnap Version'**
  String get settingsVersion;

  /// No description provided for @rateEnjoyingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying SendSnap?'**
  String get rateEnjoyingTitle;

  /// No description provided for @rateEnjoyingDesc.
  ///
  /// In en, this message translates to:
  /// **'If you love ultra-fast offline file sharing, please take a moment to rate us on the {storeName}!'**
  String rateEnjoyingDesc(String storeName);

  /// No description provided for @rateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Rate on {storeName}'**
  String rateSubmit(String storeName);

  /// No description provided for @rateFeedbackInstead.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get rateFeedbackInstead;

  /// No description provided for @rateLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get rateLater;

  /// No description provided for @networkDiagTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Diagnostics'**
  String get networkDiagTitle;

  /// No description provided for @networkDiagSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local Wi-Fi & P2P connection status'**
  String get networkDiagSubtitle;

  /// No description provided for @networkLocalIp.
  ///
  /// In en, this message translates to:
  /// **'Local IP Address'**
  String get networkLocalIp;

  /// No description provided for @networkConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get networkConnected;

  /// No description provided for @networkNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get networkNotConnected;

  /// No description provided for @networkHotspotTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: For maximum speed (up to 100 MB/s), turn on your phone\'s Personal Hotspot and connect your PC.'**
  String get networkHotspotTip;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
