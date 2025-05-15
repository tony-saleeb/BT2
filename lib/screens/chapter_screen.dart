import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble, ImageFilter;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/numerical_method.dart';
import './bisection_method_screen.dart';
import './false_position_method_screen.dart';
import './simple_fixed_point_method_screen.dart';
import './newton_method_screen.dart';
import './secant_method_screen.dart';
import './gauss_elimination_method_screen.dart';
import './lu_decomposition_method_screen.dart';
import './gauss_jordan_method_screen.dart';
import './cramer_method_screen.dart';
import 'dart:math' as math;
import 'dart:async';
// Import for timeline access

// High-performance scroll physics with minimal overhead
class UltraPerformanceScrollPhysics extends ScrollPhysics {
  const UltraPerformanceScrollPhysics({super.parent});

  @override
  UltraPerformanceScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return UltraPerformanceScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.1,        // Ultra-light mass for instant response
    stiffness: 450,   // Very high stiffness for immediate stops
    damping: 25,      // Balanced damping
  );

  @override
  double get minFlingVelocity => 50.0;
  @override
  double get maxFlingVelocity => 8000.0;
  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((position.pixels <= position.minScrollExtent && velocity <= 0) ||
        (position.pixels >= position.maxScrollExtent && velocity >= 0)) {
      return null;
    }

    final target = _calculateTargetPixels(position, velocity);
    if (target == position.pixels) return null;

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity * 0.4, // Reduced velocity for precise stopping
      tolerance: tolerance,
    );
  }

  double _calculateTargetPixels(ScrollMetrics position, double velocity) {
    final page = position.pixels / position.viewportDimension;
    final targetPage = velocity.abs() < tolerance.velocity
        ? page.round()
        : page + 0.35 * velocity.sign;
    
    return targetPage.clamp(
      0,
      (position.maxScrollExtent / position.viewportDimension).floor().toDouble(),
    ) * position.viewportDimension;
  }
}

class OptimizedCardScrollPhysics extends ScrollPhysics {
  const OptimizedCardScrollPhysics({super.parent});

  @override
  OptimizedCardScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OptimizedCardScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.2,        // Lighter mass for faster response
    stiffness: 150.0, // Higher stiffness for snappier movement
    damping: 25.0,    // Balanced damping for smooth stops
  );

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Optimize for card-based scrolling
    final tolerance = this.tolerance;
    
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return null;
    }

    // Calculate target page
    final page = position.pixels / position.viewportDimension;
    final targetPage = velocity.abs() < tolerance.velocity
        ? page.round()
        : velocity > 0
            ? page.ceil()
            : page.floor();

    final targetPixels = targetPage * position.viewportDimension;
    if (targetPixels == position.pixels) return null;

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}

class ChapterScreen extends StatefulWidget {
  final int chapter;

  const ChapterScreen({
    super.key,
    required this.chapter,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;
  int _currentPage = 0;
  double _page = 0;
  bool _isInitialized = false;
  final Map<int, GlobalKey> _cardKeys = {};
  Timer? _scrollEndTimer;
  bool _isFirstScroll = true;
  final Map<int, bool> _prerenderedPages = {};
  final ValueNotifier<bool> _isPrewarmed = ValueNotifier<bool>(false);
  final Map<int, Matrix4> _transformCache = {};
  final ValueNotifier<double> _pageNotifier = ValueNotifier<double>(0);
  final Map<int, Matrix4> _matrixPool = {};
  final Map<int, Alignment> _alignmentCache = {};
  bool _hasCompletedFirstBuild = false;
  late final List<NumericalMethod> _methods;
  final Map<int, GlobalKey> _repaintKeys = {};

  @override
  void initState() {
    super.initState();
    
    // Pre-load methods to avoid rebuilds
    _methods = NumericalMethod.getMethodsForChapter(widget.chapter);
    
    // Initialize everything
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    // Initialize controllers first
    _initializeControllers();
    
    // Initialize all caches and keys before any UI
    _initializeCardKeys();
    _initializeRepaintKeys();
    await _precalculateTransforms();
    
    // Pre-render initial cards
    _preRenderInitialCards();
    
    // Pre-warm scroll physics in parallel
    unawaited(_preWarmScrollPhysics());

    // Mark as initialized
    setState(() {
      _isInitialized = true;
      _isPrewarmed.value = true;
    });

    // Ensure proper initial state in next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.jumpTo(0);
      _page = 0;
      _currentPage = 0;
      _pageNotifier.value = 0;
      
      setState(() {
        _hasCompletedFirstBuild = true;
      });
    });
  }

