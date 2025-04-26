import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeToggleButton extends StatelessWidget {
  final AppThemeMode currentThemeMode;
  final Function(AppThemeMode) onThemeChanged;
  final bool showLabels;

  const ThemeToggleButton({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use app theme mode instead of system brightness
    final isDarkMode = currentThemeMode == AppThemeMode.staticDark || 
        (currentThemeMode == AppThemeMode.system && 
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Card(
      elevation: 0,
      color: isDarkMode 
          ? Colors.grey[800]
          : colorScheme.surfaceContainerHighest.withOpacity(0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabels) ...[
              const SizedBox(width: 8),
              Text(
                'Theme',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Using LayoutBuilder for full-width buttons
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate button width to fill available space
                  final buttonWidth = constraints.maxWidth / 4;
                  
                  return ToggleButtons(
                    constraints: BoxConstraints.expand(width: buttonWidth, height: 44),
                    direction: Axis.horizontal,
                    borderRadius: BorderRadius.circular(12),
                    selectedBorderColor: colorScheme.primary,
                    selectedColor: colorScheme.onPrimary,
                    fillColor: colorScheme.primary,
                    color: colorScheme.primary,
                    isSelected: [
                      currentThemeMode == AppThemeMode.system,
                      currentThemeMode == AppThemeMode.staticLight,
                      currentThemeMode == AppThemeMode.staticDark,
                      currentThemeMode == AppThemeMode.customColor,
                    ],
                    onPressed: (index) {
                      onThemeChanged(
                        index == 0 ? AppThemeMode.system :
                        index == 1 ? AppThemeMode.staticLight :
                        index == 2 ? AppThemeMode.staticDark :
                        AppThemeMode.customColor
                      );
                    },
                    children: const [
                      Icon(Icons.brightness_auto, size: 22),
                      Icon(Icons.light_mode, size: 22),
                      Icon(Icons.dark_mode, size: 22),
                      Icon(Icons.color_lens, size: 22),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
