import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,       // Use system theme with dynamic colors if available
  staticLight,  // Use static light theme
  staticDark,   // Use static dark theme
  customColor,  // Use custom color theme selected by user
}

// A callback type for theme change notifications
typedef ThemeChangeCallback = void Function();

class ThemeService {
  static const String _themeModeKey = 'themeMode';
  static const String _useDynamicColorsKey = 'useDynamicColors';
  static const String _customPrimaryColorKey = 'customPrimaryColor';
  static const String _useCustomColorInBothModesKey = 'useCustomColorInBothModes';
  // We'll only store primary color now and derive the others

  // Add a list of listeners to notify when theme changes
  static final List<ThemeChangeCallback> _listeners = [];

  // Method to add a listener
  static void addListener(ThemeChangeCallback listener) {
    _listeners.add(listener);
  }

  // Method to remove a listener
  static void removeListener(ThemeChangeCallback listener) {
    _listeners.remove(listener);
  }

  // Method to notify all listeners of a theme change
  static void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // Default colors for static themes
  // Old default colors
  static const Color _primaryLight = Color(0xFF6750A4);
  static const Color _secondaryLight = Color(0xFF625B71);
  static const Color _tertiaryLight = Color(0xFF7D5260);

  static const Color _primaryDark = Color(0xFFD0BCFF);
  static const Color _secondaryDark = Color(0xFFCCC2DC);
  static const Color _tertiaryDark = Color(0xFFEFB8C8);

  // Blue color scheme
  static const Color _blueLight = Color(0xFF2196F3);         // Primary light blue
  static const Color _blueLightVariant = Color(0xFF64B5F6);  // Lighter blue for secondary
  static const Color _blueLightAccent = Color(0xFF03A9F4);   // Accent blue for tertiary

  static const Color _blueDark = Color(0xFF90CAF9);          // Light blue for dark theme primary
  static const Color _blueDarkVariant = Color(0xFF42A5F5);   // Medium blue for dark theme secondary
  static const Color _blueDarkAccent = Color(0xFF29B6F6);    // Bright blue for dark theme tertiary

  // Default custom colors (if user hasn't set any)
  static const Color _defaultCustomPrimary = Color(0xFF9C27B0);    // Purple
  static const Color _defaultCustomSecondary = Color(0xFF673AB7);  // Deep Purple
  static const Color _defaultCustomTertiary = Color(0xFFE91E63);   // Pink

