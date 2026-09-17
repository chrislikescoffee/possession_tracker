import 'package:flutter/material.dart';

/// Available Color Palettes for Possession Tracker
enum AppColorPreset {
  classicIndigo(
    id: 'classic_indigo',
    displayName: 'Classic Indigo',
    description: 'Electric indigo & cyan with deep navy slate',
    primary: Color(0xFF6366F1),
    primaryLight: Color(0xFF818CF8),
    secondary: Color(0xFF06B6D4),
    tertiary: Color(0xFF10B981),
    darkBg: Color(0xFF0B0F19),
    darkSurface: Color(0xFF131B2E),
    darkCard: Color(0xFF182238),
    darkBorder: Color(0xFF263352),
  ),
  joyfulSunset(
    id: 'joyful_sunset',
    displayName: 'Joyful Sunset',
    description: 'Warm coral, golden amber, & pastel sunset tones',
    primary: Color(0xFFFF6B6B),
    primaryLight: Color(0xFFFFA07A),
    secondary: Color(0xFFFFB300),
    tertiary: Color(0xFF4ECDC4),
    darkBg: Color(0xFF140D15),
    darkSurface: Color(0xFF221524),
    darkCard: Color(0xFF2E1C30),
    darkBorder: Color(0xFF4A2D4F),
  ),
  freshEmerald(
    id: 'fresh_emerald',
    displayName: 'Fresh Emerald',
    description: 'Lush botanical emerald, mint & bright lime',
    primary: Color(0xFF10B981),
    primaryLight: Color(0xFF34D399),
    secondary: Color(0xFF06B6D4),
    tertiary: Color(0xFF84CC16),
    darkBg: Color(0xFF081410),
    darkSurface: Color(0xFF0F231D),
    darkCard: Color(0xFF143027),
    darkBorder: Color(0xFF1E483A),
  ),
  candyPlayful(
    id: 'candy_playful',
    displayName: 'Candy Pastel',
    description: 'Playful lilac, bubblegum pink & vibrant turquoise',
    primary: Color(0xFFA855F7),
    primaryLight: Color(0xFFC084FC),
    secondary: Color(0xFF06B6D4),
    tertiary: Color(0xFFEC4899),
    darkBg: Color(0xFF120E1C),
    darkSurface: Color(0xFF1D172E),
    darkCard: Color(0xFF28203F),
    darkBorder: Color(0xFF3E3160),
  ),
  oceanBreeze(
    id: 'ocean_breeze',
    displayName: 'Ocean Breeze',
    description: 'Vivid azure, sky blue & seafoam green',
    primary: Color(0xFF0284C7),
    primaryLight: Color(0xFF38BDF8),
    secondary: Color(0xFF14B8A6),
    tertiary: Color(0xFFF59E0B),
    darkBg: Color(0xFF0A121A),
    darkSurface: Color(0xFF101E2C),
    darkCard: Color(0xFF162A3D),
    darkBorder: Color(0xFF22405C),
  ),
  amberGlow(
    id: 'amber_glow',
    displayName: 'Amber Honey',
    description: 'Warm glowing amber, orange blossom & dark bronze',
    primary: Color(0xFFF59E0B),
    primaryLight: Color(0xFFFBBF24),
    secondary: Color(0xFFF97316),
    tertiary: Color(0xFF10B981),
    darkBg: Color(0xFF14110A),
    darkSurface: Color(0xFF211C11),
    darkCard: Color(0xFF2E2617),
    darkBorder: Color(0xFF453923),
  );

  final String id;
  final String displayName;
  final String description;
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color tertiary;
  final Color darkBg;
  final Color darkSurface;
  final Color darkCard;
  final Color darkBorder;

  const AppColorPreset({
    required this.id,
    required this.displayName,
    required this.description,
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.tertiary,
    required this.darkBg,
    required this.darkSurface,
    required this.darkCard,
    required this.darkBorder,
  });

  static AppColorPreset fromId(String? id) {
    return AppColorPreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => AppColorPreset.classicIndigo,
    );
  }
}

class AppTheme {
  // Constant accents
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Light Mode base Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark text
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  /// Builds a dark ThemeData dynamically configured with the chosen preset
  static ThemeData buildDarkTheme(AppColorPreset preset) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: preset.darkBg,
      primaryColor: preset.primary,
      colorScheme: ColorScheme.dark(
        primary: preset.primary,
        primaryContainer: preset.primary.withValues(alpha: 0.2),
        secondary: preset.secondary,
        secondaryContainer: preset.secondary.withValues(alpha: 0.2),
        tertiary: preset.tertiary,
        surface: preset.darkSurface,
        error: accentRose,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: preset.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: preset.darkBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: preset.darkSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: preset.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: preset.darkSurface,
        selectedItemColor: preset.primaryLight,
        unselectedItemColor: darkTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: preset.darkSurface,
        selectedIconTheme: IconThemeData(color: preset.primaryLight),
        unselectedIconTheme: const IconThemeData(color: darkTextMuted),
        selectedLabelTextStyle: TextStyle(color: preset.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelTextStyle: const TextStyle(color: darkTextMuted, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: preset.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: preset.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: preset.darkBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: preset.darkCard,
        side: BorderSide(color: preset.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(color: darkTextPrimary, fontSize: 13),
      ),
    );
  }

  /// Builds a light ThemeData dynamically configured with the chosen preset
  static ThemeData buildLightTheme(AppColorPreset preset) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: preset.primary,
      colorScheme: ColorScheme.light(
        primary: preset.primary,
        primaryContainer: preset.primary.withValues(alpha: 0.12),
        secondary: preset.secondary,
        secondaryContainer: preset.secondary.withValues(alpha: 0.12),
        tertiary: preset.tertiary,
        surface: lightSurface,
        error: accentRose,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: lightTextPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: preset.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: preset.primary,
        unselectedItemColor: lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightSurface,
        selectedIconTheme: IconThemeData(color: preset.primary),
        unselectedIconTheme: const IconThemeData(color: lightTextMuted),
        selectedLabelTextStyle: TextStyle(color: preset.primary, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelTextStyle: const TextStyle(color: lightTextMuted, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 14),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Backwards compatibility getters
  static ThemeData get darkTheme => buildDarkTheme(AppColorPreset.classicIndigo);
  static ThemeData get lightTheme => buildLightTheme(AppColorPreset.classicIndigo);
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkCard = Color(0xFF182238);
  static const Color darkBorder = Color(0xFF263352);
}
