import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
}

class FunctionGraph extends StatelessWidget {
  final String function;
  final List<Point> points;
  final double xMin;
  final double xMax;
  final bool showPoints;
  final bool showAxes;
  final bool showGrid;
  final bool showLabels;
  final double pointRadius;
  final double lineWidth;

  const FunctionGraph({
    super.key,
    required this.function,
    required this.points,
    required this.xMin,
    required this.xMax,
    this.showPoints = true,
    this.showAxes = true,
    this.showGrid = true,
    this.showLabels = true,
    this.pointRadius = 4,
    this.lineWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _FunctionGraphPainter(
            function: function,
            points: points,
            xMin: xMin,
            xMax: xMax,
            showPoints: showPoints,
            showAxes: showAxes,
            showGrid: showGrid,
            showLabels: showLabels,
            pointRadius: pointRadius,
            lineWidth: lineWidth,
            primaryColor: colorScheme.primary,
            tertiaryColor: colorScheme.tertiary,
            surfaceColor: colorScheme.surface,
            outlineColor: colorScheme.outline,
          ),
        );
      },
    );
  }
}

class _FunctionGraphPainter extends CustomPainter {
  final String function;
  final List<Point> points;
  final double xMin;
  final double xMax;
  final bool showPoints;
  final bool showAxes;
  final bool showGrid;
  final bool showLabels;
  final double pointRadius;
  final double lineWidth;
  final Color primaryColor;
  final Color tertiaryColor;
  final Color surfaceColor;
  final Color outlineColor;

  late final Parser _parser;
  late final ContextModel _context;
  late final Expression _exp;
  late final Variable _x;

  _FunctionGraphPainter({
    required this.function,
    required this.points,
    required this.xMin,
    required this.xMax,
    required this.showPoints,
    required this.showAxes,
    required this.showGrid,
    required this.showLabels,
    required this.pointRadius,
    required this.lineWidth,
    required this.primaryColor,
    required this.tertiaryColor,
    required this.surfaceColor,
    required this.outlineColor,
  }) {
    _parser = Parser();
    _context = ContextModel();
    _x = Variable('x');
    _context.bindVariable(_x, Number(0));
    _exp = _parser.parse(function);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = tertiaryColor;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outlineColor.withOpacity(0.1);

    final axesPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outlineColor.withOpacity(0.5);

    if (showGrid) {
      _drawGrid(canvas, size, gridPaint);
    }

    if (showAxes) {
      _drawAxes(canvas, size, axesPaint);
    }

    if (showLabels) {
      _drawLabels(canvas, size);
    }

    // Draw function
    paint.shader = LinearGradient(
      colors: [primaryColor, tertiaryColor],
    ).createShader(Offset.zero & size);

    final path = Path();
    var first = true;

    for (var i = 0; i <= 100; i++) {
      final x = xMin + (xMax - xMin) * i / 100;
      _context.bindVariable(_x, Number(x));
      final y = _exp.evaluate(EvaluationType.REAL, _context);

      final point = _toPixel(x, y, size);
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, paint);

    if (showPoints) {
      for (final point in points) {
        final pixel = _toPixel(point.x, point.y, size);
        canvas.drawCircle(pixel, pointRadius, pointPaint);
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    final xStep = (xMax - xMin) / 10;
    final yMin = points.map((p) => p.y).reduce(math.min) - 1;
    final yMax = points.map((p) => p.y).reduce(math.max) + 1;
    final yStep = (yMax - yMin) / 10;

    // Vertical lines
    for (var x = xMin; x <= xMax; x += xStep) {
      final p1 = _toPixel(x, yMin, size);
      final p2 = _toPixel(x, yMax, size);
      canvas.drawLine(p1, p2, paint);
    }

    // Horizontal lines
    for (var y = yMin; y <= yMax; y += yStep) {
      final p1 = _toPixel(xMin, y, size);
      final p2 = _toPixel(xMax, y, size);
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, Paint paint) {
    final yMin = points.map((p) => p.y).reduce(math.min) - 1;
    final yMax = points.map((p) => p.y).reduce(math.max) + 1;

    // X-axis
    if (yMin <= 0 && yMax >= 0) {
      final p1 = _toPixel(xMin, 0, size);
      final p2 = _toPixel(xMax, 0, size);
      canvas.drawLine(p1, p2, paint);
    }

    // Y-axis
    if (xMin <= 0 && xMax >= 0) {
      final p1 = _toPixel(0, yMin, size);
      final p2 = _toPixel(0, yMax, size);
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawLabels(Canvas canvas, Size size) {
    final yMin = points.map((p) => p.y).reduce(math.min) - 1;
    final yMax = points.map((p) => p.y).reduce(math.max) + 1;
    final xStep = (xMax - xMin) / 10;
    final yStep = (yMax - yMin) / 10;

    final textStyle = TextStyle(
      color: outlineColor.withOpacity(0.5),
      fontSize: 10,
    );

    // X-axis labels
    for (var x = xMin; x <= xMax; x += xStep) {
      if (x == 0) continue;
      final p = _toPixel(x, 0, size);
      final textSpan = TextSpan(
        text: x.toStringAsFixed(1),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(p.dx - textPainter.width / 2, size.height - 20),
      );
    }

    // Y-axis labels
    for (var y = yMin; y <= yMax; y += yStep) {
      if (y == 0) continue;
      final p = _toPixel(0, y, size);
      final textSpan = TextSpan(
        text: y.toStringAsFixed(1),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(10, p.dy - textPainter.height / 2),
      );
    }
  }

  Offset _toPixel(double x, double y, Size size) {
    final yMin = points.map((p) => p.y).reduce(math.min) - 1;
    final yMax = points.map((p) => p.y).reduce(math.max) + 1;

    return Offset(
      (x - xMin) / (xMax - xMin) * size.width,
      size.height - (y - yMin) / (yMax - yMin) * size.height,
    );
  }

  @override
  bool shouldRepaint(_FunctionGraphPainter oldDelegate) {
    return function != oldDelegate.function ||
        points != oldDelegate.points ||
        xMin != oldDelegate.xMin ||
        xMax != oldDelegate.xMax ||
        showPoints != oldDelegate.showPoints ||
        showAxes != oldDelegate.showAxes ||
        showGrid != oldDelegate.showGrid ||
        showLabels != oldDelegate.showLabels ||
        pointRadius != oldDelegate.pointRadius ||
        lineWidth != oldDelegate.lineWidth ||
        primaryColor != oldDelegate.primaryColor ||
        tertiaryColor != oldDelegate.tertiaryColor ||
        surfaceColor != oldDelegate.surfaceColor ||
        outlineColor != oldDelegate.outlineColor;
  }
} 