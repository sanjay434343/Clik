import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeSelectorSidebar extends StatelessWidget {
  final AppThemeMode currentThemeMode;
  final Function(AppThemeMode) onThemeChanged;

  const ThemeSelectorSidebar({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.palette_outlined,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Text(
            'Theme',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Theme(
            data: Theme.of(context),
            child: ToggleButtons(
              constraints: const BoxConstraints.expand(width: 42, height: 36),
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
              ],
              onPressed: (index) {
                onThemeChanged(AppThemeMode.values[index]);
              },
              children: const [
                Icon(Icons.brightness_auto),
                Icon(Icons.light_mode),
                Icon(Icons.dark_mode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
