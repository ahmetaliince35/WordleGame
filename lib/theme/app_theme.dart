import 'package:flutter/material.dart';

class GameColors {
  // Soft, harmonious, low-contrast palette as requested by the user

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF2C3539);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFD7DCE2);
  static const Color lightBorderActive = Color(0xFFA0AEC0);

  // Dark Mode Colors (gentle dark slate, not harsh pitch black)
  static const Color darkBackground = Color(0xFF1E232A);
  static const Color darkSurface = Color(0xFF272D36);
  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFF3B4350);
  static const Color darkBorderActive = Color(0xFF5A6678);

  // Soft Tile States (Natural, harmonious, eye-pleasing tones)
  // Correct (Doğru yer): Soft Eucalyptus / Sage Green
  static const Color correctLight = Color(0xFF729E74);
  static const Color correctDark = Color(0xFF5E8B60);

  // Present (Yanlış yer): Soft Warm Sand / Muted Honey Ochre (not neon yellow)
  static const Color presentLight = Color(0xFFD4A364);
  static const Color presentDark = Color(0xFFB88950);

  // Absent (Kelimede yok): Soft Slate Grey
  static const Color absentLight = Color(0xFF9BA6B2);
  static const Color absentDark = Color(0xFF566270);

  // Keyboard
  static const Color keyBgLight = Color(0xFFE2E7ED);
  static const Color keyBgDark = Color(0xFF333B46);
  static const Color keySpecialBgLight = Color(0xFFD5DCE4);
  static const Color keySpecialBgDark = Color(0xFF404A58);

  // Accent / Pill
  static const Color accentPill = Color(0xFF6B9372);
}

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: GameColors.lightBackground,
      colorScheme: const ColorScheme.light(
        surface: GameColors.lightSurface,
        primary: GameColors.correctLight,
        secondary: GameColors.presentLight,
        onSurface: GameColors.lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GameColors.lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: GameColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: GameColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GameColors.lightSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GameColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        surface: GameColors.darkSurface,
        primary: GameColors.correctDark,
        secondary: GameColors.presentDark,
        onSurface: GameColors.darkTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GameColors.darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: GameColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: GameColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GameColors.darkSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
