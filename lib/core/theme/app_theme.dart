import 'package:flutter/material.dart';

class AppColors {
  static const goldPrimary  = Color(0xFFD4AF37);
  static const goldLight    = Color(0xFFF0CC5A);
  static const goldDark     = Color(0xFFA8860A);
  static const bgDeep       = Color(0xFF0E0E0E);
  static const bgCard       = Color(0xFF1A1A1A);
  static const bgElevated   = Color(0xFF242424);
  static const borderSubtle = Color(0xFF2E2E2E);
  static const textPrimary  = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF888888);
  static const success      = Color(0xFF4CAF50);
  static const warning      = Color(0xFFFF9800);
  static const error        = Color(0xFFF44336);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.goldPrimary,
        onPrimary: Colors.black,
        secondary: AppColors.goldLight,
        surface: AppColors.bgCard,
        onSurface: AppColors.textPrimary,
        error: Color(0xFFF44336),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF141414),
        selectedItemColor: AppColors.goldPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedColor: AppColors.goldPrimary.withValues(alpha: 0.2),
        side: const BorderSide(color: AppColors.borderSubtle),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.goldPrimary,
        foregroundColor: Colors.black,
      ),
    );
  }
}