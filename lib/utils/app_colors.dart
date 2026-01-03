import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryGreenLight = Color(0xFF81C784);
  static const Color primaryGreenDark = Color(0xFF388E3C);
  
  // Soft greens
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color mintGreen = Color(0xFFC8E6C9);
  static const Color pastelGreen = Color(0xFFA5D6A7);
  
  // Accent colors
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentBlue = Color(0xFF03A9F4);
  static const Color accentYellow = Color(0xFFFFEB3B);
  
  // Task status colors
  static const Color statusPending = Color(0xFFFF9800);
  static const Color statusClaimed = Color(0xFF2196F3);
  static const Color statusCompleted = Color(0xFF4CAF50);
  static const Color statusOff = Color(0xFFF44336);
  static const Color statusRejected = Color(0xFF9E9E9E);
  
  // Background colors
  static const Color background = Color(0xFFFAFCFA);
  static const Color cardBackground = Color(0xFFF5F9F5);
  static const Color white = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textDark = Color(0xFF2E3A2E);
  static const Color textMedium = Color(0xFF5A6B5A);
  static const Color textLight = Color(0xFF8A9B8A);
  
  // Status colors
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFEF5350);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, primaryGreenLight],
  );
  
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [softGreen, white],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
  );
  
  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: primaryGreen.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primaryGreen.withOpacity(0.2),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
