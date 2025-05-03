import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MethodNumberIndicator extends StatelessWidget {
  final int index;
  final bool isSelected;
  final ColorScheme colorScheme;
  final double parallax;
  final int totalMethods;

  const MethodNumberIndicator({
    super.key,
    required this.index,
    required this.isSelected,
    required this.colorScheme,
    required this.parallax,
    required this.totalMethods,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-parallax * 0.2, 0),
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
    );
  }
} 