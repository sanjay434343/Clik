import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:math';

class SettingsPage extends StatefulWidget {
  final Function onThemeChanged;

  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppThemeMode _currentThemeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  bool _useCustomColorInBothModes = false;
  
  // Only track primary color now
  Color _primaryColor = Colors.purple;
  bool _isLoadingColors = true;

  // Add these predefined colors
  final List<Color> _predefinedColors = [
    // Pastel/Light Colors
    const Color(0xFFFFB5B5), // Baby Pink
    const Color(0xFFFFCCE6), // Light Pink
    const Color(0xFFB5EAEA), // Baby Blue
    const Color(0xFF98E4FF), // Sky Blue
    const Color(0xFFB5EAD7), // Mint Green
    const Color(0xFFFFFCD1), // Light Yellow
    const Color(0xFFE6E6FA), // Lavender
    const Color(0xFFFFDAB9), // Peach
    const Color(0xFFFFB6C1), // Light Rose
    const Color(0xFFADD8E6), // Light Blue
    
    // Material Colors (Regular)
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    
    // Vivid Colors
    const Color(0xFFFF1E1E), // Bright Red
    const Color(0xFF1E90FF), // Dodger Blue
    const Color(0xFF32CD32), // Lime Green
    const Color(0xFFFF69B4), // Hot Pink
    const Color(0xFF00CED1), // Dark Turquoise
    const Color(0xFFFF8C00), // Dark Orange
    const Color(0xFF8A2BE2), // Blue Violet
    const Color(0xFF20B2AA), // Light Sea Green
    
    // Soft/Muted Colors
    const Color(0xFF89CFF0), // Baby Blue
    const Color(0xFFF0E68C), // Khaki
    const Color(0xFFDDA0DD), // Plum
    const Color(0xFF98FB98), // Pale Green
    const Color(0xFFDEB887), // Burlywood
    const Color(0xFFF08080), // Light Coral
    
    // Deep/Rich Colors
    const Color(0xFF800000), // Maroon
    const Color(0xFF000080), // Navy
    const Color(0xFF006400), // Dark Green
    const Color(0xFF800080), // Purple
    const Color(0xFF8B4513), // Saddle Brown
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoadingColors = true);
    
    final themeMode = await ThemeService.getThemeMode();
    final useDynamicColors = await ThemeService.getUseDynamicColors();
    final useCustomColorInBothModes = await ThemeService.getUseCustomColorInBothModes();
    
    // Load primary color
    final primaryColor = await ThemeService.getCustomPrimaryColor();
    
