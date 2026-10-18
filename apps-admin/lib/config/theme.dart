import 'package:flutter/material.dart';

/// Same palette as the customer app (apps/lib/config/theme.dart).
class AppColors {
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryForeground = Color(0xFFFAFBFE);
  static const Color accent = Color(0xFFFA6E1D);
  static const Color destructive = Color(0xFFE60016);
  static const Color success = Color(0xFF13A147);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);
  static const Color surface = Color(0xFFF0F4F9);
  static const Color mutedForeground = Color(0xFF5D646F);
  static const Color foreground = Color(0xFF161B24);
  static const Color border = Color(0xFFD9DEE6);
  static const Color background = Color(0xFFFCFDFE);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      error: AppColors.destructive,
      surface: Colors.white,
      onSurface: AppColors.foreground,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.mutedForeground,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.primary : AppColors.mutedForeground);
        }),
      ),
    );
  }
}
