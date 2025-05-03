import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MethodTitle extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;
  final double parallax;

  const MethodTitle({
    super.key,
    required this.title,
    required this.colorScheme,
    required this.parallax,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
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
          title,
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: Colors.white,
            letterSpacing: -1.0,
          ),
        ),
      ),
    );
  }
} 