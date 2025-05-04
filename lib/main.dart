import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:flutter/services.dart'; // Import for HapticFeedback
import 'providers/theme_provider.dart';
import 'screens/chapter_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ScreenUtilInit(
      designSize: const Size(390, 844), // iPhone 14 Pro dimensions
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return const ProviderScope(
          child: MyApp(),
        );
      },
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3D59),
        secondary: const Color(0xFF17C3B2),
        brightness: Brightness.light,
      ).copyWith(
        tertiary: const Color(0xFF4C51C6),
        primary: const Color(0xFF2C5282),
        secondary: const Color(0xFF0891B2),
        surface: Colors.white,
        background: const Color(0xFFF8FAFC),
        surfaceVariant: const Color(0xFFE8F2FF),
        outline: const Color(0xFFCBD5E1),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(),
      cardTheme: const CardTheme(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3D59),
        secondary: const Color(0xFF17C3B2),
        brightness: Brightness.dark,
      ).copyWith(
        tertiary: const Color(0xFFFFD93D),
        surface: const Color(0xFF1A1A1A),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
    );
    
    return AnimatedTheme(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      data: themeMode == ThemeMode.dark ? darkTheme : lightTheme,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Numerical Analysis',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const SplashScreen(
          nextScreen: OnboardingScreen(nextScreen: HomePage()),
        ),
      ),
    );
  }
  
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TickerProviderStateMixin {
  int? selectedChapter;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  );
  
  // Map to store chapter animation controllers
  final Map<int, AnimationController> _chapterControllers = {};
  
  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.6,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
  ));

  // Animation removed to ensure cards remain balanced

  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  ));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    
    // Initialize controllers for chapters
    _initChapterControllers();
  }
  
  void _initChapterControllers() {
    // Create controllers for chapters 1 and 2
    for (int chapter = 1; chapter <= 2; chapter++) {
      _chapterControllers[chapter] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Dispose all chapter controllers
    for (var controller in _chapterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.primary.withOpacity(0.05),
                    colorScheme.surface,
                    colorScheme.secondary.withOpacity(0.05),
                  ]
                : [
                    colorScheme.primary.withOpacity(0.02),
                    colorScheme.background,
                    colorScheme.secondary.withOpacity(0.03),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          maintainBottomViewPadding: true, // Allow content to slightly extend beyond safe area if needed
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24.h),
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.2, 0.0),
                    end: Offset.zero,
                  ).animate(_controller),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.tertiary,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'NUMERICAL',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  height: 1.1,
                                  color: Colors.white,
                                ).apply(fontSizeDelta: 2.sp),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'ANALYSIS',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                letterSpacing: 4,
                                height: 1.1,
                                color: colorScheme.secondary,
                              ).apply(fontSizeDelta: 2.sp),
                            ),
                          ],
                        ),
                        _buildThemeToggle(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // Prevents actual scrolling but allows overflow
                    clipBehavior: Clip.none, // Ensures no clipping happens
                  child: Transform(
                    // No transform effects to ensure perfect balance
                    transform: Matrix4.identity(),
                    alignment: Alignment.center,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Stack(
                          children: [
                            // Background effect
                            Positioned.fill(
                              child: CustomPaint(
                                painter: FuturisticGridPainter(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                  phase: _controller.value,
                                ),
                              ),
                            ),
                            
                            // Chapter selection cards
                            Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 100.h),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    // Elegant title
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.secondary,
                                          Theme.of(context).colorScheme.tertiary,
                                        ],
                                      ).createShader(bounds),
                                      child: Text(
                                        "SELECT CHAPTER",
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 20.h),
                                    
                                    // Root finding chapter
                                    Hero(
                                      tag: 'chapter-1',
                                      child: _buildExtraordinaryCard(
                                        1,
                                        "ROOT FINDING",
                                        "Numerical methods to find solutions to equations",
                                        [0xFF4285F4, 0xFF34A853],
                                      ),
                                    ),
                                    SizedBox(height: 40.h),
                                    
                                    // Linear systems chapter
                                    Hero(
                                      tag: 'chapter-2',
                                      child: _buildExtraordinaryCard(
                                        2,
                                        "LINEAR SYSTEMS",
                                        "Methods for solving systems of linear equations",
                                        [0xFFEA4335, 0xFFFBBC05],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final currentTheme = ref.read(themeProvider);
            ref.read(themeProvider.notifier).setTheme(
              currentTheme == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildExtraordinaryCard(int chapter, String title, String subtitle, List<int> gradientColors) {
    final isSelected = selectedChapter == chapter;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use animation controller
    final controller = _chapterControllers[chapter]!;
    
    // Animation for spotlight effect
    final spotlightAnimation = Tween<double>(
      begin: -0.5,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        
        setState(() {
          // Toggle selection if tapping the same chapter, otherwise select this chapter
          selectedChapter = selectedChapter == chapter ? null : chapter;
        });
        
        // Only navigate if this chapter is already selected (second tap)
        if (isSelected) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChapterScreen(chapter: chapter),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400), // Even faster animation to reduce overflow time
        curve: Curves.easeOut, // Simple curve with no overshoot to prevent overflow
        width: isSelected ? 340.w : 290.w,
        height: isSelected ? 175.h : 165.h, // Minimal height increase when selected
        transform: isSelected 
            ? (Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                // Perfectly flat with no rotation on any axis for perfect balance
                ..translate(0.0, -5.0, 0.0)) // Minimal vertical lift to prevent overflow
            : Matrix4.identity(), // Perfectly flat for non-selected cards
        transformAlignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3D morphing card
            Container(
      decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
          colors: [
                    Color(gradientColors[0]).withOpacity(isDark ? 0.6 : 0.8),
                    Color(gradientColors[1]).withOpacity(isDark ? 0.6 : 0.8),
          ],
        ),
        boxShadow: [
                  // Ambient shadow
          BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.12),
                    blurRadius: 12,
                    offset: Offset(0, 6), // Balanced shadow
            spreadRadius: 0,
                  ),
                  // Glow effect
                  if (isSelected)
                    BoxShadow(
                      color: Color(gradientColors[0]).withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 1,
                      offset: Offset(0, 8), // More balanced shadow offset
          ),
        ],
      ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Animated pattern
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        return Positioned.fill(
                          child: CustomPaint(
                            painter: FuturisticPatternPainter(
                              baseColor: Color(gradientColors[0]).withOpacity(0.15),
                              patternType: chapter,
                              phase: controller.value * 2 * math.pi,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Spotlight effect
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        return Positioned.fill(
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(spotlightAnimation.value, -spotlightAnimation.value),
                                end: Alignment(-spotlightAnimation.value, spotlightAnimation.value),
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Container(
        color: Colors.transparent,
                            ),
              ),
            );
          },
                    ),
                    
                    // Content
                    Padding(
                      padding: EdgeInsets.all(isSelected ? 25.w : 24.w), // Minimal padding increase when selected
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top row with badge and selection indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chapter badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
            child: Row(
                                  mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                                      "CHAPTER",
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w800,
                    color: Colors.white,
                                        letterSpacing: 1,
                  ),
                ),
                                    SizedBox(width: 5.w),
                Container(
                                      width: isSelected ? 24.w : 22.w,
                                      height: isSelected ? 24.w : 22.w,
                  decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          chapter.toString(),
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Color(gradientColors[0]),
                                          ),
                                        ),
                  ),
                ),
              ],
            ),
          ),
                              
                              // Selection indicator
                              if (isSelected)
                                Container(
                                  width: 30.w,
                                  height: 30.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 5,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Color(gradientColors[0]),
                                    size: 18.w,
                                  ),
                                ),
                            ],
                          ),
                          
                          // Bottom section with title and subtitle
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: isSelected ? 23.sp : 22.sp, // Minimal size increase
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 4.h),
                              
                              // Subtitle
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: isSelected ? 14.sp : 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.85),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                      ],
              ),
            ),
                    

                      
                    // "TAP TO CONTINUE" overlay when selected
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)), // Less movement
                              child: Opacity(
                                opacity: value,
                                child: Container(
                                  height: 28.h, // Reduced height
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0),
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(28),
                                      bottomRight: Radius.circular(28),
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "TAP TO CONTINUE",
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        AnimatedBuilder(
                                          animation: controller,
                                          builder: (context, child) {
                                            return Transform.translate(
                                              offset: Offset(3 * math.sin(controller.value * 2 * math.pi), 0),
                              child: Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 14.w,
                              ),
                            );
                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                ),
              ),
            ),
            
            // Floating 3D elements
            if (isSelected)
              ..._buildFloatingElements(chapter, gradientColors),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildFloatingElements(int chapter, List<int> gradientColors) {
    final random = math.Random(chapter);
    final elements = <Widget>[];
    
    // Create 5-8 floating elements per card
    final count = 5 + random.nextInt(4);
    
    for (int i = 0; i < count; i++) {
      // Random position around the card
      final isLeft = random.nextBool();
      final isTop = random.nextBool();
      
      // Size between 6-15
      final size = 6.0 + random.nextDouble() * 9.0;
      
      // Random offset from card edge
      final offsetX = random.nextDouble() * 60.0 - 30.0;
      final offsetY = random.nextDouble() * 60.0 - 30.0;
      
      // Alternating shapes
      final isCircle = i % 2 == 0;
      
      elements.add(
        AnimatedBuilder(
          animation: _chapterControllers[chapter]!,
          builder: (context, child) {
            final animation = _chapterControllers[chapter]!.value;
            // Floating movement
            final floatX = 8.0 * math.sin(animation * 2 * math.pi + i);
            final floatY = 8.0 * math.cos(animation * 2 * math.pi + i * 0.5);
            
            return Positioned(
              left: isLeft ? -15 + offsetX + floatX : null,
              right: !isLeft ? -15 + offsetX + floatX : null,
              top: isTop ? -15 + offsetY + floatY : null,
              bottom: !isTop ? -15 + offsetY + floatY : null,
              child: Container(
                width: size.w,
                height: size.w,
                decoration: BoxDecoration(
                  color: Color(gradientColors[i % 2]).withOpacity(0.8),
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle ? null : BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Color(gradientColors[i % 2]).withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    
    return elements;
  }
}

// Futuristic background grid pattern
class FuturisticGridPainter extends CustomPainter {
  final Color color;
  final double phase;
  
  FuturisticGridPainter({required this.color, required this.phase});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    // Draw horizontal grid lines
    final horizSpacing = size.height / 15;
    for (int i = 0; i < 16; i++) {
      final y = i * horizSpacing;
      // Animate every other line
      final offset = i % 2 == 0 ? 20 * math.sin(phase * 2 * math.pi) : 0;
      canvas.drawLine(
        Offset(0 + offset.toDouble(), y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // Draw vertical grid lines
    final vertSpacing = size.width / 20;
    for (int i = 0; i < 21; i++) {
      final x = i * vertSpacing;
      // Animate every other line
      final offset = i % 2 == 0 ? 0 : 15 * math.cos(phase * 2 * math.pi);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height + offset),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is FuturisticGridPainter) {
      return oldDelegate.phase != phase || oldDelegate.color != color;
    }
    return true;
  }
}

// Pattern inside each card
class FuturisticPatternPainter extends CustomPainter {
  final Color baseColor;
  final int patternType;
  final double phase;
  
  FuturisticPatternPainter({
    required this.baseColor,
    required this.patternType,
    required this.phase,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (patternType == 1) {
      _paintRootFindingPattern(canvas, size);
    } else {
      _paintLinearSystemsPattern(canvas, size);
    }
  }
  
  void _paintRootFindingPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Create axes
    canvas.drawLine(
      Offset(0, size.height * 0.6),
      Offset(size.width, size.height * 0.6),
      paint,
    );
    
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.2, size.height),
      paint,
    );
    
    // Draw multiple wave functions
    final wavesPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 0; i < 2; i++) {
      final path = Path();
      final amplitude = 25.0 - i * 10.0;
      final frequency = 0.02 * (i + 1);
      final verticalOffset = size.height * 0.6;
      
      path.moveTo(0, verticalOffset);
      
      for (double x = 0; x < size.width; x += 1) {
        final y = verticalOffset - amplitude * math.sin((frequency * x) + phase + (i * math.pi / 2));
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, wavesPaint);
    }
    
    // Draw root-finding visualization
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    
    // Animated root marker
    final rootX = size.width * (0.4 + 0.1 * math.sin(phase));
    final rootY = size.height * 0.6;
    
    // Draw the root point
    canvas.drawCircle(Offset(rootX, rootY), 3, dotPaint);
    
    // Draw dashed line to function
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    final amplitude = 25.0;
    final frequency = 0.02;
    final functionY = rootY - amplitude * math.sin((frequency * rootX) + phase);
    
    // Dashed line
    const dashLength = 3.0;
    const dashSpace = 3.0;
    double distance = 0;
    final pathDash = Path();
    pathDash.moveTo(rootX, rootY);
    
    final totalDistance = (functionY - rootY).abs();
    
    while (distance < totalDistance) {
      final startPoint = rootY + distance * (functionY - rootY) / totalDistance;
      distance += dashLength;
      final endPoint = distance < totalDistance 
          ? rootY + distance * (functionY - rootY) / totalDistance
          : functionY;
      
      pathDash.lineTo(rootX, endPoint);
      
      if (distance >= totalDistance) break;
      
      pathDash.moveTo(rootX, endPoint + dashSpace * (functionY - rootY) / totalDistance);
      distance += dashSpace;
    }
    
    canvas.drawPath(pathDash, dashPaint);
    
    // Draw function point
    canvas.drawCircle(Offset(rootX, functionY), 3, dotPaint);
  }
  
  void _paintLinearSystemsPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Matrix grid
    final cellSize = 20.0; // Larger cell size
    final rows = 4; // More rows 
    final cols = 3; // Keep 3 columns
    // Move the grid to the right side of the card
    final offsetX = size.width * 0.55;
    final offsetY = size.height * 0.18; // Position it higher
    
    // Draw grid
    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(
        Offset(offsetX, offsetY + i * cellSize),
        Offset(offsetX + cols * cellSize, offsetY + i * cellSize),
        paint,
      );
    }
    
    for (int i = 0; i <= cols; i++) {
      canvas.drawLine(
        Offset(offsetX + i * cellSize, offsetY),
        Offset(offsetX + i * cellSize, offsetY + rows * cellSize),
        paint,
      );
    }
    
    // Draw matrix elements and vector
    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    final random = math.Random(42);
    
    // Animate the numbers based on phase
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (j < cols - 1) {
          // Matrix element
          final baseValue = random.nextInt(9) - 4;
          final animatedValue = (baseValue + phase * 2).toInt() % 9 - 4;
          final value = animatedValue.toString();
          
          textPaint.text = TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
            ),
          );
          
          textPaint.layout();
          
          final x = offsetX + j * cellSize + cellSize / 2 - textPaint.width / 2;
          final y = offsetY + i * cellSize + cellSize / 2 - textPaint.height / 2;
          
          textPaint.paint(canvas, Offset(x, y));
        } else {
          // Vector element (b vector)
          final value = (random.nextInt(9) + 1).toString();
          
          textPaint.text = TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
          
          textPaint.layout();
          
          final x = offsetX + j * cellSize + cellSize / 2 - textPaint.width / 2;
          final y = offsetY + i * cellSize + cellSize / 2 - textPaint.height / 2;
          
          textPaint.paint(canvas, Offset(x, y));
        }
      }
    }
    
    // Draw some additional matrix elements to replace the X vector
    // Add scattered numbers and math symbols for more visual interest
    final symbols = ["+", "×", "=", "÷", "-"];
    
    // First batch of numbers - right side
    for (int i = 0; i < 8; i++) {
      // Use phase to animate the numbers
      final baseValue = random.nextInt(9) - 4;
      final animatedValue = (baseValue + (phase * 3 + i).toInt()) % 9 - 4;
      final value = animatedValue.toString();
      
      final fontSize = 10.0 + random.nextDouble() * 4;
      final opacity = 0.6 + random.nextDouble() * 0.4;
      
      textPaint.text = TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );
      
      textPaint.layout();
      
      // Position throughout the right part of the card
      final x = offsetX + cols * cellSize + 5 + random.nextDouble() * (size.width * 0.25);
      final y = offsetY + random.nextDouble() * (size.height * 0.7);
      
      textPaint.paint(canvas, Offset(x, y));
    }
    
    // Add a few math symbols
    for (int i = 0; i < 3; i++) {
      final symbolIndex = random.nextInt(symbols.length);
      
      textPaint.text = TextSpan(
        text: symbols[symbolIndex],
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      
      textPaint.layout();
      
      final x = offsetX + random.nextDouble() * (size.width * 0.3);
      final y = offsetY + rows * cellSize + 15 + random.nextDouble() * 30;
      
      textPaint.paint(canvas, Offset(x, y));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is FuturisticPatternPainter) {
      return oldDelegate.phase != phase || 
             oldDelegate.baseColor != baseColor ||
             oldDelegate.patternType != patternType;
    }
    return true;
  }
}