  void _initializeRepaintKeys() {
    for (int i = 0; i < _methods.length; i++) {
      _repaintKeys[i] = GlobalKey();
    }
  }

  void _initializeControllers() {
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: 0,
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pageController.addListener(_optimizedPageUpdate);
    _animationController.forward();
  }

  void _preRenderInitialCards() {
    // Pre-render more cards for smoother initial scrolling
    for (int i = 0; i < math.min(6, _methods.length); i++) {
      _prerenderedPages[i] = true;
      _updateTransformForIndex(i, i == 0 ? 0 : 1);
    }
  }

  Future<void> _precalculateTransforms() async {
    // Initialize matrix pool and alignment cache
    for (int i = 0; i < _methods.length; i++) {
      _matrixPool[i] = Matrix4.identity()..setEntry(3, 2, 0.001);
      _alignmentCache[i] = Alignment.centerRight;
    }

    // Pre-calculate initial transforms
    for (int i = 0; i < math.min(6, _methods.length); i++) {
      final progress = i == 0 ? 0.0 : 1.0;
      _updateTransformForIndex(i, progress);
    }
  }

  Matrix4 _updateTransformForIndex(int index, double progress) {
    final matrix = _matrixPool[index]!;
    matrix.setIdentity();
    matrix.setEntry(3, 2, 0.001);
    matrix.rotateY(progress * (_isFirstScroll ? 0.03 : 0.05));
    
    _transformCache[index] = matrix;
    _alignmentCache[index] = progress <= 0 ? Alignment.centerRight : Alignment.centerLeft;
    return matrix;
  }

  void _optimizedPageUpdate() {
    if (!mounted || !_isPrewarmed.value || !_hasCompletedFirstBuild || !_pageController.hasClients) return;
    
    final newPage = _pageController.page ?? 0;
    
    // Handle first scroll
    if (_isFirstScroll && newPage.abs() > 0.01) {
      _isFirstScroll = false;
      _updatePageState(newPage, isFirstScroll: true);
      return;
    }

    // Skip tiny updates
    if ((_page - newPage).abs() > 0.001) {
      _updatePageState(newPage, isFirstScroll: false);
    }

    _pageNotifier.value = newPage;
  }

