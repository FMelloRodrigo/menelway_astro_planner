import 'package:flutter/material.dart';

class AstroColors {
  // Deep Space Dark Palette
  static const Color spaceDarkBackground = Color(0xFF0B0E14);
  static const Color spaceDarkSurface = Color(0xFF131A26);
  static const Color spaceDarkSurfaceVariant = Color(0xFF1E2838);
  static const Color spaceDarkBorder = Color(0xFF2B3A4E);

  static const Color starlightCyan = Color(0xFF38BDF8);
  static const Color nebulaIndigo = Color(0xFF818CF8);
  static const Color starGold = Color(0xFFFBBF24);
  static const Color deepSkyTeal = Color(0xFF2DD4BF);
  static const Color visibleGreen = Color(0xFF34D399);

  // Red Night Vision Mode (for telescope dark adaptation)
  static const Color nightVisionBackground = Color(0xFF060101);
  static const Color nightVisionSurface = Color(0xFF180303);
  static const Color nightVisionSurfaceVariant = Color(0xFF2C0707);
  static const Color nightVisionBorder = Color(0xFF4C0E0E);
  static const Color nightVisionRed = Color(0xFFEF4444);
  static const Color nightVisionRedDim = Color(0xFF991B1B);
}

class AstroTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AstroColors.spaceDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AstroColors.starlightCyan,
        secondary: AstroColors.nebulaIndigo,
        tertiary: AstroColors.starGold,
        surface: AstroColors.spaceDarkSurface,
        surfaceContainerHighest: AstroColors.spaceDarkSurfaceVariant,
        outline: AstroColors.spaceDarkBorder,
      ),
      cardTheme: CardThemeData(
        color: AstroColors.spaceDarkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AstroColors.spaceDarkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AstroColors.spaceDarkBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AstroColors.spaceDarkSurfaceVariant,
        selectedColor: AstroColors.starlightCyan.withValues(alpha: 0.2),
        side: const BorderSide(color: AstroColors.spaceDarkBorder),
        labelStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AstroColors.spaceDarkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AstroColors.spaceDarkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AstroColors.spaceDarkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AstroColors.starlightCyan, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  static ThemeData redNightVisionTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AstroColors.nightVisionBackground,
      colorScheme: const ColorScheme.dark(
        primary: AstroColors.nightVisionRed,
        secondary: AstroColors.nightVisionRedDim,
        surface: AstroColors.nightVisionSurface,
        surfaceContainerHighest: AstroColors.nightVisionSurfaceVariant,
        outline: AstroColors.nightVisionBorder,
      ),
      cardTheme: CardThemeData(
        color: AstroColors.nightVisionSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AstroColors.nightVisionBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AstroColors.nightVisionBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AstroColors.nightVisionRed,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AstroColors.nightVisionRed),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AstroColors.nightVisionSurfaceVariant,
        selectedColor: AstroColors.nightVisionRed.withValues(alpha: 0.25),
        side: const BorderSide(color: AstroColors.nightVisionBorder),
        labelStyle: const TextStyle(fontSize: 12, color: AstroColors.nightVisionRed),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AstroColors.nightVisionSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AstroColors.nightVisionBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AstroColors.nightVisionBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AstroColors.nightVisionRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AstroColors.nightVisionRedDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AstroColors.nightVisionRed),
        bodyMedium: TextStyle(color: AstroColors.nightVisionRed),
        titleMedium: TextStyle(color: AstroColors.nightVisionRed),
        titleLarge: TextStyle(color: AstroColors.nightVisionRed),
      ),
    );
  }
}
