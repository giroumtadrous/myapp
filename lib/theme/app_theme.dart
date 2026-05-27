import 'package:flutter/material.dart';

class AppTheme {
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0B0F0C);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Shared Colors
  static const Color background = Color(0xFF0B0F0C);
  static const Color surface = Color(0xFF111827);
  static const Color primary = Color(0xFF22C55E);
  static const Color accent = Color(0xFF4ADE80);
  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary],
  );

  static BorderSide border({double width = 1, bool isDark = true}) {
    final color = isDark
        ? primary.withValues(alpha: 0.22)
        : primary.withValues(alpha: 0.14);
    return BorderSide(color: color, width: width);
  }

  static List<BoxShadow> glow({double alpha = 0.2}) {
    return [
      BoxShadow(
        color: primary.withValues(alpha: alpha),
        blurRadius: 18,
        spreadRadius: 0,
      ),
    ];
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      isDark: true,
      background: darkBackground,
      surface: darkSurface,
      textPrimary: darkTextPrimary,
      textSecondary: darkTextSecondary,
    );
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      isDark: false,
      background: lightBackground,
      surface: lightSurface,
      textPrimary: lightTextPrimary,
      textSecondary: lightTextSecondary,
    );
  }

  static ThemeData _buildTheme({
    required bool isDark,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final borderSideLight = BorderSide(
      color: isDark ? primary.withValues(alpha: 0.22) : primary.withValues(alpha: 0.14),
      width: 1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              secondary: accent,
              surface: surface,
              onPrimary: background,
              onSecondary: background,
              onSurface: textPrimary,
              error: primary,
            )
          : ColorScheme.light(
              primary: primary,
              secondary: accent,
              surface: surface,
              onPrimary: lightBackground,
              onSecondary: lightBackground,
              onSurface: textPrimary,
              error: primary,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: borderSideLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: borderSideLight,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: borderSideLight,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
        hintStyle: TextStyle(color: textSecondary),
        prefixIconColor: primary,
        suffixIconColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? darkBackground : lightBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: borderSideLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