  void _updatePageState(double newPage, {required bool isFirstScroll}) {
    final nextPage = newPage.round() + 1;
    final prevPage = newPage.round() - 1;
    
    // Update transforms outside setState
    for (int i = prevPage; i <= nextPage + 1; i++) {
      if (i >= 0 && i < _methods.length) {
        final progress = (newPage - i).clamp(-1.0, 1.0);
        _updateTransformForIndex(i, isFirstScroll ? progress * 0.7 : progress);
      }
    }

    setState(() {
      _page = newPage;
      _currentPage = _page.round();
      
      // Pre-render pages
      if (isFirstScroll) {
        for (int i = prevPage - 1; i <= nextPage + 2; i++) {
          if (i >= 0 && i < _methods.length) {
            _prerenderedPages[i] = true;
          }
        }
      } else {
        if (nextPage >= 0 && nextPage < _methods.length) {
          _prerenderedPages[nextPage] = true;
        }
        if (prevPage >= 0 && prevPage < _methods.length) {
          _prerenderedPages[prevPage] = true;
        }
      }
    });

    // Optimized scroll end detection
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _cleanupFarPages(_currentPage);
    });
  }

  void _cleanupFarPages(int currentPage) {
    final keysToRemove = _prerenderedPages.keys
        .where((page) => (page - currentPage).abs() > 2)
        .toList();
    
    for (final page in keysToRemove) {
      _prerenderedPages.remove(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
          } else if (notification is ScrollEndNotification) {
          }
          return false;
        },
        child: Stack(
          children: [
            // Background with fixed decorative elements
            RepaintBoundary(
              child: Stack(
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                colorScheme.primary.withOpacity(0.08),
                                colorScheme.surface,
                                colorScheme.secondary.withOpacity(0.08),
                              ]
                            : [
                                // Darker pearl white gradient for light mode
                                const Color(0xFFE8EDF6),
                                const Color(0xFFDFE7F0),
                                const Color(0xFFD6DEE8),
                              ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // Fixed decorative elements - adding pearlescent accents
                  ...List.generate(_methods.length, (index) {
                    final offset = index * 0.85;
                    return Positioned(
                      left: MediaQuery.of(context).size.width * offset + 40.w,
                      bottom: 40.h,
                      child: Opacity(
                        opacity: isDark ? 0.5 : 0.75,
                        child: Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? colorScheme.primary.withOpacity(0.1)
                                  : const Color(0xFFA4B8D4),
                              width: 1,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                  ...List.generate(_methods.length, (index) {
                    final offset = index * 0.85;
                    return Positioned(
                      right: MediaQuery.of(context).size.width * offset + 20.w,
                      top: 120.h,
                      child: Opacity(
                        opacity: isDark ? 0.5 : 0.75,
                        child: Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? colorScheme.secondary.withOpacity(0.2)
                                  : const Color(0xFF9BB5D9),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(20.r),
                              bottomLeft: Radius.circular(20.r),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Content
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 16.h,
                      ),
                      child: Row(
                        children: [
                          // Back button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16.r),
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.1),
                                      blurRadius: 20.r,
                                      offset: Offset(0, 8.h),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: colorScheme.primary,
                                  size: 24.r,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 24.w),
                          // Title
                          Expanded(
                            child: Column(
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
                                    'CHAPTER ${widget.chapter}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      height: 1.1,
                                      color: Colors.white,
                                    ).apply(fontSizeDelta: 2.sp),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  widget.chapter == 1 ? 'ROOT-FINDING METHODS' : 'LINEAR ALGEBRA METHODS',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 2,
                                    color: colorScheme.secondary,
                                  ).apply(fontSizeDelta: 1.sp),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Cards with optimized scrolling
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const UltraPerformanceScrollPhysics(),
                      itemCount: _methods.length,
                      onPageChanged: null,
                      itemBuilder: (context, index) {
                        if (!_isInitialized || !_prerenderedPages.containsKey(index) || !_isPrewarmed.value) {
                          return const SizedBox.shrink();
                        }

                        return RepaintBoundary(
                          key: _repaintKeys[index],
                          child: ValueListenableBuilder<double>(
                            valueListenable: _pageNotifier,
                            builder: (context, page, _) {
                              final transform = _transformCache[index] ?? _matrixPool[index]!;
                              final alignment = _alignmentCache[index]!;
                              
                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                opacity: _isInitialized && _isPrewarmed.value ? 1.0 : 0.0,
                                child: Transform(
                                  transform: transform,
                                  alignment: alignment,
                                  transformHitTests: false,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 32.h,
                                    ),
                                    child: MethodCardContent(
                                      key: _cardKeys[index],
                                      method: _methods[index],
                                      index: index,
                                      colorScheme: colorScheme,
                                      isDark: isDark,
                                      parentProgress: (page - index).clamp(-1.0, 1.0),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Page Indicator
                  RepaintBoundary(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_methods.length, (index) {
                          final isSelected = index == _currentPage;
                          final size = lerpDouble(6, 24, isSelected ? 1 : 0)!;
                          
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            width: size,
                            height: 6.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3.r),
                              color: isSelected ? 
                                colorScheme.secondary : 
                                colorScheme.primary.withOpacity(0.1),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preWarmScrollPhysics() async {
    const physics = UltraPerformanceScrollPhysics();
    final testVelocities = [
      -3000.0, -2000.0, -1500.0, -1000.0, -500.0, -250.0,
      250.0, 500.0, 1000.0, 1500.0, 2000.0, 3000.0
    ];
    
    final testPixels = [0.0, 200.0, 400.0, 600.0, 800.0, 1000.0];
    
    for (final velocity in testVelocities) {
      for (final pixel in testPixels) {
        final simulation = physics.createBallisticSimulation(
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 2000,
            pixels: pixel,
            viewportDimension: 400,
            axisDirection: AxisDirection.right,
            devicePixelRatio: WidgetsBinding.instance.window.devicePixelRatio,
          ),
          velocity,
        );
        
        if (simulation != null) {
          for (int i = 0; i < 120; i++) {
            simulation.x(i * 16.667);
            simulation.dx(i * 16.667);
          }
        }
      }
    }
  }

  void _initializeCardKeys() {
    for (int i = 0; i < _methods.length; i++) {
      _cardKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    _pageController.removeListener(_optimizedPageUpdate);
    _pageController.dispose();
    _animationController.dispose();
    _prerenderedPages.clear();
    _transformCache.clear();
    _matrixPool.clear();
    _alignmentCache.clear();
    super.dispose();
  }
}

// Extract the card content to a separate stateless widget to improve performance
class MethodCardContent extends StatelessWidget {
  final NumericalMethod method;
  final int index;
  final ColorScheme colorScheme;
  final bool isDark;
  final double parentProgress;

  const MethodCardContent({
    super.key,
    required this.method,
    required this.index,
    required this.colorScheme,
    required this.isDark,
    required this.parentProgress,
  });

  @override
  Widget build(BuildContext context) {
    final progress = parentProgress.abs();
    final isSelected = progress < 0.5;
    final parallax = math.sin(progress * math.pi) * 80.w * (parentProgress < 0 ? 1 : -1);
    
    // More performant glassmorphism implementation
    return Container(
      decoration: BoxDecoration(
        // Base decoration 
        color: isDark 
            ? colorScheme.surface.withOpacity(0.45)
            : const Color(0xFFF5F7FB).withOpacity(0.65),
        borderRadius: BorderRadius.circular(40.r),
        // Enhanced double border for more obvious glass effect
        border: Border.all(
          width: 2.0, // Increased from 1.5
          color: isDark
              ? Colors.white.withOpacity(0.8) // More opaque
              : const Color(0xFF9FB8D8).withOpacity(0.95), // Darker, more visible
        ),
        boxShadow: [
          // Inner glow effect
          BoxShadow(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.25),
            blurRadius: 10.r,
            spreadRadius: 0.5.r,
            // Inset shadow for inner glow
            offset: const Offset(0, 0),
          ),
          // Outer shadow
          BoxShadow(
            color: isDark
                ? colorScheme.primary.withOpacity(0.05)
                : const Color(0xFF8BA3C7).withOpacity(0.35), // More opaque
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
            spreadRadius: 1.r, // Added spread for more visible shadow
          ),
        ],
        // Gradient overlay for glass effect
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ]
              : [
                  Colors.white.withOpacity(0.8), // Increased opacity
                  Colors.white.withOpacity(0.35),
                ],
          stops: const [0.1, 0.9],
        ),
      ),
      // Mark for hardware acceleration
      child: RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.all(method.chapter == 2 ? 24.r : 32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Method number indicator with creative design
              Transform.translate(
                offset: Offset(-parallax * 0.2, 0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: method.chapter == 2 ? 12.w : 16.w,
                        vertical: method.chapter == 2 ? 6.h : 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.secondary.withOpacity(0.15)
                            : colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12.r),
                          bottomRight: Radius.circular(12.r),
                          topRight: Radius.circular(4.r),
                          bottomLeft: Radius.circular(4.r),
                        ),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.secondary.withOpacity(0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (index + 1).toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: isSelected
                                  ? colorScheme.secondary
                                  : colorScheme.primary.withOpacity(0.6),
                              fontSize: method.chapter == 2 ? 14.sp : 16.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            ' / ${NumericalMethod.getMethodsForChapter(method.chapter).length.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: (isSelected
                                  ? colorScheme.secondary
                                  : colorScheme.primary)
                                  .withOpacity(0.4),
                              fontSize: method.chapter == 2 ? 12.sp : 14.sp,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) ...[
                      SizedBox(width: 12.w),
                      Container(
                        width: 24.w,
                        height: 2.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.secondary.withOpacity(0.3),
                              colorScheme.secondary.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: method.chapter == 2 ? 12.h : 24.h),
              
              // Method tag with enhanced design
              Transform.translate(
                offset: Offset(-parallax * 0.4, 0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: method.chapter == 2 ? 10.w : 12.w,
                    vertical: method.chapter == 2 ? 6.h : 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: method.chapter == 2 ? 3.w : 4.w,
                        height: method.chapter == 2 ? 3.w : 4.w,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: method.chapter == 2 ? 6.w : 8.w),
                      Text(
                        method.tag.toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: method.chapter == 2 ? 10.sp : 12.sp,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: method.chapter == 2 ? 12.h : 24.h),
              
              // Method name with creative typography
              Transform.translate(
                offset: Offset(-parallax * 0.4, 0),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.onSurface,
                      colorScheme.onSurface.withOpacity(0.8),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    method.name,
                    style: TextStyle(
                      fontSize: method.chapter == 2 ? 32.sp : 40.sp,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              SizedBox(height: method.chapter == 2 ? 12.h : 16.h),
              
              // Description with enhanced readability
              Transform.translate(
                offset: Offset(-parallax * 0.6, 0),
                child: Text(
                  method.description,
                  style: TextStyle(
                    fontSize: method.chapter == 2 ? 14.sp : 16.sp,
                    color: colorScheme.onSurface.withOpacity(0.75),
                    height: 1.6,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: method.chapter == 2 ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              SizedBox(height: method.chapter == 2 ? 24.h : 32.h),
              
              // Action button
              Transform.translate(
                offset: Offset(-parallax * 0.8, 0),
                child: _buildActionButton(context, isSelected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isSelected) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, scaleValue, child) {
        return Transform.scale(
          scale: 0.85 + (0.15 * scaleValue),
          child: child,
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 280.w,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.15),
              blurRadius: 24.r,
              offset: Offset(0, 12.h),
              spreadRadius: -4.r,
            ),
            if (isSelected) ...[
              BoxShadow(
                color: colorScheme.tertiary.withOpacity(0.2),
                blurRadius: 32.r,
                offset: Offset(0, 16.h),
                spreadRadius: -8.r,
              ),
            ],
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
            colors: isSelected
                ? [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.95),
                    colorScheme.tertiary,
                  ]
                : [
                    colorScheme.primary.withOpacity(0.8),
                    colorScheme.primary.withOpacity(0.75),
                    colorScheme.primary.withOpacity(0.8),
                  ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: () => _navigateToMethod(context),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButtonIcon(isSelected),
                  SizedBox(width: 12.w),
                  Flexible(
                    child: _buildButtonText(),
                  ),
                  SizedBox(width: 12.w),
                  _buildButtonArrow(isSelected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToMethod(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          switch (method.name) {
            case 'Bisection Method':
              return const BisectionMethodScreen();
            case 'False Position Method':
              return const FalsePositionMethodScreen();
            case 'Simple Fixed Point Method':
              return const SimpleFixedPointMethodScreen();
            case 'Newton Method':
              return const NewtonMethodScreen();
            case 'Secant Method':
              return const SecantMethodScreen();
            case 'Gauss Elimination Method':
              return const GaussEliminationMethodScreen();
            case 'LU Decomposition Method':
              return const LUDecompositionMethodScreen();
            case 'Gauss Jordan Method':
              return const GaussJordanMethodScreen();
            case 'Cramer Method':
              return const CramerMethodScreen();
            default:
              return const BisectionMethodScreen();
          }
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildButtonIcon(bool isSelected) {
    return Container(
      width: 32.w,
      height: 32.w,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSelected)
            Positioned(
              right: 4.w,
              bottom: 4.h,
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.r),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.all(6.r),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.8),
                ],
              ).createShader(bounds),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.9),
            ],
          ).createShader(bounds),
          child: Text(
            "Let's start",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
              letterSpacing: 0.3,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          'Interactive Tutorial',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
            fontSize: 10.sp,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildButtonArrow(bool isSelected) {
    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSelected)
            Positioned(
              right: -2.w,
              bottom: -2.h,
              child: Container(
                width: 16.w,
                height: 16.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.r),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
            ),
          Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white.withOpacity(0.9),
            size: 12.sp,
          ),
        ],
      ),
    );
  }
}

// Remove unused pattern class definitions
class AnimatedBackgroundPatterns extends StatefulWidget {
  final bool isDark;
  final ColorScheme colorScheme;
  
  const AnimatedBackgroundPatterns({
    super.key,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  State<AnimatedBackgroundPatterns> createState() => _AnimatedBackgroundPatternsState();
}

class _AnimatedBackgroundPatternsState extends State<AnimatedBackgroundPatterns> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.isDark ? widget.colorScheme.surface : widget.colorScheme.background,
    );
  }
} 