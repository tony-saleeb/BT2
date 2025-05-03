import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MethodTag extends StatelessWidget {
  final String tag;
  final ColorScheme colorScheme;
  final double parallax;

  const MethodTag({
    super.key,
    required this.tag,
    required this.colorScheme,
    required this.parallax,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-parallax * 0.4, 0),
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
              tag.toUpperCase(),
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
    );
  }
} 