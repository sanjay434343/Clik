import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'home_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/theme.dart';
import 'services/theme_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Platform-specific database initialization
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Add a static method to get a reference to the state
  static _MyAppState? of(BuildContext context) => 
      context.findAncestorStateOfType<_MyAppState>();

  @override 
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
    
    // Add a listener to update theme when it changes anywhere in the app
    ThemeService.addListener(_loadThemePreferences);
  }
  
  @override
  void dispose() {
    // Remove the listener when app is disposed
    ThemeService.removeListener(_loadThemePreferences);
    super.dispose();
  }

  Future<void> _loadThemePreferences() async {
    final themeMode = await ThemeService.getThemeMode();
    final useDynamicColors = await ThemeService.getUseDynamicColors();
    
    if (mounted) {
      setState(() {
        _themeMode = themeMode;
        _useDynamicColors = useDynamicColors;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return FutureBuilder<ThemeData>(
          future: ThemeService.getLightTheme(_useDynamicColors, lightDynamic),
          builder: (context, lightThemeSnapshot) {
            // Use async method for dark theme as well now
            return FutureBuilder<ThemeData>(
              future: ThemeService.getDarkThemeAsync(_useDynamicColors, darkDynamic),
              builder: (context, darkThemeSnapshot) {
                // While loading themes, show a loading indicator
                if (!lightThemeSnapshot.hasData || !darkThemeSnapshot.hasData) {
                  return MaterialApp(
                    home: Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                
                // Ensure the right theme mode is used
                final themeMode = ThemeService.getFlutterThemeMode(_themeMode);
                
                return MaterialApp(
                  title: 'Clik',
                  theme: lightThemeSnapshot.data,
                  darkTheme: darkThemeSnapshot.data,
                  themeMode: themeMode,
                  navigatorObservers: [routeObserver],
                  home: const SplashScreen(),
                  debugShowCheckedModeBanner: false,
                );
              },
            );
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Add button animation related variables
  bool _isButtonPressed = false;
  
  // Add wave animation controller and variables
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  bool _showWave = false;
  double _waveRadius = 0.0;
  
  // Add new animation controllers for enhanced effects
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;
  
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  
  @override
  void initState() {
    super.initState();
    // Initialize fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    
    // Initialize wave animation controller
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut)
    );
    
    // Initialize pulse animation (breathing effect)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    // Make pulse animation repeat
    _pulseController.repeat(reverse: true);
    
    // Initialize rotation animation for inner circle
    _rotateController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear)
    );
    // Make rotation continuous
    _rotateController.repeat();
    
    // Color animation will be initialized in build method using theme colors
    _colorController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Original wave animation listener
    _waveAnimation.addListener(() {
      setState(() {
        // Calculate the wave radius based on animation value
        _waveRadius = _waveAnimation.value * 300;
      });
      
      // Add haptic feedback at key points of the wave animation
      if (_waveAnimation.value > 0.1 && _waveAnimation.value < 0.15) {
        HapticFeedback.lightImpact();
      } else if (_waveAnimation.value > 0.4 && _waveAnimation.value < 0.45) {
        HapticFeedback.mediumImpact();
      }
      
      // Hide wave after animation completes
      if (_waveAnimation.isCompleted) {
        setState(() {
          _showWave = false;
        });
      }
    });
    
    // Start auto-navigation immediately
    _setupAutoNavigation();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _colorController.dispose();
    super.dispose();
  }
  
  // Modify auto-navigation method to use a 5-second delay
  void _setupAutoNavigation() {
    // At 1.5 seconds, press the button and trigger wave
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isButtonPressed = true;
          _showWave = true;
        });
        
        // Use heavy impact for stronger feedback
        HapticFeedback.heavyImpact();
        // Start wave animation
        _waveController.forward(from: 0.0);
        
        // Release button after 500ms
        Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _isButtonPressed = false);
          }
        });
      }
    });
    
    // Change navigation timer from 4 seconds to 5 seconds
    Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }
  
  void _navigateToHome() {
    // Add haptic feedback when button is pressed
    HapticFeedback.heavyImpact();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MyHomePage(title: 'Clik'),
      ),
    );
  }
  
  // Add a custom paint for ripple effect with dynamic colors
  Widget _buildRippleEffect() {
    final colorScheme = Theme.of(context).colorScheme;
    // Use primary color with proper opacity for wave effect
    final waveColor = colorScheme.primary.withOpacity(0.3);
    
    return Positioned.fill(
      child: _showWave
        ? CustomPaint(
            painter: WaveEffectPainter(
              waveRadius: _waveRadius,
              waveColor: waveColor,
              secondaryWaveColor: colorScheme.primaryContainer.withOpacity(0.3),
            ),
          )
        : const SizedBox(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    
    // Get colors that respect dynamic theming
    // Replace fixed backgroundColor with theme primary
    final backgroundColor = isDark ? Colors.grey[900] : colorScheme.background;
    final buttonColor = colorScheme.primary; // Use theme primary color for button
    final textColor = colorScheme.onPrimary; // Use on-primary for proper contrast
    
    // Initialize color animation with theme colors
    if (!_colorController.isAnimating) {
      _colorAnimation = ColorTween(
        begin: colorScheme.primary,
        end: colorScheme.secondary,
      ).animate(CurvedAnimation(
        parent: _colorController,
        curve: Curves.easeInOut,
      ));
      _colorController.repeat(reverse: true);
    }
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ripple wave effect layer
            _buildRippleEffect(),
            
            // Add subtle orbital particles
            _buildOrbitalParticles(colorScheme),
            
            // Button content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTapDown: (_) {
                    setState(() {
                      _isButtonPressed = true;
                      _showWave = true;
                    });
                    HapticFeedback.heavyImpact(); // Stronger haptic feedback
                    _waveController.forward(from: 0.0); // Start wave animation
                    _pulseController.stop(); // Stop pulsing when pressed
                  },
                  onTapUp: (_) {
                    setState(() => _isButtonPressed = false);
                    _pulseController.repeat(reverse: true); // Resume pulsing
                    _navigateToHome();
                  },
                  onTapCancel: () {
                    setState(() => _isButtonPressed = false);
                    _pulseController.repeat(reverse: true); // Resume pulsing
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: _isButtonPressed ? 1.0 : 0.0,
                    ),
                    duration: Duration(milliseconds: _isButtonPressed ? 100 : 300),
                    curve: _isButtonPressed ? Curves.easeIn : Curves.elasticOut,
                    builder: (context, value, child) {
                      // Calculate shadow offset and blur based on press state
                      final yOffset = _isButtonPressed ? 2.0 : 6.0;
                      final blurRadius = _isButtonPressed ? 4.0 : 8.0;
                      
                      return AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isButtonPressed ? 0.95 : _pulseAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, _isButtonPressed ? 2.0 * value : 0),
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  // Modern gradient with theme colors
                                  gradient: SweepGradient(
                                    center: Alignment.topLeft,
                                    startAngle: 0,
                                    endAngle: 2 * pi,
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.primary.withOpacity(0.9),
                                      colorScheme.primaryContainer,
                                      colorScheme.primary,
                                    ],
                                    stops: [0.0, 0.3, 0.7, 1.0],
                                  ),
                                  boxShadow: [
                                    // Main shadow using theme accent color
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(_isButtonPressed ? 0.3 : 0.5),
                                      blurRadius: _isButtonPressed ? 8 : 20,
                                      offset: Offset(0, _isButtonPressed ? 3 : 8),
                                      spreadRadius: 0,
                                    ),
                                    // Secondary shadow with deeper tone from accent
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(_isButtonPressed ? 0.2 : 0.4),
                                      blurRadius: 4,
                                      offset: Offset(4, _isButtonPressed ? 4 : 10),
                                      spreadRadius: -2,
                                    ),
                                    // Inner highlight for modern contrast
                                    BoxShadow(
                                      color: isDark ? colorScheme.primary.withOpacity(0.2) : Colors.white,
                                      blurRadius: 20,
                                      offset: Offset(-5, -5),
                                      spreadRadius: 0,
                                    ),
                                    // Inner shadow when pressed with accent color
                                    if (_isButtonPressed) BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.15),
                                      blurRadius: 15,
                                      offset: Offset(0, 5),
                                      spreadRadius: -5,
                                    ),
                                  ],
                                  // Add subtle border that follows accent color
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                // Add inner container with rotation
                                child: AnimatedBuilder(
                                  animation: _rotateAnimation,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _isButtonPressed ? 0 : _rotateAnimation.value * 0.06, // Subtle rotation
                                      child: Center(
                                        child: Container(
                                          width: 130,
                                          height: 130,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              center: Alignment(-0.3, -0.3),
                                              radius: 1.2,
                                              colors: [
                                                colorScheme.primaryContainer.withOpacity(0.9),
                                                _isButtonPressed 
                                                    ? colorScheme.primary.withOpacity(0.8) 
                                                    : colorScheme.primary,
                                              ],
                                              stops: [0.2, 1.0],
                                            ),
                                            boxShadow: [
                                              // Inner subtle shadow for depth
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 5,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Clik',
                                              style: TextStyle(
                                                fontFamily: 'Hins',
                                                fontSize: 32,
                                                fontWeight: FontWeight.w900,
                                                color: colorScheme.onPrimary, // Use on-primary for text
                                                letterSpacing: 2.0,
                                                height: 1.0,
                                                fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black.withOpacity(0.3),
                                                    offset: const Offset(0, 1),
                                                    blurRadius: 2,
                                                  ),
                                                  Shadow(
                                                    color: Colors.white.withOpacity(0.5),
                                                    offset: const Offset(0, -1),
                                                    blurRadius: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // New method to create orbital particles
  Widget _buildOrbitalParticles(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return Center(
          child: Stack(
            children: List.generate(6, (index) {
              final angle = _rotateController.value * 2 * pi + (index * pi / 3);
              final radius = 110.0;
              final x = cos(angle) * radius;
              final y = sin(angle) * radius;
              
              return Positioned(
                left: MediaQuery.of(context).size.width / 2 + x - 4,
                top: MediaQuery.of(context).size.height / 2 + y - 4,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: _isButtonPressed ? 0.0 : 0.8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        colorScheme.primary,
                        colorScheme.secondary,
                        index / 5.0,
                      )?.withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        )
                      ]
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// Update the custom painter class to support more dynamic colors
class WaveEffectPainter extends CustomPainter {
  final double waveRadius;
  final Color waveColor;
  final Color secondaryWaveColor;
  
  WaveEffectPainter({
    required this.waveRadius,
    required this.waveColor,
    required this.secondaryWaveColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Create more realistic wave with multiple rings
    final mainPaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0 * (1.0 - (waveRadius / 300)) // Thicker stroke that fades
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * (waveRadius / 300));
    
    canvas.drawCircle(center, waveRadius, mainPaint);
    
    // Secondary wave
    final secondPaint = Paint()
      ..color = secondaryWaveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    
    // Multiple secondary waves at different distances for more natural effect
    canvas.drawCircle(center, waveRadius * 0.75, secondPaint);
    
    // Tertiary inner wave (subtle)
    final thirdPaint = Paint()
      ..color = waveColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(center, waveRadius * 0.5, thirdPaint);
    
    // Create subtle ripple dots at the perimeter
    if (waveRadius > 50) {
      final sparkPaint = Paint()
        ..color = waveColor.withOpacity(0.8)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
        
      // Draw 8 dots around the perimeter
      for (int i = 0; i < 8; i++) {
        final angle = (i / 8) * 2 * 3.14159;
        final x = center.dx + waveRadius * 0.9 * cos(angle);
        final y = center.dy + waveRadius * 0.9 * sin(angle);
        canvas.drawCircle(Offset(x, y), 2, sparkPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(WaveEffectPainter oldDelegate) {
    return oldDelegate.waveRadius != waveRadius || 
           oldDelegate.waveColor != waveColor ||
           oldDelegate.secondaryWaveColor != secondaryWaveColor;
  }
}
