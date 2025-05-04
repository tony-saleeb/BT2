import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _textController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _pulseAnimation;
  
  // Text animations
  final List<Animation<Offset>> _charOffsetAnimations = [];
  final List<Animation<double>> _charOpacityAnimations = [];
  
  // Text to be animated
  final String _titleText = "NUMERICAL";
  final String _subtitleText = "ANALYSIS";
  
  // SVG loading state
  bool _svgLoadError = false;

  @override
  void initState() {
    super.initState();
    
    // Simplified controllers - removed _backgroundController
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    
    // Simplified logo animations
    _logoScaleAnimation = CurvedAnimation(
        parent: _mainController,
      curve: Curves.easeOutBack,
    );

    _logoOpacityAnimation = CurvedAnimation(
        parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // Reduced pulse intensity
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Setup staggered text animations
    _setupTextAnimations();

    // Start animation with a shorter delay
    _startAnimation();
  }
  
  void _setupTextAnimations() {
    final int totalChars = _titleText.length + _subtitleText.length;
    
    // Stagger effect for letters - faster timing
    for (int i = 0; i < totalChars; i++) {
      final double startTime = 0.3 + (i * 0.02); // Faster stagger
      final double endTime = startTime + 0.2;
      
      // Offset animation (slide from bottom)
      _charOffsetAnimations.add(
        Tween<Offset>(
          begin: const Offset(0.0, 0.3), // Less movement
          end: Offset.zero,
    ).animate(
      CurvedAnimation(
            parent: _textController,
            curve: Interval(startTime, endTime, curve: Curves.easeOutCubic),
          ),
        ),
      );
      
      // Opacity animation
      _charOpacityAnimations.add(
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: _textController,
            curve: Interval(startTime, endTime, curve: Curves.easeIn),
          ),
        ),
      );
    }
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200)); // Reduced delay
    if (mounted) {
      _mainController.forward();
      _textController.forward();
      
      // Navigation delay - shorter
      await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                opacity: animation,
                  child: child,
                );
              },
            transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                    colorScheme.surface.withOpacity(0.8),
                        colorScheme.surface,
                    colorScheme.primary.withOpacity(0.05),
                      ]
                    : [
                    colorScheme.background.withOpacity(0.95),
                        colorScheme.background,
                    colorScheme.primary.withOpacity(0.02),
                      ],
            stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: Stack(
              children: [
            // Simplified background particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return Stack(
                  children: List.generate(8, (index) { // Reduced from 15 to 8
                    final random = math.Random(index * 3);
                    final particleSize = random.nextDouble() * 15 + 5; // Smaller particles
                  final xPosition = random.nextDouble() * MediaQuery.of(context).size.width;
                  final yPosition = random.nextDouble() * MediaQuery.of(context).size.height;
                    final opacity = (random.nextDouble() * 0.12);
                    
                    // Color selection
                    Color color;
                    if (index % 3 == 0) {
                      color = colorScheme.primary;
                    } else if (index % 3 == 1) {
                      color = colorScheme.secondary;
                    } else {
                      color = colorScheme.tertiary;
                    }
                    
                    final animationValue = (_particleController.value + random.nextDouble()) % 1.0;
                    
                    // Simpler movement patterns
                    double dx = 0, dy = 0;
                    if (index % 2 == 0) {
                      dx = 20 * math.cos(animationValue * 2 * math.pi);
                    } else {
                      dy = 20 * math.sin(animationValue * 2 * math.pi);
                    }
                  
                  return Positioned(
                      left: xPosition + dx,
                      top: yPosition + dy,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                          width: particleSize,
                          height: particleSize,
                        decoration: BoxDecoration(
                          color: color,
                            shape: BoxShape.circle, // Only circles for simplicity
                        ),
                      ),
                    ),
                  );
                }),
                );
              }
            ),
                
                // Main content
                Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with error handling
                  AnimatedBuilder(
                    animation: Listenable.merge([_mainController, _pulseController]),
                    builder: (context, child) {
                      return ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: FadeTransition(
                          opacity: _logoOpacityAnimation,
                          child: Transform.scale(
                            scale: _pulseAnimation.value,
                            child: _buildLogo(colorScheme, size),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 30.h),
                  
                  // Animated Text (NUMERICAL)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildAnimatedCharacters(
                      _titleText, 
                      0, 
                      Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        height: 1.1,
                      ).apply(fontSizeDelta: 2.sp),
                      true,
                    ),
                  ),
                  
                  SizedBox(height: 10.h),
                  
                  // Animated Text (ANALYSIS)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildAnimatedCharacters(
                      _subtitleText, 
                      _titleText.length, 
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                        height: 1.1,
                        color: colorScheme.secondary,
                      ).apply(fontSizeDelta: 2.sp),
                      false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Separate method for logo with fallback
  Widget _buildLogo(ColorScheme colorScheme, Size size) {
    if (_svgLoadError) {
      // Fallback widget if SVG fails to load
      return Container(
        width: size.width * 0.5,
        height: size.width * 0.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colorScheme.primary,
              colorScheme.tertiary,
            ],
          ),
        ),
        child: Center(
          child: Text(
            "N",
            style: TextStyle(
              fontSize: 80.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    
    // Try loading the SVG with error handling
    return SvgPicture.asset(
      'assets/bt2.svg',
      width: size.width * 0.5,
      height: size.width * 0.4,
      fit: BoxFit.contain,
      placeholderBuilder: (BuildContext context) {
        // While SVG is loading or if it fails
        return SizedBox(
          width: size.width * 0.5,
          height: size.width * 0.4,
          child: Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          ),
        );
      },
      semanticsLabel: 'Numerical Analysis Logo',
      // Handle errors
      errorBuilder: (context, exception, stackTrace) {
        _svgLoadError = true; // Mark as error for future rebuilds
        return Container(
          width: size.width * 0.5,
          height: size.width * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colorScheme.primary,
                colorScheme.tertiary,
              ],
            ),
          ),
          child: Center(
            child: Text(
              "N",
              style: TextStyle(
                fontSize: 80.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            ),
          );
        },
    );
  }
  
  List<Widget> _buildAnimatedCharacters(
    String text, 
    int offset, 
    TextStyle? style,
    bool isTitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return List.generate(
      text.length,
      (index) {
        final charIndex = offset + index;
        return AnimatedBuilder(
          animation: _textController,
          builder: (context, child) {
            return SlideTransition(
              position: _charOffsetAnimations[charIndex],
              child: FadeTransition(
                opacity: _charOpacityAnimations[charIndex],
                child: isTitle ? ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    text[index],
                    style: style?.copyWith(color: Colors.white),
                  ),
                ) : Text(
                  text[index],
                  style: style,
                ),
              ),
            );
          },
        );
      },
    );
  }
} 