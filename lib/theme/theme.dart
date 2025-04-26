import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static final themeData = {
    'Green': ThemeSet(
      seed: const Color(0xFF00875A), // Primary green
      light: (brightness) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF00875A),
        brightness: brightness,
        primary: const Color(0xFF00875A),
        secondary: const Color(0xFF4CAF50),
        tertiary: const Color(0xFF66BB6A),
        background: const Color(0xFFF5F5F5),
      ),
      dark: (brightness) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF00875A),
        brightness: brightness,
        primary: const Color(0xFF00C853),
        secondary: const Color(0xFF69F0AE),
        tertiary: const Color(0xFF00E676),
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
      ),
    ),
    'Blue': ThemeSet(
      seed: const Color(0xFF1A73E8),
      light: (brightness) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A73E8),
        brightness: brightness,
      ),
      dark: (brightness) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A73E8),
        brightness: brightness,
      ),
    ),
    'Purple': ThemeSet(
      seed: const Color(0xFF673AB7),
      light: (brightness) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF673AB7),
        brightness: brightness,
      ),
      dark: (brightness) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF673AB7),
        brightness: brightness,
      ),
    ),
  };

  static var lightTheme;

  static ThemeData getThemeData(ColorScheme? dynamicColorScheme, ThemeSet themeSet, Brightness brightness, bool useSystemColors) {
    // Only use dynamic colors when explicitly following system theme
    final colorScheme = useSystemColors && dynamicColorScheme != null
        ? dynamicColorScheme
        : (brightness == Brightness.light 
            ? themeSet.light(brightness) 
            : themeSet.dark(brightness));

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: brightness,
      applyElevationOverlayColor: brightness == Brightness.dark,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontFamily: 'AppFont',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  static String getCurrentThemeName(SharedPreferences prefs) {
    return prefs.getString('themeName') ?? 'Blue';
  }

  static Future<void> saveThemeName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeName', name);
  }
}

class ThemeSet {
  final Color seed;
  final ColorScheme Function(Brightness) light;
  final ColorScheme Function(Brightness) dark;

  ThemeSet({
    required this.seed,
    required this.light,
    required this.dark,
  });
}
