import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF1A3A4A);
  static const teal = Color(0xFF2A7D8C);
  static const tealLight = Color(0xFFE0F3F6);
  static const amber = Color(0xFFE07B3A);
  static const amberLight = Color(0xFFFEF0E7);
  static const green = Color(0xFF2E8B57);
  static const greenBg = Color(0xFFE8F5EE);
  static const yellow = Color(0xFFC89020);
  static const yellowBg = Color(0xFFFEF9E6);
  static const red = Color(0xFFC0392B);
  static const redBg = Color(0xFFFDE8E6);
  static const bg = Color(0xFFF0F5F9);
  static const muted = Color(0xFF7A9AAA);
  static const border = Color(0xFFDDE8EE);
  // SpO2
  static const oxygenNormal = Color(0xFF1565C0);
  static const oxygenNormalBg = Color(0xFFE3F0FF);
  static const oxygenLow = Color(0xFFF57F17);
  static const oxygenLowBg = Color(0xFFFFF3E0);
  static const oxygenCritical = Color(0xFFC62828);
  static const oxygenCriticalBg = Color(0xFFFDE8E6);
}

const kSpo2NormalMin = 95;
const kSpo2LowMin = 90;

const kMoments = ['Ayuno', 'Antes comida', 'Después comida', 'Noche'];
const kMomentIcons = {
  'Ayuno': '🌅',
  'Antes comida': '🍽️',
  'Después comida': '⏱️',
  'Noche': '🌙',
};
const kInsulinTypes = ['Rápida', 'Lenta / Basal', 'Mixta', 'Otra'];

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.amber,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.teal,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
