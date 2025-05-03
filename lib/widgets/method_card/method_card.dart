import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/numerical_method.dart';
import '../../screens/bisection_method_screen.dart';
import '../../screens/false_position_method_screen.dart';
import '../../screens/simple_fixed_point_method_screen.dart';
import '../../screens/newton_method_screen.dart';
import 'dart:math' as math;

class MethodCard extends StatelessWidget {
  final NumericalMethod method;
  final int index;
  final ColorScheme colorScheme;
  final bool isDark;
  final double parentProgress;
  final int totalMethods;
  final bool isSelected;

  const MethodCard({
    super.key,
    required this.method,
    required this.index,
    required this.colorScheme,
    required this.isDark,
    required this.parentProgress,
    required this.totalMethods,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Optimized parallax calculations using curved progress
    final curvedProgress = Curves.easeOutCubic.transform(parentProgress.abs()) * (parentProgress < 0 ? -1 : 1);
    final baseParallax = -300.w * curvedProgress;
    
    // Optimized parallax multipliers with exponential progression
    final decorativeParallax = baseParallax * 0.1;  // Subtle background movement
    final numberParallax = baseParallax * math.pow(0.4, 2);  // Faster for small elements
    final tagParallax = baseParallax * math.pow(0.5, 2);     // Medium speed for tag
    final titleParallax = baseParallax * math.pow(0.6, 2);   // Slower for title
    final descriptionParallax = baseParallax * math.pow(0.7, 2); // Even slower for description
    final buttonParallax = baseParallax * math.pow(0.8, 2);  // Slowest for button

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isSelected) ...[
            // Optimized background elements with subtle parallax
            Positioned(
              right: -40.w + decorativeParallax,
              top: -20.h,
              child: Transform.rotate(
                angle: math.pi / 6 + (curvedProgress * 0.1),  // Slight rotation based on scroll
                child: Container(
                  width: 160.w,
                  height: 160.w,
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.1),
                        colorScheme.tertiary.withOpacity(0.05),
                        colorScheme.secondary.withOpacity(0.1),
                        colorScheme.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(80.r),
                      bottomRight: Radius.circular(80.r),
                    ),
                  ),
                ),
              ),
            ),
            // Optimized decorative elements
            Positioned(
              left: 20.w - decorativeParallax,
              bottom: 40.h,
              child: Transform.rotate(
                angle: -math.pi / 12 - (curvedProgress * 0.05),  // Subtle counter-rotation
                child: Container(
                  width: 120.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary.withOpacity(0),
                        colorScheme.secondary.withOpacity(0.3),
                        colorScheme.secondary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Main content with optimized transforms
          Padding(
            padding: EdgeInsets.all(32.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Method number with optimized parallax
                RepaintBoundary(
                  child: Transform.translate(
                    offset: Offset(numberParallax, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                ' / ${totalMethods.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: (isSelected
                                      ? colorScheme.secondary
                                      : colorScheme.primary)
                                      .withOpacity(0.4),
                                  fontSize: 14.sp,
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
                ),

                SizedBox(height: 24.h),

                // Method tag with optimized parallax
                RepaintBoundary(
                  child: Transform.translate(
                    offset: Offset(tagParallax, 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
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
                            width: 4.w,
                            height: 4.w,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            method.tag.toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Method name with optimized parallax
                RepaintBoundary(
                  child: Transform.translate(
                    offset: Offset(titleParallax, 0),
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
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: Colors.white,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Description with optimized parallax
                RepaintBoundary(
                  child: Transform.translate(
                    offset: Offset(descriptionParallax, 0),
                    child: Text(
                      method.description,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: colorScheme.onSurface.withOpacity(0.75),
                        height: 1.6,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                SizedBox(height: 32.h),

                // Action button with optimized parallax
                RepaintBoundary(
                  child: Transform.translate(
                    offset: Offset(buttonParallax, 0),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
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
                            BoxShadow(
                              color: colorScheme.secondary.withOpacity(0.1),
                              blurRadius: 16.r,
                              offset: Offset(0, 8.h),
                              spreadRadius: -2.r,
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
                          splashColor: Colors.white.withOpacity(0.1),
                          highlightColor: Colors.white.withOpacity(0.05),
                          onTap: () {
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
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Left decorative element
                                Container(
                                  width: 36.w,
                                  height: 36.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (isSelected) ...[
                                        Positioned(
                                          right: 4.w,
                                          bottom: 4.h,
                                          child: Container(
                                            width: 14.w,
                                            height: 14.w,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      Container(
                                        padding: EdgeInsets.all(8.r),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 18.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                // Text content
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Let's start",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16.sp,
                                        letterSpacing: 0.3,
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Interactive Tutorial',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w400,
                                        fontSize: 11.sp,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 16.w),
                                // Right decorative element
                                Container(
                                  width: 28.w,
                                  height: 28.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (isSelected) ...[
                                        Positioned(
                                          right: -3.w,
                                          bottom: -3.h,
                                          child: Container(
                                            width: 20.w,
                                            height: 20.w,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 14.sp,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Decorative elements
          if (isSelected) ...[
            Positioned(
              right: 20.w + decorativeParallax,
              top: 20.h,
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.secondary.withOpacity(0.2),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20.r),
                    bottomLeft: Radius.circular(20.r),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 40.w - decorativeParallax,
              bottom: 40.h,
              child: Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                    width: 1,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 