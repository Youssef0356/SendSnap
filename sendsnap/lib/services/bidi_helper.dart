class BidiHelper {
  /// Unicode Left-To-Right Isolate (LRI)
  static const String lri = '\u2066';
  /// Unicode Pop Directional Isolate (PDI)
  static const String pdi = '\u2069';

  /// Wraps LTR technical strings (e.g. "192.168.1.1:53318", "45.2 MB/s", "12/40 MB")
  /// so that punctuation, hyphens, colons, and decimals do not get scrambled when embedded
  /// in RTL (Arabic) sentences or tables.
  static String isolate(String text) {
    if (text.isEmpty) return text;
    return '$lri$text$pdi';
  }

  /// Sanitizes a file name against Unicode Right-to-Left Override (RLO) exploits
  /// and invisible directional control markers (U+202A - U+202E, U+2066 - U+2069).
  /// This prevents malicious files like "document\u202Egpj.exe" from visually mimicking "documentexe.jpg".
  static String sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '')
        .trim();
  }
}