    setState(() {
      _currentThemeMode = themeMode;
      _useDynamicColors = useDynamicColors;
      _useCustomColorInBothModes = useCustomColorInBothModes;
      _primaryColor = primaryColor;
      _isLoadingColors = false;
    });
  }

  void _updateThemeMode(AppThemeMode mode) async {
    setState(() => _currentThemeMode = mode);
    await ThemeService.setThemeMode(mode);
  }

  void _updateDynamicColors(bool value) async {
    setState(() => _useDynamicColors = value);
    await ThemeService.setUseDynamicColors(value);
  }
  
  void _updateUseCustomColorInBothModes(bool value) async {
    setState(() => _useCustomColorInBothModes = value);
    await ThemeService.setUseCustomColorInBothModes(value);
  }
  
  // Add this helper method to generate color variations
  List<Color> _generateColorVariations(Color baseColor) {
    final HSLColor hsl = HSLColor.fromColor(baseColor);
    
    return [
      // Light shade (40% lighter)
      hsl.withLightness((hsl.lightness + 0.4).clamp(0.0, 1.0)).toColor(),
      
      // Medium light shade (20% lighter)
      hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor(),
      
      // Base color
      baseColor,
      
      // Medium dark shade (20% darker)
      hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
      
      // Dark shade (40% darker)
      hsl.withLightness((hsl.lightness - 0.4).clamp(0.0, 1.0)).toColor(),
    ];
  }

  // Update _showColorGrid method to show color variations
  void _showColorGrid() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Make bottom sheet full height
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose a color',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: colorScheme.onSurface,
                    ),
                  ],
                ),
              ),

              // Color grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _predefinedColors.length,
                  itemBuilder: (context, index) {
                    final baseColor = _predefinedColors[index];
                    final isSelected = _primaryColor == baseColor;
                    
                    return InkWell(
                      onTap: () {
                        // Show color variations when a color is tapped
                        _showColorVariations(baseColor);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: baseColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected 
                                ? colorScheme.primary 
                                : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: baseColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add method to show color variations
  void _showColorVariations(Color baseColor) {
    final variations = _generateColorVariations(baseColor);
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Variation'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tap a color to select it as your primary color'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: variations.map((color) {
                  final isSelected = _primaryColor == color;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      _updateCustomColor(color);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected 
                              ? colorScheme.primary 
                              : Colors.grey.withOpacity(0.3),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _updateCustomColor(Color color) async {
    // Update the color state
    setState(() {
      _primaryColor = color;
    });
    
    // Save the color to preferences
    await ThemeService.setCustomColor(color, 'primary');
    
    // If we're in custom color mode, we need to update the theme immediately
    if (_currentThemeMode == AppThemeMode.customColor) {
      // Force a theme refresh
      ThemeService.notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Updated isDarkMode check to use the app's theme mode
    final isDarkMode = _currentThemeMode == AppThemeMode.staticDark || 
        (_currentThemeMode == AppThemeMode.system && 
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    // Generate preview colors using the same algorithm
    ColorScheme previewScheme;
    if (_currentThemeMode == AppThemeMode.customColor || 
        (_useCustomColorInBothModes && _currentThemeMode != AppThemeMode.system)) {
      previewScheme = ThemeService.generateColorSchemeFromPrimary(_primaryColor, isDarkMode);
    } else if (_currentThemeMode == AppThemeMode.system && !_useDynamicColors) {
      // For system mode without dynamic colors, create a random color for preview
      // Use a locally created random color instead of accessing the private method
      final random = Random();
      final hue = random.nextDouble() * 360;
      final saturation = 0.6 + (random.nextDouble() * 0.3);
      final lightness = 0.4 + (random.nextDouble() * 0.2);
      final randomColor = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
      
      previewScheme = ThemeService.generateColorSchemeFromPrimary(randomColor, isDarkMode);
    } else {
      previewScheme = colorScheme;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Themes',  // Changed from 'Settings'
          style: TextStyle(
            fontFamily: 'AppFont',
            color: isDarkMode ? Colors.white : colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
      body: _isLoadingColors
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Remove the "Appearance" text section and continue with the theme options
                // Start directly with theme options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theme Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? Colors.grey[800] 
                              : colorScheme.surfaceContainerHighest.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Full-width toggle buttons
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // Calculate the width for each button based on available width
                                final buttonWidth = (constraints.maxWidth - 24) / 4; // Subtract some padding to avoid overflow
                                
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ToggleButtons(
                                      constraints: BoxConstraints.expand(
                                        width: buttonWidth,
                                        height: 50,
                                      ),
                                      direction: Axis.horizontal,
                                      borderRadius: BorderRadius.circular(12),
                                      selectedBorderColor: colorScheme.primary,
                                      selectedColor: colorScheme.onPrimary,
                                      fillColor: colorScheme.primary,
                                      color: colorScheme.primary,
                                      borderColor: colorScheme.outline.withOpacity(0.3),
                                      isSelected: [
                                        _currentThemeMode == AppThemeMode.system,
                                        _currentThemeMode == AppThemeMode.staticLight,
                                        _currentThemeMode == AppThemeMode.staticDark,
                                        _currentThemeMode == AppThemeMode.customColor,
                                      ],
                                      onPressed: (index) {
                                        _updateThemeMode(
                                          index == 0 ? AppThemeMode.system :
                                          index == 1 ? AppThemeMode.staticLight :
                                          index == 2 ? AppThemeMode.staticDark :
                                          AppThemeMode.customColor
                                        );
                                      },
                                      children: [
                                        // Simplify the content to avoid overflow
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.brightness_auto, size: 20),
                                            const SizedBox(height: 2),
                                            Text('Auto', style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.light_mode, size: 20),
                                            const SizedBox(height: 2),
                                            Text('Light', style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.dark_mode, size: 20),
                                            const SizedBox(height: 2),
                                            Text('Dark', style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.color_lens, size: 20),
                                            const SizedBox(height: 2),
                                            Text('Custom', style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Theme preview section now inside the theme mode card
                            Text(
                              'Theme Preview',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                    ? Colors.grey[850]
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildColorPreview('Primary', previewScheme.primary, previewScheme.onPrimary),
                                  _buildColorPreview('Secondary', previewScheme.secondary, previewScheme.onSecondary),
                                  _buildColorPreview('Tertiary', previewScheme.tertiary, previewScheme.onTertiary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // NEW: Card for additional theme options
                if (_currentThemeMode == AppThemeMode.system || 
                    (_currentThemeMode != AppThemeMode.customColor && _currentThemeMode != AppThemeMode.system) ||
                    _currentThemeMode == AppThemeMode.customColor || 
                    (_useCustomColorInBothModes && _currentThemeMode != AppThemeMode.system))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.grey[800] 
                            : colorScheme.surfaceContainerHighest.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Color Options',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          
                          // Dynamic colors toggle (only visible for system theme)
                          if (_currentThemeMode == AppThemeMode.system)
                            SwitchListTile(
                              title: const Text('Use dynamic colors'),
                              subtitle: Text(_useDynamicColors 
                                ? 'Use Material You colors on supported devices' 
                                : 'Use random colors each time you open the app'),
                              value: _useDynamicColors,
                              onChanged: _updateDynamicColors,
                              activeColor: colorScheme.primary,
                              secondary: Icon(
                                _useDynamicColors ? Icons.color_lens : Icons.shuffle,
                                color: colorScheme.primary,
                              ),
                            ),
                          
                          // New option - use custom color in all themes
                          if (_currentThemeMode != AppThemeMode.customColor && 
                              _currentThemeMode != AppThemeMode.system)
                            SwitchListTile(
                              title: const Text('Use custom color'),
                              subtitle: const Text('Apply your custom color to this theme'),
                              value: _useCustomColorInBothModes,
                              onChanged: _updateUseCustomColorInBothModes,
                              activeColor: colorScheme.primary,
                              secondary: Icon(
                                Icons.format_paint_outlined,
                                color: colorScheme.primary,
                              ),
                            ),
                          
                          // Custom color picker (visible for custom theme OR when useCustomColorInBothModes is enabled)
                          if (_currentThemeMode == AppThemeMode.customColor || 
                              (_useCustomColorInBothModes && _currentThemeMode != AppThemeMode.system)) ...[
                            ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              title: const Text('Primary Color'),
                              subtitle: Text('#${_primaryColor.value.toRadixString(16).substring(2).toUpperCase()}'),
                              trailing: Icon(
                                Icons.palette,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              onTap: _showColorGrid,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                
                // Remove standalone options that are now in the card
                // (The "Color Options" card above replaces these standalone options)
                
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildColorPreview(String label, Color color, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Aa',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
