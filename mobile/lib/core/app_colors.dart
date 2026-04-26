import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF7F1EA);
  static const Color darkBackground = Color(0xFF1B120B);
  static const Color darkCard = Color(0xFF24160D);
  static const Color primary = Color(0xFFFFB26B);
  static const Color secondary = Color(0xFF8EDBFF);
  static const Color textDark = Color(0xFF2A140A);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
