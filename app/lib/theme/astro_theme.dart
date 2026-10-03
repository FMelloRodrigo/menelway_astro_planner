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
      iconTheme: const IconThemeData(
        color: Colors.white,
        size: 20,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.9),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AstroColors.spaceDarkSurface,
        selectedIconTheme: const IconThemeData(color: AstroColors.starlightCyan, size: 24),
        unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.65), size: 24),
        selectedLabelTextStyle: const TextStyle(color: AstroColors.starlightCyan, fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
        indicatorColor: AstroColors.starlightCyan.withValues(alpha: 0.18),
      ),
      extensions: const [AstroPalette.defaultDark],
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
      iconTheme: const IconThemeData(
        color: AstroColors.nightVisionRed,
        size: 20,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AstroColors.nightVisionRed,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AstroColors.nightVisionSurface,
        selectedIconTheme: const IconThemeData(color: AstroColors.nightVisionRed, size: 24),
        unselectedIconTheme: IconThemeData(color: AstroColors.nightVisionRedDim.withValues(alpha: 0.8), size: 24),
        selectedLabelTextStyle: const TextStyle(color: AstroColors.nightVisionRed, fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: AstroColors.nightVisionRedDim.withValues(alpha: 0.8), fontSize: 12),
        indicatorColor: AstroColors.nightVisionRed.withValues(alpha: 0.2),
      ),
      extensions: const [AstroPalette.defaultRed],
    );
  }
}

/// ThemeExtension to encapsulate the active theme palette and eliminate parameter drilling.
@immutable
class AstroPalette extends ThemeExtension<AstroPalette> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color accent;
  final Color text;
  final Color textDim;
  final Color starGold;
  final Color nebulaIndigo;
  final Color deepSkyTeal;
  final Color visibleGreen;
  final bool isRedNightMode;

  const AstroPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.accent,
    required this.text,
    required this.textDim,
    required this.starGold,
    required this.nebulaIndigo,
    required this.deepSkyTeal,
    required this.visibleGreen,
    required this.isRedNightMode,
  });

  Color get textPrimary => text;
  Color get textSecondary => textDim;
  Color get textTertiary => textDim.withValues(alpha: 0.6);
  Color get starlightCyan => isRedNightMode ? accent : AstroColors.starlightCyan;

  static AstroPalette of(BuildContext context) {
    return Theme.of(context).extension<AstroPalette>() ?? defaultDark;
  }

  static const defaultDark = AstroPalette(
    background: AstroColors.spaceDarkBackground,
    surface: AstroColors.spaceDarkSurface,
    surfaceVariant: AstroColors.spaceDarkSurfaceVariant,
    border: AstroColors.spaceDarkBorder,
    accent: AstroColors.starlightCyan,
    text: Colors.white,
    textDim: Color(0xB3FFFFFF),
    starGold: AstroColors.starGold,
    nebulaIndigo: AstroColors.nebulaIndigo,
    deepSkyTeal: AstroColors.deepSkyTeal,
    visibleGreen: AstroColors.visibleGreen,
    isRedNightMode: false,
  );

  static const defaultRed = AstroPalette(
    background: AstroColors.nightVisionBackground,
    surface: AstroColors.nightVisionSurface,
    surfaceVariant: AstroColors.nightVisionSurfaceVariant,
    border: AstroColors.nightVisionBorder,
    accent: AstroColors.nightVisionRed,
    text: AstroColors.nightVisionRed,
    textDim: AstroColors.nightVisionRedDim,
    starGold: AstroColors.nightVisionRed,
    nebulaIndigo: AstroColors.nightVisionRedDim,
    deepSkyTeal: AstroColors.nightVisionRed,
    visibleGreen: AstroColors.nightVisionRed,
    isRedNightMode: true,
  );

  @override
  AstroPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? accent,
    Color? text,
    Color? textDim,
    Color? starGold,
    Color? nebulaIndigo,
    Color? deepSkyTeal,
    Color? visibleGreen,
    bool? isRedNightMode,
  }) {
    return AstroPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      starGold: starGold ?? this.starGold,
      nebulaIndigo: nebulaIndigo ?? this.nebulaIndigo,
      deepSkyTeal: deepSkyTeal ?? this.deepSkyTeal,
      visibleGreen: visibleGreen ?? this.visibleGreen,
      isRedNightMode: isRedNightMode ?? this.isRedNightMode,
    );
  }

  @override
  AstroPalette lerp(ThemeExtension<AstroPalette>? other, double t) {
    if (other is! AstroPalette) return this;
    return AstroPalette(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t) ?? surfaceVariant,
      border: Color.lerp(border, other.border, t) ?? border,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      text: Color.lerp(text, other.text, t) ?? text,
      textDim: Color.lerp(textDim, other.textDim, t) ?? textDim,
      starGold: Color.lerp(starGold, other.starGold, t) ?? starGold,
      nebulaIndigo: Color.lerp(nebulaIndigo, other.nebulaIndigo, t) ?? nebulaIndigo,
      deepSkyTeal: Color.lerp(deepSkyTeal, other.deepSkyTeal, t) ?? deepSkyTeal,
      visibleGreen: Color.lerp(visibleGreen, other.visibleGreen, t) ?? visibleGreen,
      isRedNightMode: t < 0.5 ? isRedNightMode : other.isRedNightMode,
    );
  }
}
