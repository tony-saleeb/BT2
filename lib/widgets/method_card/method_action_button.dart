import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/numerical_method.dart';
import '../../screens/bisection_method_screen.dart';
import '../../screens/false_position_method_screen.dart';
import '../../screens/simple_fixed_point_method_screen.dart';
import '../../screens/newton_method_screen.dart';

class MethodActionButton extends StatelessWidget {
  final bool isSelected;
  final ColorScheme colorScheme;
  final double parallax;
  final NumericalMethod method;

  const MethodActionButton({
    super.key,
    required this.isSelected,
    required this.colorScheme,
    required this.parallax,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-parallax * 0.8, 0),
      child: TweenAnimationBuilder<double>(
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
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
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16.w),
                        // Text content
                        Flexible(
                          child: Column(
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
                                    fontSize: 16.sp,
                                    letterSpacing: 0.3,
                                    height: 1.2,
                                  ),
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
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 