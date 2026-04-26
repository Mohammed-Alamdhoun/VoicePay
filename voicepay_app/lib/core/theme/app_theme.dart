import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2463F6);
  static const Color primaryDark = Color(0xFF1D4FE0);
  static const Color background = Color(0xFFF3F6FB);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF13294B);
  static const Color textMuted = Color(0xFF6E7A90);
  static const Color inputFill = Color(0xFFF5F6F8);
  static const Color border = Color(0xFFE5E8EF);
  static const Color success = Color(0xFF18A957);
  static const Color error = Color(0xFFE24C4C);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}