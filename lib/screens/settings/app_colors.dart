import 'package:flutter/material.dart';

class AppColors {
  // Основной зелёный
  static const Color primary = Color(0xFF50D14D);
  static const Color primaryLight = Color(0xFF7FE57C);
  static const Color primaryDark = Color(0xFF3AA839);

  // Акцент
  static const Color accent = Color(0xFF54FF52);
  static const Color accentLight = Color(0xFFCAFFC9);

  // Фоны
  static const Color scaffoldBackground = Color(0xFFF5FFF5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFEBFFEB);

  // Текст
  static const Color textPrimary = Color(0xFF1E2A1E);
  static const Color textSecondary = Color(0xFF556B55);
  static const Color textHint = Color(0xFF88AA88);

  // Статусы
  static const Color success = Color(0xFF50D14D);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFE57373);

  // Дополнительно
  static const Color divider = Color(0xFFB2D8B2);

  // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: Используем fromSeed с твоим primary, но фиксируем всё
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true, // Включаем Material 3
    brightness: Brightness.light,

    // Отключаем динамические цвета и фиксируем нашу палитру
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
      background: scaffoldBackground,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      onError: Colors.white,
      brightness: Brightness.light,
    ),

    scaffoldBackgroundColor: scaffoldBackground,
    cardColor: cardBackground,

    textTheme: TextTheme(
      headlineMedium: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
      bodyLarge: const TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      labelLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // для кнопок
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: primary.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: divider.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textHint),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.black,
    ),
  );
}