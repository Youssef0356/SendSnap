import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sendsnap/services/bidi_helper.dart';
import 'package:sendsnap/models/device.dart';
import 'package:sendsnap/models/transfer.dart';
import 'package:sendsnap/models/transfer_file.dart';
import 'package:sendsnap/config/theme.dart';
import 'package:sendsnap/l10n/app_localizations_en.dart';
import 'package:sendsnap/l10n/app_localizations_fr.dart';
import 'package:sendsnap/l10n/app_localizations_ar.dart';
import 'package:sendsnap/l10n/app_localizations_es.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('BidiHelper Tests', () {
    test('isolate wraps text in Unicode LTR and PDI control characters', () {
      expect(BidiHelper.isolate(''), equals(''));
      expect(BidiHelper.isolate('192.168.1.1:53318'), equals('\u2066192.168.1.1:53318\u2069'));
      expect(BidiHelper.isolate('45.2 MB/s'), equals('\u206645.2 MB/s\u2069'));
    });

    test('sanitizeFileName strips malicious Right-to-Left Override and directional marks', () {
      // Benign filename
      expect(BidiHelper.sanitizeFileName('document.pdf'), equals('document.pdf'));
      expect(BidiHelper.sanitizeFileName('ملف_العمل.docx'), equals('ملف_العمل.docx'));
      expect(BidiHelper.sanitizeFileName('résumé_2026.pdf'), equals('résumé_2026.pdf'));

      // Right-to-Left Override (RLO) attack: document\u202Efdp.exe -> displays visually as documentexe.pdf
      const rloAttack = 'document\u202Efdp.exe';
      final sanitized = BidiHelper.sanitizeFileName(rloAttack);
      expect(sanitized, equals('documentfdp.exe'));
      expect(sanitized.contains('\u202E'), isFalse);

      // Multiple directional embeddings and overrides
      const mixedMarks = '\u200Etest_\u202Afolder\u202C_\u2066token\u2069.txt';
      expect(BidiHelper.sanitizeFileName(mixedMarks), equals('test_folder_token.txt'));
    });
  });

  group('Model Sanitation & BiDi Isolation Tests', () {
    test('NearbyDevice.fromJson sanitizes device name against RLO exploits', () {
      final device = NearbyDevice.fromJson({
        'id': 'test-1',
        'name': 'Hacker\u202EDevice',
        'ip': '192.168.1.20',
      });
      expect(device.name, equals('HackerDevice'));
      expect(device.name.contains('\u202E'), isFalse);
    });

    test('FileTransfer.fromJson sanitizes fileName and formats speed with BiDi isolation', () {
      final transfer = FileTransfer.fromJson({
        'id': 'tx-1',
        'fileName': 'malicious\u202Egpj.exe',
        'fileSize': 1024 * 1024 * 5,
        'status': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(transfer.fileName, equals('maliciousgpj.exe'));

      final withSpeed = transfer.copyWith(speed: 1024 * 1024 * 25.5);
      expect(withSpeed.formattedSpeed, startsWith('\u2066'));
      expect(withSpeed.formattedSpeed, endsWith('\u2069'));
      expect(withSpeed.formattedSpeed, contains('25.5 MB/s'));
    });

    test('TransferFile.formattedSize formats units correctly with BiDi isolation', () {
      const fileBytes = TransferFile(name: 'test', path: '', size: 500);
      expect(fileBytes.formattedSize, equals('\u2066500 B\u2069'));

      const fileKb = TransferFile(name: 'test', path: '', size: 2048);
      expect(fileKb.formattedSize, equals('\u20662.0 KB\u2069'));

      const fileMb = TransferFile(name: 'test', path: '', size: 1024 * 1024 * 10);
      expect(fileMb.formattedSize, equals('\u206610.0 MB\u2069'));

      const fileGb = TransferFile(name: 'test', path: '', size: 1024 * 1024 * 1024 * 3);
      expect(fileGb.formattedSize, equals('\u20663.0 GB\u2069'));
    });
  });

  group('ARB Localization & Plural Grammar Tests', () {
    test('English pluralization rules', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.homeFilesCount(0), equals('No files'));
      expect(l10n.homeFilesCount(1), equals('1 file'));
      expect(l10n.homeFilesCount(5), equals('5 files'));
      expect(l10n.appTitle, equals('SendSnap'));
    });

    test('French transcreated strings & pluralization', () {
      final l10n = AppLocalizationsFr();
      expect(l10n.homeFilesCount(0), equals('Aucun fichier'));
      expect(l10n.homeFilesCount(1), equals('1 fichier'));
      expect(l10n.homeFilesCount(5), equals('5 fichiers'));
      expect(l10n.homeDragAll, equals('TOUT GLISSER'));
      expect(l10n.appTitle, equals('SendSnap'));
    });

    test('Arabic 6-category pluralization rules', () {
      final l10n = AppLocalizationsAr();
      // Zero
      expect(l10n.homeFilesCount(0), equals('لا توجد ملفات'));
      // One
      expect(l10n.homeFilesCount(1), equals('ملف واحد'));
      // Dual (Two)
      expect(l10n.homeFilesCount(2), equals('ملفان'));
      // Few (3 - 10)
      expect(l10n.homeFilesCount(3), equals('3 ملفات'));
      expect(l10n.homeFilesCount(10), equals('10 ملفات'));
      // Many (11 - 99)
      expect(l10n.homeFilesCount(11), equals('11 ملفاً'));
      expect(l10n.homeFilesCount(45), equals('45 ملفاً'));
      expect(l10n.homeFilesCount(99), equals('99 ملفاً'));
      // Other (100, 200, 1000...) vs Few with higher hundreds (103)
      expect(l10n.homeFilesCount(100), equals('100 ملف'));
      expect(l10n.homeFilesCount(103), equals('103 ملفات'));

      // Check key transcreated terms
      expect(l10n.appTitle, equals('SendSnap'));
      expect(l10n.homeDragAll, equals('سحب الكل'));
    });

    test('Spanish transcreated strings & pluralization', () {
      final l10n = AppLocalizationsEs();
      expect(l10n.homeFilesCount(0), equals('Ningún archivo'));
      expect(l10n.homeFilesCount(1), equals('1 archivo'));
      expect(l10n.homeFilesCount(5), equals('5 archivos'));
      expect(l10n.homeDragAll, equals('ARRASTRAR TODO'));
      expect(l10n.appTitle, equals('SendSnap'));
    });
  });

  group('Typography & Theme Tests', () {
    test('Arabic theme strictly enforces letterSpacing: 0.0 to preserve cursive ligatures', () async {
      final completer = Completer<void>();
      runZonedGuarded(() {
        final arabicTheme = AppTheme.lightTheme(isArabic: true);
        final textTheme = arabicTheme.textTheme;

        expect(textTheme.displayLarge?.letterSpacing, equals(0.0));
        expect(textTheme.titleLarge?.letterSpacing, equals(0.0));
        expect(textTheme.titleMedium?.letterSpacing, equals(0.0));
        expect(textTheme.bodyLarge?.letterSpacing, equals(0.0));
        expect(textTheme.bodyMedium?.letterSpacing, equals(0.0));
        expect(textTheme.bodySmall?.letterSpacing, equals(0.0));
        expect(textTheme.labelLarge?.letterSpacing, equals(0.0));
        completer.complete();
      }, (error, stackTrace) {
        // Ignore GoogleFonts network/asset missing errors in headless unit tests
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      });
      await completer.future;
    });

    test('Latin theme preserves modern negative display and uppercase label letterSpacing', () async {
      final completer = Completer<void>();
      runZonedGuarded(() {
        final latinTheme = AppTheme.lightTheme(isArabic: false);
        final textTheme = latinTheme.textTheme;

        expect(textTheme.displayLarge?.letterSpacing, equals(-0.5));
        expect(textTheme.labelLarge?.letterSpacing, equals(1.0));
        completer.complete();
      }, (error, stackTrace) {
        // Ignore GoogleFonts network/asset missing errors in headless unit tests
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      });
      await completer.future;
    });
  });
}
