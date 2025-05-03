import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MethodDescription extends StatelessWidget {
  final String description;
  final ColorScheme colorScheme;
  final double parallax;

  const MethodDescription({
    super.key,
    required this.description,
    required this.colorScheme,
    required this.parallax,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-parallax * 0.6, 0),
      child: Text(
        description,
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
    );
  }
} 