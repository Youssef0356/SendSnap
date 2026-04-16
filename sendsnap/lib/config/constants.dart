import 'package:flutter/material.dart';

class AppColors {
  // Primary palette (Light & Premium)
  static const Color primary = Color(0xFF3D5AFE); // Electric Blue
  static const Color secondary = Color(0xFF00B0FF); // Light Azure
  
  static const Color background = Color(0xFFF8F9FE); // Very light grey-blue
  static const Color surface = Colors.white;
  
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6C757D);
  
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB40);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
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
