import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to Numerical Analysis',
      'description': 'A powerful toolkit for solving mathematical problems with numerical methods.',
      'image': 'assets/onboarding1.png',
      'imageInBase': false,
      'imageWidget': _buildModernIllustration1(),
    },
    {
      'title': 'Interactive Methods',
      'description': 'Work with various methods including Bisection, False Position, Secant and more.',
      'image': 'assets/onboarding2.png',
      'imageInBase': false,
      'imageWidget': _buildModernIllustration2(),
    },
    {
      'title': 'Visualize Solutions',
      'description': 'See your results through dynamic graphs and detailed step-by-step solutions.',
      'image': 'assets/onboarding3.png',
      'imageInBase': false, 
      'imageWidget': _buildModernIllustration3(),
    },
  ];

  static Widget _buildModernIllustration1() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle with gradient
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2C5282).withOpacity(0.1),
                  const Color(0xFF2C5282).withOpacity(0.05),
                ],
              ),
            ),
          ),
          
          // Animated calculator elements
          _buildAnimatedCalculator(),
          
          // Floating formula elements
          Positioned(
            top: 50,
            right: 30,
            child: _buildFormulaChip('f(x)=0'),
          ),
          
          Positioned(
            bottom: 60,
            left: 40,
            child: _buildFormulaChip('x₀=a+b'),
          ),
          
          // Animated particles
          ...List.generate(5, (index) => _buildFloatingParticle(index, const Color(0xFF2C5282))),
        ],
      ),
    );
  }
  
  static Widget _buildModernIllustration2() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle with gradient
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0891B2).withOpacity(0.1),
                  const Color(0xFF0891B2).withOpacity(0.05),
                ],
              ),
            ),
          ),
          
          // Interactive graph visualization
          CustomPaint(
            size: const Size(200, 200),
            painter: InteractiveGraphPainter(
              lineColor: const Color(0xFF0891B2),
            ),
          ),
          
          // Floating elements
          Positioned(
            top: 45,
            left: 35,
            child: _buildMethodChip('Bisection'),
          ),
          
          Positioned(
            bottom: 50,
            right: 35,
            child: _buildMethodChip('Secant'),
          ),
          
          // Animated particles
          ...List.generate(5, (index) => _buildFloatingParticle(index, const Color(0xFF0891B2))),
        ],
      ),
    );
  }
  
  static Widget _buildModernIllustration3() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle with gradient
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4C51C6).withOpacity(0.1),
                  const Color(0xFF4C51C6).withOpacity(0.05),
                ],
              ),
            ),
          ),
          
          // Results visualization
          _buildResultsVisualization(),
          
          // Floating elements
          Positioned(
            top: 50,
            right: 40,
            child: _buildResultChip('x = 1.234'),
          ),
          
          Positioned(
            bottom: 70,
            left: 50,
            child: _buildResultChip('Error: 0.001%'),
          ),
          
          // Animated particles
          ...List.generate(5, (index) => _buildFloatingParticle(index, const Color(0xFF4C51C6))),
        ],
      ),
    );
  }
  
  // Helper widgets for modern illustrations
  static Widget _buildAnimatedCalculator() {
    return Container(
      width: 140,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C5282).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calculator display
          Container(
            width: double.infinity,
            height: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C5282).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'f(1.234) = 0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2C5282),
                ),
              ),
            ),
          ),
          
          // Calculator buttons
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 1.0,
              padding: const EdgeInsets.all(8),
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(12, (index) {
                String btnText = '';
                if (index < 9) {
                  btnText = '${index + 1}';
                } else if (index == 9) {
                  btnText = '0';
                } else if (index == 10) {
                  btnText = '.';
                } else {
                  btnText = '=';
                }
                
                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: index == 11 
                        ? const Color(0xFF2C5282) 
                        : const Color(0xFF2C5282).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      btnText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: index == 11 ? Colors.white : const Color(0xFF2C5282),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildFormulaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C5282).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Color(0xFF2C5282),
        ),
      ),
    );
  }
  
  static Widget _buildMethodChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891B2).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 14,
            color: Color(0xFF0891B2),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0891B2),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildResultChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C51C6).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check,
            size: 14,
            color: Color(0xFF4C51C6),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF4C51C6),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget _buildFloatingParticle(int index, Color color) {
    final random = math.Random(index * 10);
    final size = random.nextDouble() * 10 + 5;
    final top = random.nextDouble() * 220;
    final left = random.nextDouble() * 220;
    final opacity = random.nextDouble() * 0.5 + 0.1;
    
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
  
  static Widget _buildResultsVisualization() {
    return Container(
      width: 200,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C51C6).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Result view header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF4C51C6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Text(
              'Solution',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Graph visualization
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CustomPaint(
                size: const Size(180, 100),
                painter: ResultGraphPainter(),
              ),
            ),
          ),
          
          // Steps indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  width: 30,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index < 3 
                        ? const Color(0xFF4C51C6) 
                        : const Color(0xFF4C51C6).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Save the onboarding completed status
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
          child: Column(
            children: [
              // Skip button at the top-right with fade animation
              AnimatedOpacity(
                opacity: _currentPage == _numPages - 1 ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 16.h, right: 24.w),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _currentPage == _numPages - 1 ? null : _completeOnboarding,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal:
                              16.w, vertical: 8.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12.sp,
                                  color: colorScheme.primary,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: _numPages,
                  itemBuilder: (context, index) {
                    return _buildPage(
                      title: _pages[index]['title'],
                      description: _pages[index]['description'],
                      imageWidget: _pages[index]['imageWidget'],
                    );
                  },
                ),
              ),

              // Page indicator and navigation buttons
              Padding(
                padding: EdgeInsets.only(bottom: 48.h, left: 24.w, right: 24.w),
                child: Column(
                  children: [
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _numPages,
                        (index) => _buildPageIndicator(index),
                      ),
                    ),
                    SizedBox(height: 32.h),
                    
                    // Navigation buttons
                    _currentPage > 0
                        ? _buildNavigationButtons(colorScheme)
                        : _buildButton(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        Container(
          width: 120.w,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.r),
            color: colorScheme.surface,
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28.r),
              onTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.ease,
                );
              },
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16.sp,
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Next/Get Started button
        Container(
          width: 200.w,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.r),
            gradient: LinearGradient(
              colors: [
                colorScheme.secondary,
                colorScheme.tertiary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.secondary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28.r),
              onTap: _currentPage == _numPages - 1
                  ? _completeOnboarding
                  : () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.ease,
                      );
                    },
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentPage == _numPages - 1 ? 'Get Started' : 'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.arrow_forward,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage({
    required String title,
    required String description,
    required Widget imageWidget,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image/Icon section
          Expanded(
            flex: 5,
            child: Container(
              padding: EdgeInsets.all(24.r),
              child: Center(
                child: Hero(
                  tag: 'onboarding_image_$_currentPage',
                  child: imageWidget,
                ),
              ),
            ),
          ),
          
          // Text content section
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: colorScheme.onBackground.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isCurrentPage = index == _currentPage;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      height: 10.0,
      width: isCurrentPage ? 24.0 : 10.0,
      decoration: BoxDecoration(
        color: isCurrentPage 
            ? colorScheme.primary 
            : colorScheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildButton(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: LinearGradient(
          colors: [
            colorScheme.secondary,
            colorScheme.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28.r),
          onTap: () {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.ease,
            );
          },
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_forward,
                  size: 20.sp,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for graph illustration
class GraphPainter extends CustomPainter {
  final Color color;
  
  GraphPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
      
    final path = Path();
    
    // Starting point at the left side
    path.moveTo(0, size.height * 0.7);
    
    // Curve points to create a function graph look
    path.cubicTo(
      size.width * 0.2, size.height * 0.9,
      size.width * 0.4, size.height * 0.2,
      size.width * 0.6, size.height * 0.5,
    );
    
    path.cubicTo(
      size.width * 0.8, size.height * 0.8,
      size.width * 0.9, size.height * 0.4,
      size.width, size.height * 0.3,
    );
    
    canvas.drawPath(path, paint);
    
    // Draw axes
    final axisPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    // Draw x-axis (horizontal)
    canvas.drawLine(
      Offset(0, size.height * 0.98),
      Offset(size.width, size.height * 0.98),
      axisPaint,
    );
    
    // Draw y-axis (vertical)
    canvas.drawLine(
      Offset(size.width * 0.02, 0),
      Offset(size.width * 0.02, size.height),
      axisPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// More advanced interactive graph painter
class InteractiveGraphPainter extends CustomPainter {
  final Color lineColor;
  
  InteractiveGraphPainter({required this.lineColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    // Draw coordinate system
    final axisPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // X-axis
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      axisPaint,
    );
    
    // Y-axis
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      axisPaint,
    );
    
    // Draw function curve
    final path = Path();
    
    // Sinusoidal function
    path.moveTo(0, size.height / 2);
    
    for (double x = 0; x <= size.width; x += 1) {
      // Create a sin wave but add some special deformation to make it look like a
      // more complex function
      final normalizedX = (x / size.width - 0.5) * 4 * math.pi;
      final y = size.height / 2 - 
          math.sin(normalizedX) * 40 * 
          (1 / (1 + 0.1 * (normalizedX * normalizedX)));
      
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
    
    // Draw points/dots on the curve to represent iterations
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final pointStrokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Root approximation points
    List<Offset> points = [
      Offset(size.width * 0.2, size.height * 0.35),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.45),
      Offset(size.width * 0.8, size.height * 0.52),
    ];
    
    // Draw connector lines between points
    final dashPaint = Paint()
      ..color = lineColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], dashPaint);
    }
    
    // Draw the points
    for (var point in points) {
      canvas.drawCircle(point, 6, pointPaint);
      canvas.drawCircle(point, 6, pointStrokePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Results graph painter
class ResultGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw axes
    final axisPaint = Paint()
      ..color = const Color(0xFF4C51C6).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // X-axis
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      axisPaint,
    );
    
    // Y-axis
    canvas.drawLine(
      Offset(size.width * 0.1, 0),
      Offset(size.width * 0.1, size.height * 0.8),
      axisPaint,
    );
    
    // Draw function curve
    final paint = Paint()
      ..color = const Color(0xFF4C51C6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.5);
    
    // Quadratic function with a root
    for (double x = 0; x <= size.width; x += 1) {
      final normalizedX = (x / size.width - 0.1) * 3;
      final y = size.height * 0.5 - 
          40 * (normalizedX - 0.5) * (normalizedX - 1.5) * 0.5;
      
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
    
    // Draw root point with highlight
    final rootX = size.width * 0.6;
    final rootY = size.height * 0.8;
    
    // Draw vertical line to the root
    final dashPaint = Paint()
      ..color = const Color(0xFF4C51C6).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(rootX, 0),
      Offset(rootX, size.height * 0.8),
      dashPaint,
    );
    
    // Draw the root point
    final pointPaint = Paint()
      ..color = const Color(0xFF4C51C6)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(rootX, rootY), 5, pointPaint);
    
    // Add a highlight effect
    final highlightPaint = Paint()
      ..color = const Color(0xFF4C51C6).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(rootX, rootY), 12, highlightPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 