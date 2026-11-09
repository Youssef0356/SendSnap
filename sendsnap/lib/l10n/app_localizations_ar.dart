// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'SendSnap';

  @override
  String get appTagline => 'مشاركة سريعة للملفات مباشرة دون إنترنت';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navTransfers => 'التحويلات';

  @override
  String get navReceived => 'الملفات المستلمة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get homeRadarSearching => 'جارٍ البحث عن الأجهزة المجاورة...';

  @override
  String get homeRadarReady => 'جاهز للإرسال والاستقبال';

  @override
  String get homeTroubleshoot => 'استكشاف الأخطاء';

  @override
  String get homeNoDevicesFound => 'لم يتم العثور على أجهزة بعد';

  @override
  String get homeNoDevicesHint =>
      'تأكد من فتح SendSnap على الجهاز الآخر واتصالهما بنفس شبكة Wi-Fi أو نقطة الاتصال.';

  @override
  String get homeConnectManual => 'اتصال عبر IP';

  @override
  String get homeScanQr => 'مسح الرمز';

  @override
  String get homeDropHintSingle =>
      'اسحب البطاقة نحو الجهاز أو حافة الشاشة للإرسال';

  @override
  String get homeDropHintMulti =>
      'أفلت كل ملف على حدة أو اسحب الشريط لإرسال الكل';

  @override
  String get homeDragAll => 'سحب الكل';

  @override
  String get homeAddFiles => 'إضافة';

  @override
  String homeFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفاً',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا توجد ملفات',
    );
    return '$_temp0';
  }

  @override
  String get homeEdgePortalHint =>
      'ادفع الملفات نحو حافة الشاشة للإرسال السريع';

  @override
  String get homeDropToShare => 'أفلت للمشاركة';

  @override
  String get homeSendingViaPortal => 'جارٍ الإرسال عبر بوابة الإرسال السريع...';

  @override
  String get transferTitle => 'التحويلات';

  @override
  String get transferNoActive => 'لا توجد عمليات نقل نشطة';

  @override
  String transferConnecting(String deviceName) {
    return 'جارٍ الاتصال بـ $deviceName...';
  }

  @override
  String transferSending(String fileName) {
    return 'جارٍ إرسال $fileName...';
  }

  @override
  String transferReceiving(String fileName) {
    return 'جارٍ استلام $fileName...';
  }

  @override
  String get transferCompleted => 'اكتمل النقل بنجاح';

  @override
  String get transferFailed => 'تعذر إكمال النقل';

  @override
  String get transferCanceled => 'تم إلغاء النقل';

  @override
  String transferSpeed(String speed) {
    return '$speed/ث';
  }

  @override
  String transferRemaining(String time) {
    return 'متبقي $time';
  }

  @override
  String get transferViewFiles => 'عرض الملفات المستلمة';

  @override
  String get transferCancel => 'إلغاء';

  @override
  String get transferRetry => 'إعادة المحاولة';

  @override
  String get receivedTitle => 'الملفات المستلمة';

  @override
  String get receivedSearchHint => 'البحث في الملفات المستلمة...';

  @override
  String get receivedNoFiles => 'لم يتم استلام أي ملفات بعد';

  @override
  String get receivedNoFilesHint =>
      'الملفات التي تستلمها من الأجهزة المجاورة ستظهر هنا.';

  @override
  String get receivedOpenFolder => 'فتح المجلد';

  @override
  String get receivedDeleteTitle => 'حذف الملف؟';

  @override
  String receivedDeleteConfirm(String fileName) {
    return 'هل أنت متأكد من رغبتك في حذف \"$fileName\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get receivedFilterAll => 'الكل';

  @override
  String get receivedFilterPhotos => 'الصور';

  @override
  String get receivedFilterVideos => 'الفيديو';

  @override
  String get receivedFilterDocs => 'المستندات';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsDeviceName => 'اسم الجهاز الظاهر';

  @override
  String get settingsDeviceNameHint => 'أدخل اسم جهازك';

  @override
  String get settingsLanguage => 'لغة التطبيق';

  @override
  String get settingsLanguageSystem => 'افتراضي النظام';

  @override
  String get settingsStorageTitle => 'التخزين والملفات المستلمة';

  @override
  String get settingsSendSnapFolder => 'مجلد SendSnap';

  @override
  String get settingsOpen => 'فتح';

  @override
  String get settingsWindowsSettings => 'إعدادات ويندوز وشريط المهام';

  @override
  String get settingsLaunchStartup => 'تشغيل تلقائي عند بدء ويندوز';

  @override
  String get settingsLaunchStartupDesc =>
      'تشغيل SendSnap تلقائياً في الخلفية فور إقلاع الكمبيوتر';

  @override
  String get settingsTaskbarTray => 'أيقونة شريط المهام';

  @override
  String get settingsTaskbarTrayDesc =>
      'إغلاق النافذة يصغّر SendSnap لشريط المهام للاستمرار في استقبال الملفات';

  @override
  String get settingsTrayEnabled => 'مفعّل';

  @override
  String get settingsRateApp => 'تقييم SendSnap';

  @override
  String get settingsRateAppDesc =>
      'أضف تقييمك لدعم استمرار التطوير والتحسينات';

  @override
  String get settingsGetDesktop => 'تحميل SendSnap للكمبيوتر';

  @override
  String get settingsGetDesktopDesc =>
      'انقل الجيجابايت بين الكمبيوتر والأندرويد بسرعة 100 م.ب/ث';

  @override
  String get settingsFeedback => 'إرسال ملاحظات';

  @override
  String get settingsFeedbackDesc =>
      'اقتراحات الميزات وبلاغات الأعطال مباشرة إلى الفريق';

  @override
  String get settingsVersion => 'إصدار SendSnap';

  @override
  String get rateEnjoyingTitle => 'هل أعجبك SendSnap؟';

  @override
  String rateEnjoyingDesc(String storeName) {
    return 'إذا كنت تستمتع بالنقل المباشر فائق السرعة، يسعدنا أن تمنحنا تقييماً على $storeName!';
  }

  @override
  String rateSubmit(String storeName) {
    return 'التقييم على $storeName';
  }

  @override
  String get rateFeedbackInstead => 'إرسال ملاحظات';

  @override
  String get rateLater => 'لاحقاً';

  @override
  String get networkDiagTitle => 'تشخيص الشبكة';

  @override
  String get networkDiagSubtitle => 'حالة اتصال Wi-Fi والنقل المباشر';

  @override
  String get networkLocalIp => 'عنوان IP المحلي';

  @override
  String get networkConnected => 'متصل';

  @override
  String get networkNotConnected => 'غير متصل';

  @override
  String get networkHotspotTip =>
      'نصيحة: للحصول على أقصى سرعة (تصل إلى 100 م.ب/ث)، فعّل نقطة اتصال هاتفك الشخصية ووصّل الكمبيوتر بها.';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDone => 'تم';
}
