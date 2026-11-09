// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'SendSnap';

  @override
  String get appTagline => 'Partage direct ultra-rapide et 100% hors-ligne';

  @override
  String get navHome => 'Accueil';

  @override
  String get navTransfers => 'Transferts';

  @override
  String get navReceived => 'Fichiers reçus';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get commonBack => 'Retour';

  @override
  String get homeSendButton => 'ENVOYER';

  @override
  String get homeSendSubtitle =>
      'Partager des fichiers avec les appareils à proximité';

  @override
  String get homeReceiveButton => 'RECEVOIR';

  @override
  String get homeReceiveSubtitle => 'Rendre votre appareil détectable';

  @override
  String get homeReceiverStatus => 'STATUT DU RÉCEPTEUR';

  @override
  String get homeWifiConnected => 'Wi-Fi connecté';

  @override
  String get homeWifiDisconnected => 'Pas de Wi-Fi (Aide)';

  @override
  String get homeDragHandle => 'GLISSER';

  @override
  String get homeQrCode => 'Code QR';

  @override
  String get homeConnectingWifi => 'Connexion via le Wi-Fi local...';

  @override
  String get homeIpCopied => 'Adresse IP copiée dans le presse-papiers !';

  @override
  String get homeCameraPermission =>
      'L\'autorisation de la caméra est requise pour scanner les codes QR.';

  @override
  String get homeScanToConnect => 'Scanner pour se connecter';

  @override
  String homeConnectDirectly(String name) {
    return 'Se connecter directement à $name';
  }

  @override
  String get homeRadarSearching => 'Recherche d\'appareils à proximité...';

  @override
  String get homeRadarReady => 'Prêt pour l\'envoi et la réception';

  @override
  String get homeTroubleshoot => 'Dépannage';

  @override
  String get homeNoDevicesFound => 'Aucun appareil détecté pour l\'instant';

  @override
  String get homeNoDevicesHint =>
      'Assurez-vous que SendSnap est ouvert sur l\'autre appareil et connecté au même réseau Wi-Fi ou point d\'accès.';

  @override
  String get homeConnectManual => 'Connexion par IP';

  @override
  String get homeScanQr => 'Scanner le QR';

  @override
  String get homeDropHintSingle =>
      'Glissez la carte vers un appareil ou le bord pour envoyer';

  @override
  String get homeDropHintMulti =>
      'Glissez fichier par fichier ou le bandeau pour tout envoyer';

  @override
  String get homeDragAll => 'TOUT GLISSER';

  @override
  String get homeAddFiles => 'AJOUTER';

  @override
  String homeFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
      zero: 'Aucun fichier',
    );
    return '$_temp0';
  }

  @override
  String get homeEdgePortalHint =>
      'Poussez les fichiers vers le bord de l\'écran pour envoyer';

  @override
  String get homeDropToShare => 'Déposez pour partager';

  @override
  String get homeSendingViaPortal => 'Envoi via le portail d\'envoi rapide...';

  @override
  String get transferTitle => 'Transferts';

  @override
  String get transferNoActive => 'Aucun transfert en cours';

  @override
  String transferConnecting(String deviceName) {
    return 'Connexion à $deviceName...';
  }

  @override
  String transferSending(String fileName) {
    return 'Envoi de $fileName...';
  }

  @override
  String transferReceiving(String fileName) {
    return 'Réception de $fileName...';
  }

  @override
  String get transferCompleted => 'Transfert terminé avec succès';

  @override
  String get transferFailed => 'Échec du transfert';

  @override
  String get transferCanceled => 'Transfert annulé';

  @override
  String transferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String transferRemaining(String time) {
    return '$time restant';
  }

  @override
  String get transferViewFiles => 'Voir les fichiers reçus';

  @override
  String get transferCancel => 'Annuler';

  @override
  String get transferRetry => 'Réessayer';

  @override
  String get receivedTitle => 'Fichiers reçus';

  @override
  String get receivedSearchHint => 'Rechercher parmi les fichiers reçus...';

  @override
  String get receivedNoFiles => 'Aucun fichier reçu pour l\'instant';

  @override
  String get receivedNoFilesHint =>
      'Les fichiers que vous recevez d\'appareils à proximité apparaîtront ici.';

  @override
  String get receivedOpenFolder => 'Ouvrir le dossier';

  @override
  String get receivedDeleteTitle => 'Supprimer le fichier ?';

  @override
  String receivedDeleteConfirm(String fileName) {
    return 'Voulez-vous vraiment supprimer « $fileName » ? Cette action est irréversible.';
  }

  @override
  String get receivedFilterAll => 'Tous';

  @override
  String get receivedFilterPhotos => 'Photos';

  @override
  String get receivedFilterVideos => 'Vidéos';

  @override
  String get receivedFilterDocs => 'Documents';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsDeviceName => 'NOM DE L\'APPAREIL';

  @override
  String get settingsDeviceNameHint => 'Entrez le nom de votre appareil';

  @override
  String get settingsLanguage => 'LANGUE DE L\'APPLICATION';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsStorageTitle => 'STOCKAGE ET TÉLÉCHARGEMENTS';

  @override
  String get settingsSendSnapFolder => 'Dossier SendSnap';

  @override
  String get settingsOpen => 'Ouvrir';

  @override
  String get settingsWindowsSettings =>
      'PARAMÈTRES WINDOWS ET BARRE DES TÂCHES';

  @override
  String get settingsLaunchStartup => 'Lancer au démarrage de Windows';

  @override
  String get settingsLaunchStartupDesc =>
      'Démarrer SendSnap automatiquement en arrière-plan au démarrage du PC';

  @override
  String get settingsTaskbarTray => 'Icône dans la zone de notification';

  @override
  String get settingsTaskbarTrayDesc =>
      'Fermer la fenêtre réduit SendSnap dans la barre des tâches pour continuer à recevoir des fichiers';

  @override
  String get settingsTrayEnabled => 'ACTIVÉ';

  @override
  String get settingsRateApp => 'Évaluer SendSnap';

  @override
  String get settingsRateAppDesc =>
      'Laissez un avis pour soutenir le développement continu';

  @override
  String get settingsGetDesktop => 'Obtenir SendSnap pour PC';

  @override
  String get settingsGetDesktopDesc =>
      'Transférez des gigaoctets entre PC et Android à 100 Mo/s';

  @override
  String get settingsFeedback => 'Envoyer des commentaires';

  @override
  String get settingsFeedbackDesc =>
      'Suggestions de fonctionnalités et signalements de bugs directement à l\'équipe';

  @override
  String get settingsVersion => 'Version de SendSnap';

  @override
  String get rateEnjoyingTitle => 'Vous appréciez SendSnap ?';

  @override
  String rateEnjoyingDesc(String storeName) {
    return 'Si vous aimez le partage direct ultra-rapide et hors-ligne, prenez un instant pour nous laisser une note sur le $storeName !';
  }

  @override
  String rateSubmit(String storeName) {
    return 'Noter sur le $storeName';
  }

  @override
  String get rateFeedbackInstead => 'Envoyer un commentaire';

  @override
  String get rateLater => 'Plus tard';

  @override
  String get networkDiagTitle => 'Diagnostic réseau';

  @override
  String get networkDiagSubtitle =>
      'État du réseau Wi-Fi local et de la connexion directe';

  @override
  String get networkLocalIp => 'Adresse IP locale';

  @override
  String get networkConnected => 'Connecté';

  @override
  String get networkNotConnected => 'Non connecté';

  @override
  String get networkHotspotTip =>
      'Astuce : Pour une vitesse maximale (jusqu\'à 100 Mo/s), activez le point d\'accès de votre téléphone et connectez votre PC.';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionConfirm => 'Confirmer';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionDone => 'Terminé';
}
