import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData lightTheme({bool isArabic = false}) {
    final TextTheme baseTextTheme = isArabic
        ? GoogleFonts.cairoTextTheme()
        : GoogleFonts.outfitTextTheme();

    final textTheme = baseTextTheme.copyWith(
      displayLarge: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 30,
        letterSpacing: isArabic ? 0.0 : -0.5,
        height: isArabic ? 1.3 : 1.2,
      ),
      titleLarge: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: isArabic ? 0.0 : -0.2,
        height: isArabic ? 1.35 : 1.25,
      ),
      titleMedium: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.0,
        height: isArabic ? 1.35 : 1.25,
      ),
      bodyLarge: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.textPrimary,
        fontSize: 15,
        letterSpacing: 0.0,
        height: isArabic ? 1.4 : 1.3,
      ),
      bodyMedium: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.textSecondary,
        fontSize: 13.5,
        letterSpacing: 0.0,
        height: isArabic ? 1.4 : 1.3,
      ),
      bodySmall: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.textSecondary,
        fontSize: 11.5,
        letterSpacing: 0.0,
        height: isArabic ? 1.35 : 1.2,
      ),
      labelLarge: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: isArabic ? 0.0 : 1.0,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.08)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: (isArabic ? GoogleFonts.cairo : GoogleFonts.outfit)(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.0,
          ),
        ),
      ),
    );
  }
}
