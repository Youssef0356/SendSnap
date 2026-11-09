// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'SendSnap';

  @override
  String get appTagline =>
      'Transferencia rápida de archivos punto a punto sin internet';

  @override
  String get navHome => 'Inicio';

  @override
  String get navTransfers => 'Transferencias';

  @override
  String get navReceived => 'Archivos recibidos';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get homeRadarSearching => 'Buscando dispositivos cercanos...';

  @override
  String get homeRadarReady => 'Listo para enviar y recibir';

  @override
  String get homeTroubleshoot => 'Solución de problemas';

  @override
  String get homeNoDevicesFound => 'Aún no se encontraron dispositivos';

  @override
  String get homeNoDevicesHint =>
      'Asegúrate de que SendSnap esté abierto en el otro dispositivo y conectado a la misma red Wi-Fi o zona portátil.';

  @override
  String get homeConnectManual => 'Conectar por IP';

  @override
  String get homeScanQr => 'Escanear QR';

  @override
  String get homeDropHintSingle =>
      'Arrastra la tarjeta al dispositivo o al borde para enviar';

  @override
  String get homeDropHintMulti =>
      'Suelta archivo por archivo o arrastra la barra para enviar todo';

  @override
  String get homeDragAll => 'ARRASTRAR TODO';

  @override
  String get homeAddFiles => 'AÑADIR';

  @override
  String homeFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
      zero: 'Ningún archivo',
    );
    return '$_temp0';
  }

  @override
  String get homeEdgePortalHint =>
      'Empuja los archivos hacia el borde de la pantalla para enviar';

  @override
  String get homeDropToShare => 'Suelta para compartir';

  @override
  String get homeSendingViaPortal => 'Enviando mediante el portal lateral...';

  @override
  String get transferTitle => 'Transferencias';

  @override
  String get transferNoActive => 'No hay transferencias activas';

  @override
  String transferConnecting(String deviceName) {
    return 'Conectando con $deviceName...';
  }

  @override
  String transferSending(String fileName) {
    return 'Enviando $fileName...';
  }

  @override
  String transferReceiving(String fileName) {
    return 'Recibiendo $fileName...';
  }

  @override
  String get transferCompleted => 'Transferencia completada con éxito';

  @override
  String get transferFailed => 'Error en la transferencia';

  @override
  String get transferCanceled => 'Transferencia cancelada';

  @override
  String transferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String transferRemaining(String time) {
    return 'quedan $time';
  }

  @override
  String get transferViewFiles => 'Ver archivos recibidos';

  @override
  String get transferCancel => 'Cancelar';

  @override
  String get transferRetry => 'Reintentar';

  @override
  String get receivedTitle => 'Archivos recibidos';

  @override
  String get receivedSearchHint => 'Buscar entre los archivos recibidos...';

  @override
  String get receivedNoFiles => 'Aún no has recibido archivos';

  @override
  String get receivedNoFilesHint =>
      'Los archivos que recibas de dispositivos cercanos aparecerán aquí.';

  @override
  String get receivedOpenFolder => 'Abrir carpeta';

  @override
  String get receivedDeleteTitle => '¿Eliminar archivo?';

  @override
  String receivedDeleteConfirm(String fileName) {
    return '¿Estás seguro de que deseas eliminar \"$fileName\"? Esta acción no se puede deshacer.';
  }

  @override
  String get receivedFilterAll => 'Todos';

  @override
  String get receivedFilterPhotos => 'Fotos';

  @override
  String get receivedFilterVideos => 'Vídeos';

  @override
  String get receivedFilterDocs => 'Documentos';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsDeviceName => 'NOMBRE DEL DISPOSITIVO';

  @override
  String get settingsDeviceNameHint => 'Introduce el nombre de tu dispositivo';

  @override
  String get settingsLanguage => 'IDIOMA DE LA APLICACIÓN';

  @override
  String get settingsLanguageSystem => 'Predeterminado del sistema';

  @override
  String get settingsStorageTitle => 'ALMACENAMIENTO Y DESCARGAS';

  @override
  String get settingsSendSnapFolder => 'Carpeta SendSnap';

  @override
  String get settingsOpen => 'Abrir';

  @override
  String get settingsWindowsSettings => 'AJUSTES DE WINDOWS Y BARRA DE TAREAS';

  @override
  String get settingsLaunchStartup => 'Iniciar con Windows';

  @override
  String get settingsLaunchStartupDesc =>
      'Iniciar SendSnap automáticamente en segundo plano al arrancar la PC';

  @override
  String get settingsTaskbarTray => 'Icono en la bandeja del sistema';

  @override
  String get settingsTaskbarTrayDesc =>
      'Cerrar la ventana minimiza SendSnap a la bandeja para seguir recibiendo archivos';

  @override
  String get settingsTrayEnabled => 'ACTIVADO';

  @override
  String get settingsRateApp => 'Valorar SendSnap';

  @override
  String get settingsRateAppDesc =>
      'Deja tu valoración para apoyar el desarrollo continuo';

  @override
  String get settingsGetDesktop => 'Obtener SendSnap para PC';

  @override
  String get settingsGetDesktopDesc =>
      'Transfiere gigabytes entre PC y Android a 100 MB/s';

  @override
  String get settingsFeedback => 'Enviar comentarios';

  @override
  String get settingsFeedbackDesc =>
      'Sugerencias de funciones e informes de errores directamente al equipo';

  @override
  String get settingsVersion => 'Versión de SendSnap';

  @override
  String get rateEnjoyingTitle => '¿Te gusta SendSnap?';

  @override
  String rateEnjoyingDesc(String storeName) {
    return 'Si te gusta el intercambio rápido sin conexión, ¡tómate un momento para calificarnos en $storeName!';
  }

  @override
  String rateSubmit(String storeName) {
    return 'Valorar en $storeName';
  }

  @override
  String get rateFeedbackInstead => 'Enviar comentarios';

  @override
  String get rateLater => 'Más tarde';

  @override
  String get networkDiagTitle => 'Diagnóstico de red';

  @override
  String get networkDiagSubtitle =>
      'Estado de la red Wi-Fi local y conexión directa';

  @override
  String get networkLocalIp => 'Dirección IP local';

  @override
  String get networkConnected => 'Conectado';

  @override
  String get networkNotConnected => 'No conectado';

  @override
  String get networkHotspotTip =>
      'Consejo: Para la máxima velocidad (hasta 100 MB/s), activa la zona Wi-Fi de tu móvil y conecta tu PC.';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionDone => 'Listo';
}
