/// AURA Theme
/// Pastel blue neumorphic design system for autism therapy app

import 'package:flutter/material.dart';

class AuraTheme {
  // Primary Colors
  static const Color primaryPastelBlue = Color(0xFFE3F2FD);
  static const Color accentCornflower = Color(0xFF90CAF9);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F9FF);
  
  // Text Colors
  static const Color textDark = Color(0xFF37474F);
  static const Color textMedium = Color(0xFF607D8B);
  static const Color textLight = Color(0xFF90A4AE);
  
  // Game Card Colors
  static const Color gameG1 = Color(0xFFE3F2FD); // Magnet Catch
  static const Color gameG2 = Color(0xFFF3E5F5); // Sound Match
  static const Color gameG3 = Color(0xFFE8F5E9); // Invisible Maze
  static const Color gameG4 = Color(0xFFFFF3E0); // Jumping Numbers
  static const Color gameG5 = Color(0xFFE1F5FE); // Alphabet Fish
  static const Color gameG6 = Color(0xFFFCE4EC); // Emotion Slider
  static const Color gameG7 = Color(0xFFFFFDE7); // Simon Says
  static const Color gameG8 = Color(0xFFE0F7FA); // Glow Race
  
  // Neumorphic Shadow Colors
  static const Color shadowLight = Colors.white;
  static const Color shadowDark = Color(0xFFD1D9E6);
  
  // Status Colors
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFEF5350);
  
  // Border Radius
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 28.0;
  static const double radiusXLarge = 40.0;
  
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // Get game color by ID
  static Color getGameColor(String gameId) {
    switch (gameId) {
      case 'G1': return gameG1;
      case 'G2': return gameG2;
      case 'G3': return gameG3;
      case 'G4': return gameG4;
      case 'G5': return gameG5;
      case 'G6': return gameG6;
      case 'G7': return gameG7;
      case 'G8': return gameG8;
      default: return primaryPastelBlue;
    }
  }
  
  // Get game icon by ID
  static IconData getGameIcon(String gameId) {
    switch (gameId) {
      case 'G1': return Icons.catching_pokemon;
      case 'G2': return Icons.music_note_rounded;
      case 'G3': return Icons.grid_view_rounded;
      case 'G4': return Icons.pin_rounded;
      case 'G5': return Icons.text_fields_rounded;
      case 'G6': return Icons.emoji_emotions_rounded;
      case 'G7': return Icons.gamepad_rounded;
      case 'G8': return Icons.lightbulb_rounded;
      default: return Icons.games_rounded;
    }
  }
  
  // Custom TextStyle for child-friendly rounded font
  static TextStyle get _baseTextStyle => const TextStyle(
    fontFamily: 'Segoe UI',
    letterSpacing: 0.2,
  );
  
  // Theme Data
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentCornflower,
        brightness: Brightness.light,
        primary: accentCornflower,
        surface: backgroundWhite,
      ),
      scaffoldBackgroundColor: surfaceLight,
      fontFamily: 'Segoe UI',
      textTheme: TextTheme(
        displayLarge: _baseTextStyle.copyWith(fontSize: 57, fontWeight: FontWeight.w400, color: textDark),
        displayMedium: _baseTextStyle.copyWith(fontSize: 45, fontWeight: FontWeight.w400, color: textDark),
        displaySmall: _baseTextStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w400, color: textDark),
        headlineLarge: _baseTextStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w600, color: textDark),
        headlineMedium: _baseTextStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: textDark),
        headlineSmall: _baseTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: textDark),
        titleLarge: _baseTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w500, color: textDark),
        titleMedium: _baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: textDark),
        titleSmall: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: textDark),
        bodyLarge: _baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: textDark),
        bodyMedium: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: textDark),
        bodySmall: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: textMedium),
        labelLarge: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: textDark),
        labelMedium: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: textDark),
        labelSmall: _baseTextStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: textMedium),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundWhite,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _baseTextStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCornflower,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: _baseTextStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: backgroundWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentCornflower,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// Neumorphic Box Decoration
BoxDecoration neumorphicDecoration({
  Color color = AuraTheme.backgroundWhite,
  double radius = AuraTheme.radiusMedium,
  bool isPressed = false,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: isPressed
        ? [
            BoxShadow(
              color: AuraTheme.shadowDark.withAlpha((0.15 * 255).round()),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ]
        : [
            const BoxShadow(
              color: AuraTheme.shadowLight,
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: AuraTheme.shadowDark.withAlpha((0.25 * 255).round()),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
          ],
  );
}

// Neumorphic Inset Decoration (simplified without inset shadows for compatibility)
BoxDecoration neumorphicInsetDecoration({
  Color color = AuraTheme.surfaceLight,
  double radius = AuraTheme.radiusMedium,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AuraTheme.shadowDark.withAlpha((0.1 * 255).round()),
      width: 1,
    ),
  );
}
