// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SendSnap';

  @override
  String get appTagline => 'Fast Offline P2P File Sharing';

  @override
  String get navHome => 'Home';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navReceived => 'Received Files';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonBack => 'Back';

  @override
  String get homeSendButton => 'SEND';

  @override
  String get homeSendSubtitle => 'Share files with nearby devices';

  @override
  String get homeReceiveButton => 'RECEIVE';

  @override
  String get homeReceiveSubtitle => 'Make your device discoverable';

  @override
  String get homeReceiverStatus => 'RECEIVER STATUS';

  @override
  String get homeWifiConnected => 'Wi-Fi Connected';

  @override
  String get homeWifiDisconnected => 'No Wi-Fi (Tap for help)';

  @override
  String get homeDragHandle => 'DRAG';

  @override
  String get homeQrCode => 'QR Code';

  @override
  String get homeConnectingWifi => 'Connecting over local Wi-Fi...';

  @override
  String get homeIpCopied => 'IP address copied to clipboard!';

  @override
  String get homeCameraPermission =>
      'Camera permission is required to scan QR codes.';

  @override
  String get homeScanToConnect => 'Scan to Connect';

  @override
  String homeConnectDirectly(String name) {
    return 'Connect directly to $name';
  }

  @override
  String get homeRadarSearching => 'Looking for nearby devices...';

  @override
  String get homeRadarReady => 'Ready to send and receive';

  @override
  String get homeTroubleshoot => 'Troubleshoot';

  @override
  String get homeNoDevicesFound => 'No devices found yet';

  @override
  String get homeNoDevicesHint =>
      'Ensure SendSnap is open on the other device and connected to the same Wi-Fi or hotspot.';

  @override
  String get homeConnectManual => 'Connect by IP';

  @override
  String get homeScanQr => 'Scan QR';

  @override
  String get homeDropHintSingle => 'Drag card to nearby device or edge to send';

  @override
  String get homeDropHintMulti =>
      'Drop file per file or drag header to send all';

  @override
  String get homeDragAll => 'DRAG ALL';

  @override
  String get homeAddFiles => 'ADD';

  @override
  String homeFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
      zero: 'No files',
    );
    return '$_temp0';
  }

  @override
  String get homeEdgePortalHint => 'Push files towards screen edge to send';

  @override
  String get homeDropToShare => 'Drop to share';

  @override
  String get homeSendingViaPortal => 'Sending via Edge Portal...';

  @override
  String get transferTitle => 'Transfers';

  @override
  String get transferNoActive => 'No active transfers';

  @override
  String transferConnecting(String deviceName) {
    return 'Connecting to $deviceName...';
  }

  @override
  String transferSending(String fileName) {
    return 'Sending $fileName...';
  }

  @override
  String transferReceiving(String fileName) {
    return 'Receiving $fileName...';
  }

  @override
  String get transferCompleted => 'Transfer completed successfully';

  @override
  String get transferFailed => 'Transfer failed';

  @override
  String get transferCanceled => 'Transfer canceled';

  @override
  String transferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String transferRemaining(String time) {
    return '$time remaining';
  }

  @override
  String get transferViewFiles => 'View Received Files';

  @override
  String get transferCancel => 'Cancel';

  @override
  String get transferRetry => 'Retry';

  @override
  String get receivedTitle => 'Received Files';

  @override
  String get receivedSearchHint => 'Search received files...';

  @override
  String get receivedNoFiles => 'No files received yet';

  @override
  String get receivedNoFilesHint =>
      'Files you receive from nearby devices will show up here.';

  @override
  String get receivedOpenFolder => 'Open Folder';

  @override
  String get receivedDeleteTitle => 'Delete File?';

  @override
  String receivedDeleteConfirm(String fileName) {
    return 'Are you sure you want to delete \"$fileName\"? This cannot be undone.';
  }

  @override
  String get receivedFilterAll => 'All';

  @override
  String get receivedFilterPhotos => 'Photos';

  @override
  String get receivedFilterVideos => 'Videos';

  @override
  String get receivedFilterDocs => 'Documents';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDeviceName => 'DEVICE DISPLAY NAME';

  @override
  String get settingsDeviceNameHint => 'Enter your device name';

  @override
  String get settingsLanguage => 'APP LANGUAGE';

  @override
  String get settingsLanguageSystem => 'System Default';

  @override
  String get settingsStorageTitle => 'STORAGE & DOWNLOADS';

  @override
  String get settingsSendSnapFolder => 'SendSnap Folder';

  @override
  String get settingsOpen => 'Open';

  @override
  String get settingsWindowsSettings => 'WINDOWS & TASKBAR SETTINGS';

  @override
  String get settingsLaunchStartup => 'Launch on Windows Startup';

  @override
  String get settingsLaunchStartupDesc =>
      'Start SendSnap automatically in the background on PC boot';

  @override
  String get settingsTaskbarTray => 'Taskbar System Tray Icon';

  @override
  String get settingsTaskbarTrayDesc =>
      'Closing the window hides SendSnap to the tray so you can always receive files';

  @override
  String get settingsTrayEnabled => 'ENABLED';

  @override
  String get settingsRateApp => 'Rate SendSnap';

  @override
  String get settingsRateAppDesc =>
      'Leave a review to support continuous development';

  @override
  String get settingsGetDesktop => 'Get SendSnap for Desktop';

  @override
  String get settingsGetDesktopDesc =>
      'Transfer gigabytes between PC and Android at 100 MB/s';

  @override
  String get settingsFeedback => 'Send Feedback';

  @override
  String get settingsFeedbackDesc =>
      'Feature suggestions and bug reports directly to the team';

  @override
  String get settingsVersion => 'SendSnap Version';

  @override
  String get rateEnjoyingTitle => 'Enjoying SendSnap?';

  @override
  String rateEnjoyingDesc(String storeName) {
    return 'If you love ultra-fast offline file sharing, please take a moment to rate us on the $storeName!';
  }

  @override
  String rateSubmit(String storeName) {
    return 'Rate on $storeName';
  }

  @override
  String get rateFeedbackInstead => 'Send Feedback';

  @override
  String get rateLater => 'Maybe Later';

  @override
  String get networkDiagTitle => 'Network Diagnostics';

  @override
  String get networkDiagSubtitle => 'Local Wi-Fi & P2P connection status';

  @override
  String get networkLocalIp => 'Local IP Address';

  @override
  String get networkConnected => 'Connected';

  @override
  String get networkNotConnected => 'Not Connected';

  @override
  String get networkHotspotTip =>
      'Tip: For maximum speed (up to 100 MB/s), turn on your phone\'s Personal Hotspot and connect your PC.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDone => 'Done';
}
