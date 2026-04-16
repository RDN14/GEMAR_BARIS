import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF7ED6A5);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(centerTitle: true),
      inputDecorationTheme: const InputDecorationTheme(
        border: UnderlineInputBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        ),
      ),
    );
  }
}