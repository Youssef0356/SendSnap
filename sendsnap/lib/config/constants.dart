import 'package:flutter/material.dart';

class AppColors {
  // Apple-inspired Vibrant Palette
  static const Color primary = Color(0xFF3B5BFE);        // Electric Blue
  static const Color primaryDark = Color(0xFF2541DE);    // Deep Cobalt
  static const Color primaryLight = Color(0xFF6B8AFD);   // Soft Periwinkle
  static const Color secondary = Color(0xFF00D2FF);      // Vibrant Cyan
  static const Color accent = Color(0xFF00D2FF);         // Electric Cyan Accent
  
  static const Color receivePrimary = Color(0xFF00C853); // Mint Emerald
  static const Color receiveSecondary = Color(0xFF00E5FF);// Aqua
  
  static const Color background = Color(0xFFF7F9FD);     // Apple Soft Snow
  static const Color surface = Colors.white;
  
  static const Color textPrimary = Color(0xFF11141A);    // Jet Dark
  static const Color textSecondary = Color(0xFF757E90);  // Slate Grey
  static const Color textMuted = Color(0xFFA1AAB9);      // Muted Lavender
  
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF453A);          // Apple Red
  static const Color warning = Color(0xFFFF9F0A);        // Apple Orange

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B5BFE), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sendGradient = LinearGradient(
    colors: [Color(0xFF3B5BFE), Color(0xFF4A80FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient receiveGradient = LinearGradient(
    colors: [Color(0xFF00BFA5), Color(0xFF00E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassHighlight = LinearGradient(
    colors: [Colors.white, Color(0x33FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