  // Get the current theme mode from shared preferences
  static Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeModeKey) ?? 0;
    return AppThemeMode.values[index];
  }

  // Save the current theme mode to shared preferences
  static Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners(); // Notify listeners when theme mode changes
  }

  // Convert AppThemeMode to Flutter's ThemeMode
  static ThemeMode getFlutterThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.staticLight:
        return ThemeMode.light;
      case AppThemeMode.staticDark:
        return ThemeMode.dark;
      case AppThemeMode.customColor:
        return ThemeMode.light; // Custom color uses light mode
    }
  }

  // NEW: Helper method to check if current theme is dark
  static Future<bool> isDarkMode(BuildContext context) async {
    final themeMode = await getThemeMode();
    
    switch (themeMode) {
      case AppThemeMode.system:
        // For system mode, use platform brightness
        return MediaQuery.of(context).platformBrightness == Brightness.dark;
      case AppThemeMode.staticDark:
        // For static dark mode, always return true
        return true;
      case AppThemeMode.staticLight:
      case AppThemeMode.customColor:
        // For light modes, always return false
        return false;
    }
  }

  // Generate a harmonious color scheme from a single primary color
  static ColorScheme generateColorSchemeFromPrimary(Color primaryColor, bool isDark) {
    // Convert to HSL for easier manipulation
    final HSLColor primaryHSL = HSLColor.fromColor(primaryColor);
    
    // Create complementary colors while maintaining the original hue
    final HSLColor secondaryHSL = primaryHSL.withSaturation(
      (primaryHSL.saturation * 0.8).clamp(0.2, 0.9)
    ).withLightness(
      (primaryHSL.lightness * 0.9).clamp(0.3, 0.8)
    );
    
    final HSLColor tertiaryHSL = primaryHSL.withHue(
      (primaryHSL.hue + 30) % 360
    ).withSaturation(
      (primaryHSL.saturation * 0.85).clamp(0.2, 0.9)
    );
    
    if (isDark) {
      // For dark theme, lighten colors instead of darkening
      final HSLColor darkPrimaryHSL = primaryHSL.withLightness(
        (primaryHSL.lightness * 1.3).clamp(0.4, 0.8)
      );
      
      return ColorScheme.dark(
        primary: darkPrimaryHSL.toColor(),
        secondary: secondaryHSL.withLightness(0.7).toColor(),
        tertiary: tertiaryHSL.withLightness(0.65).toColor(),
        onPrimary: Colors.white,
        primaryContainer: darkPrimaryHSL.withLightness(0.3).toColor(),
        onPrimaryContainer: Colors.white,
        secondaryContainer: secondaryHSL.withLightness(0.25).toColor(),
        onSecondaryContainer: Colors.white,
        tertiaryContainer: tertiaryHSL.withLightness(0.25).toColor(),
        onTertiaryContainer: Colors.white,
        surface: const Color(0xFF1E1E1E),
      );
    } else {
      // Light theme - maintain original color brightness
      return ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryHSL.toColor(),
        tertiary: tertiaryHSL.toColor(),
        onPrimary: _shouldUseWhiteText(primaryColor) ? Colors.white : Colors.black,
        primaryContainer: primaryHSL.withLightness(0.9).toColor(),
        onPrimaryContainer: primaryColor,
        secondaryContainer: secondaryHSL.withLightness(0.9).toColor(),
        onSecondaryContainer: secondaryHSL.toColor(),
        tertiaryContainer: tertiaryHSL.withLightness(0.9).toColor(),
        onTertiaryContainer: tertiaryHSL.toColor(),
      );
    }
  }

  // Add helper method to determine text color
  static bool _shouldUseWhiteText(Color color) {
    // Calculate relative luminance
    final double luminance = color.computeLuminance();
    return luminance < 0.5;
  }

  // Add method to validate color before saving
  static bool isValidCustomColor(Color color) {
    // Convert to HSL for better color validation
    final HSLColor hsl = HSLColor.fromColor(color);
    
    // Check for pure black (#000000)
    if (color.value == 0xFF000000) return false;
    
    // Check for pure white (#FFFFFF)
    if (color.value == 0xFFFFFFFF) return false;
    
    // Can also check for very dark or very light colors
    if (hsl.lightness < 0.1 || hsl.lightness > 0.9) return false;
    
    // Can also check for very low saturation (grayscale)
    if (hsl.saturation < 0.1) return false;
    
    return true;
  }

  // Modify setCustomColor to include validation
  static Future<bool> setCustomColor(Color color, String type) async {
    // We only store the primary color
    if (type == 'primary') {
      // Validate color before saving
      if (!isValidCustomColor(color)) {
        return false; // Color is not valid
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_customPrimaryColorKey, color.value);
      notifyListeners();
      return true; // Color was saved successfully
    }
    return false; // Invalid type
  }

  // Get the custom primary color from preferences
  static Future<Color> getCustomPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_customPrimaryColorKey);
    return colorValue != null ? Color(colorValue) : const Color(0xFF9C27B0); // Purple default
  }

  // Generate a random color with good saturation and lightness
  static Color _generateRandomColor() {
    final random = Random();
    
    // Use HSL to ensure vibrant, visually appealing colors
    // Hue: Any value between 0-360
    // Saturation: 60-90% for vibrant but not overwhelming colors
    // Lightness: 40-60% for medium brightness
    final hue = random.nextDouble() * 360;
    final saturation = 0.6 + (random.nextDouble() * 0.3); // 60-90%
    final lightness = 0.4 + (random.nextDouble() * 0.2);  // 40-60%
    
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  // Get light theme with optional dynamic color
  static Future<ThemeData> getLightTheme(bool useDynamicColors, ColorScheme? dynamicLightScheme) async {
    // If dynamic colors are available and enabled, use them
    if (useDynamicColors && dynamicLightScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: dynamicLightScheme,
        brightness: Brightness.light,
      );
    }
    
    // Get the current theme mode and custom color settings
    final themeMode = await getThemeMode();
    final useCustomColorInBothModes = await getUseCustomColorInBothModes();
    
    // For custom colors, load the user's custom primary color and generate scheme
    if (themeMode == AppThemeMode.customColor || 
        (useCustomColorInBothModes && themeMode != AppThemeMode.system)) {
      final primaryColor = await getCustomPrimaryColor();
      final colorScheme = generateColorSchemeFromPrimary(primaryColor, false);
      
      return ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        brightness: Brightness.light,
      );
    }
    
    // Generate random color scheme for system mode without dynamic colors
    if (themeMode == AppThemeMode.system && !useDynamicColors) {
      final randomPrimaryColor = _generateRandomColor();
      final colorScheme = generateColorSchemeFromPrimary(randomPrimaryColor, false);
      
      return ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        brightness: Brightness.light,
      );
    }
    
    // Otherwise use the blue color scheme
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: _blueLight,
        secondary: _blueLightVariant,
        tertiary: _blueLightAccent,
        onPrimary: Colors.white,
        primaryContainer: _blueLightVariant.withOpacity(0.3),
        onPrimaryContainer: _blueLight,
        secondaryContainer: _blueLightAccent.withOpacity(0.2),
        onSecondaryContainer: _blueLightVariant.withOpacity(0.8),
        tertiaryContainer: _blueLightVariant.withOpacity(0.2),
        onTertiaryContainer: _blueLightAccent,
      ),
      brightness: Brightness.light,
    );
  }

  // Get dark theme with optional dynamic color
  static ThemeData getDarkTheme(bool useDynamicColors, ColorScheme? dynamicDarkScheme) {
    // If dynamic colors are available and enabled, use them
    if (useDynamicColors && dynamicDarkScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: dynamicDarkScheme,
        brightness: Brightness.dark,
      );
    }
    
    // We'll use the blue color scheme as the default
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: _blueDark,
        secondary: _blueDarkVariant,
        tertiary: _blueDarkAccent,
        onPrimary: Colors.black,
        primaryContainer: _blueDarkVariant.withOpacity(0.3),
        onPrimaryContainer: Colors.white,
        secondaryContainer: _blueDarkAccent.withOpacity(0.3),
        onSecondaryContainer: Colors.white,
        tertiaryContainer: _blueDarkVariant.withOpacity(0.2),
        onTertiaryContainer: Colors.white,
        surface: const Color(0xFF1E1E1E),
      ),
      brightness: Brightness.dark,
    );
  }

  // Update this to use the new color scheme generation for custom dark theme
  static Future<ThemeData> getDarkThemeAsync(bool useDynamicColors, ColorScheme? dynamicColorScheme) async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = await getThemeMode();
    final useCustomColorInBothModes = await getUseCustomColorInBothModes();
    
    ColorScheme colorScheme;
    
    if (useDynamicColors && dynamicColorScheme != null) {
      colorScheme = dynamicColorScheme;
    } else if (themeMode == AppThemeMode.customColor || useCustomColorInBothModes) {
      // Use custom color for dark theme
      final customColorValue = prefs.getInt(_customPrimaryColorKey);
      final customColor = customColorValue != null 
          ? Color(customColorValue) 
          : _defaultCustomPrimary;
          
      final adjustedColor = _adjustColorForDarkTheme(customColor);
      
      colorScheme = ColorScheme.dark(
        primary: adjustedColor,
        primaryContainer: adjustedColor.withOpacity(0.7),
        secondary: adjustedColor.withOpacity(0.8),
        secondaryContainer: adjustedColor.withOpacity(0.3),
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        error: Colors.red[700]!,
      );
    } else {
      // Use default dark theme colors
      colorScheme = ColorScheme.dark(
        primary: _blueDark,
        secondary: _blueDarkVariant,
        tertiary: _blueDarkAccent,
        // ...rest of default dark theme colors...
      );
    }

    return _buildThemeData(colorScheme, true);
  }

  // Add helper method to adjust colors for dark theme
  static Color _adjustColorForDarkTheme(Color color) {
    final hslColor = HSLColor.fromColor(color);
    
    // Skip conversion for grayscale colors (black/white)
    if (hslColor.saturation < 0.1) {
      // Return a default dark theme color instead
      return const Color(0xFF2196F3); // Default to blue
    }
    
    // For other colors, adjust brightness for dark theme
    return HSLColor.fromAHSL(
      color.alpha / 255.0,
      hslColor.hue,
      hslColor.saturation,
      0.6, // Set fixed lightness for dark theme
    ).toColor();
  }

  static ThemeData _buildThemeData(ColorScheme colorScheme, bool isDark) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colorScheme.background,
      cardColor: isDark 
          ? const Color(0xFF2D2D2D)
          : colorScheme.surface,
      // Remove surfaceTintColor property since it's not available
    );
  }

  // Add method to check if a color is grayscale
  static bool isGrayscaleColor(Color color) {
    final hslColor = HSLColor.fromColor(color);
    return hslColor.saturation < 0.1;
  }

  // Check if we should use dynamic colors
  static Future<bool> getUseDynamicColors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useDynamicColorsKey) ?? true;
  }

  // Set whether to use dynamic colors
  static Future<void> setUseDynamicColors(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDynamicColorsKey, value);
    notifyListeners(); // Notify listeners when dynamic colors setting changes
  }

  // Check if custom colors should be used in both dark and light modes
  static Future<bool> getUseCustomColorInBothModes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useCustomColorInBothModesKey) ?? false;
  }
  
  // Set whether to use custom colors in both dark and light modes
  static Future<void> setUseCustomColorInBothModes(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useCustomColorInBothModesKey, value);
    notifyListeners();
  }
}