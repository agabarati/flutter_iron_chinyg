// lib/presentation/themes/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Color(0xFF8B1E3F), // Бордовый цвет (осетинский)
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF8B1E3F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      colorScheme:
          ColorScheme.fromSwatch(
            primarySwatch: MaterialColor(0xFF8B1E3F, {
              50: Color(0xFFF9E6EB),
              100: Color(0xFFF0C1CD),
              200: Color(0xFFE698AF),
              300: Color(0xFFDB6F91),
              400: Color(0xFFD3507B),
              500: Color(0xFF8B1E3F), // Основной цвет
              600: Color(0xFF7D1B39),
              700: Color(0xFF6C1731),
              800: Color(0xFF5C1329),
              900: Color(0xFF3F0D1C),
            }),
          ).copyWith(
            secondary: Color(0xFFF4C542), // Золотой акцент
          ),
    );
  }
}
