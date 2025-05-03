import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;

class MethodCardBackground extends StatelessWidget {
  final bool isSelected;
  final ColorScheme colorScheme;
  final double parallax;

  const MethodCardBackground({
    super.key,
    required this.isSelected,
    required this.colorScheme,
    required this.parallax,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isSelected) ...[
          // Geometric background elements
          Positioned(
            right: -40.w + parallax * 0.3,
            top: -20.h,
            child: Transform.rotate(
              angle: math.pi / 6,
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
          // Decorative line elements
          Positioned(
            left: 20.w - parallax * 0.2,
            bottom: 40.h,
            child: Transform.rotate(
              angle: -math.pi / 12,
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
          // Right top decorative element
          Positioned(
            right: 20.w,
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
          // Left bottom circle
          Positioned(
            left: 40.w,
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
    );
  }
} 