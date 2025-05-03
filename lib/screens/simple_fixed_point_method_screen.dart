import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import './simple_fixed_point_solution_screen.dart';
import '../models/simple_fixed_point_method.dart';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';

class PowerNotationFormatter extends TextInputFormatter {
  final Map<String, String> superscriptMap;

  PowerNotationFormatter(this.superscriptMap);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    int cursorPosition = newValue.selection.baseOffset;
    
    // If we're adding a character and the old text had a superscript,
    // make sure we don't lose it
    if (text.length > oldValue.text.length) {
      for (var entry in superscriptMap.entries) {
        String superscript = entry.value;
        if (oldValue.text.contains(superscript)) {
          // Check if the superscript was replaced with its caret form
          String caretForm = entry.key;
          if (text.contains(caretForm)) {
            // Keep the superscript form
            text = text.replaceFirst(caretForm, superscript);
            cursorPosition = newValue.selection.baseOffset;
          }
        }
      }
    }
    
    // Convert any new caret numbers to superscript
    if (text.contains('^')) {
      String newText = text;
      int offset = cursorPosition;
      
      for (var entry in superscriptMap.entries) {
        while (newText.contains(entry.key)) {
          final int index = newText.indexOf(entry.key);
          newText = newText.replaceFirst(entry.key, entry.value);
          
          if (index < cursorPosition) {
            offset--;
          }
        }
      }
      
      if (newText != text) {
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: offset),
        );
      }
    }
    
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

// Add these classes after PowerNotationFormatter class and before SimpleFixedPointMethodScreen class

class GridBackgroundPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final bool isDark;
  final double animationValue;

  GridBackgroundPainter({
    required this.colorScheme,
    required this.isDark,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = colorScheme.primary.withOpacity(0.05 * animationValue)
      ..strokeWidth = 0.5;

    // Draw horizontal grid lines
    final int horizontalLinesCount = 10;
    final double horizontalSpacing = size.height / horizontalLinesCount;
    
    for (int i = 0; i <= horizontalLinesCount; i++) {
      final y = i * horizontalSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical grid lines
    final int verticalLinesCount = 10;
    final double verticalSpacing = size.width / verticalLinesCount;
    
    for (int i = 0; i <= verticalLinesCount; i++) {
      final x = i * verticalSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw x and y axes
    final Paint axesPaint = Paint()
      ..color = colorScheme.secondary.withOpacity(0.1 * animationValue)
      ..strokeWidth = 1.0;
    
    // X axis
    final double xAxis = size.height / 2;
    canvas.drawLine(Offset(0, xAxis), Offset(size.width, xAxis), axesPaint);
    
    // Y axis
    final double yAxis = size.width / 2;
    canvas.drawLine(Offset(yAxis, 0), Offset(yAxis, size.height), axesPaint);
  }

  @override
  bool shouldRepaint(GridBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.isDark != isDark;
  }
}

class FunctionGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> terms;
  final ColorScheme colorScheme;
  final bool isDark;

  FunctionGraphPainter({
    required this.terms,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (terms.isEmpty) return;

    final Paint functionPaint = Paint()
      ..color = colorScheme.secondary
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;
    
    // Draw function curve
    final Path path = Path();
    bool isFirst = true;

    // Define range for x values on grid
    final double xMin = -5.0;
    final double xMax = 5.0;
    final double yMin = -5.0;
    final double yMax = 5.0;
    
    // Translate grid coordinates to canvas coordinates
    double gridToCanvasX(double x) => ((x - xMin) / (xMax - xMin)) * width;
    double gridToCanvasY(double y) => height - ((y - yMin) / (yMax - yMin)) * height;
    
    // Function to evaluate polynomial at point x
    double evalFunction(double x) {
      double result = 0.0;
      for (final term in terms) {
        final double coefficient = term['coefficient'];
        final int power = term['power'];
        final bool isVariable = term['isVariable'];
        
        if (isVariable) {
          result += coefficient * pow(x, power);
        } else {
          result += coefficient;
        }
      }
      return result;
    }
    
    // Sample points to draw the curve
    final int samples = 100;
    final double dx = (xMax - xMin) / samples;
    
    for (int i = 0; i <= samples; i++) {
      final double x = xMin + i * dx;
      final double y = evalFunction(x);
      
      // Only draw if y is within range
      if (y >= yMin && y <= yMax) {
        final double canvasX = gridToCanvasX(x);
        final double canvasY = gridToCanvasY(y);
        
        if (isFirst) {
          path.moveTo(canvasX, canvasY);
          isFirst = false;
        } else {
          path.lineTo(canvasX, canvasY);
        }
      } else if (!isFirst) {
        // Handle case where curve goes out of bounds
        isFirst = true;
      }
    }
    
    canvas.drawPath(path, functionPaint);
  }

  @override
  bool shouldRepaint(FunctionGraphPainter oldDelegate) {
    return oldDelegate.terms != terms;
  }
}

class SimpleFixedPointMethodScreen extends StatefulWidget {
  const SimpleFixedPointMethodScreen({super.key});

  @override
  State<SimpleFixedPointMethodScreen> createState() => _SimpleFixedPointMethodScreenState();
}

class _SimpleFixedPointMethodScreenState extends State<SimpleFixedPointMethodScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  var _functionController = TextEditingController();
  final _x0Controller = TextEditingController();
  final _errorController = TextEditingController();
  final _iterationsController = TextEditingController();
  final _coefficientController = TextEditingController();
  final _powerController = TextEditingController();
  final _constantController = TextEditingController();
  
  bool _useError = true;
  bool _isVariableMode = true;
  int _decimalPlaces = 3;
  List<Map<String, dynamic>> _terms = [];

  late final AnimationController _headerAnimationController;

  final Map<String, String> _superscriptMap = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  };

  String _convertToSuperscript(String number) {
    String result = '';
    for (var digit in number.split('')) {
      result += _superscriptMap[digit] ?? digit;
    }
    return result;
  }

  // Add this near the top of the class with other declarations
  late final ValueNotifier<List<Map<String, dynamic>>> _historyNotifier;

  @override
  void initState() {
    super.initState();
    _historyNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
    _initializeAnimations();
    _initializeControllers();
    // Set initial value of _isValidInterval based on x₀
    _loadHistory(); // Load history when screen initializes
  }

  void _initializeControllers() {
    _functionController = TextEditingController();
  }


  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerAnimationController.forward();
  }

  @override
  void dispose() {
    _historyNotifier.dispose();
    _headerAnimationController.dispose();
    _functionController.dispose();
    _x0Controller.dispose();
    _errorController.dispose();
    _iterationsController.dispose();
    _coefficientController.dispose();
    _powerController.dispose();
    _constantController.dispose();
    super.dispose();
  }

  void _clearFields() {
    setState(() {
      _functionController.clear();
      _x0Controller.clear();
      _errorController.clear();
      _iterationsController.clear();
      _coefficientController.clear();
      _powerController.clear();
      _constantController.clear();
      _terms.clear();
    });
  }

  String _convertSuperscriptToRegular(String text) {
    final Map<String, String> reverseMap = {
      '⁰': '^0', '¹': '^1', '²': '^2', '³': '^3', '⁴': '^4',
      '⁵': '^5', '⁶': '^6', '⁷': '^7', '⁸': '^8', '⁹': '^9',
    };
    
    String result = text;
    for (var entry in reverseMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  void _calculateAndNavigate() {
    if (_formKey.currentState!.validate()) {
      // Save to history before calculation
      _saveToHistory();

      try {
        // Get the values
        final x0 = double.parse(_x0Controller.text);
        final error = _useError 
            ? double.parse(_errorController.text)
            : 0.001; // Default error
        
        final maxIterations = _useError 
            ? 50 // Default max iterations
            : int.parse(_iterationsController.text);

        // Convert superscript to regular power notation and ensure proper spacing
        String functionText = _convertSuperscriptToRegular(_functionController.text);
        debugPrint('Original function: ${_functionController.text}');
        debugPrint('After superscript conversion: $functionText');
        
        // Format the function string for math_expressions package
        functionText = functionText
            .replaceAll(' ', '') // Remove all spaces
            .replaceAll('²', '^2')
            .replaceAll('³', '^3')
            .replaceAll('⁴', '^4')
            .replaceAll('⁵', '^5')
            .replaceAll('⁶', '^6')
            .replaceAll('⁷', '^7')
            .replaceAll('⁸', '^8')
            .replaceAll('⁹', '^9')
            .replaceAll('⁰', '^0');

        // Add multiplication operator between coefficient and x
        functionText = functionText.replaceAll('x', '*x');
        // Handle special case of -x (no coefficient)
        functionText = functionText.replaceAll('-*x', '-x');
        // Handle special case of +x (no coefficient)
        functionText = functionText.replaceAll('+*x', '+x');
        // Handle start of string (no sign)
        if (functionText.startsWith('*x')) {
            functionText = functionText.substring(1);
        }

        debugPrint('Final formatted function: $functionText');
        debugPrint('x0: ${_x0Controller.text}');
        debugPrint('error: $error');
        debugPrint('maxIterations: $maxIterations');

        // Create SimpleFixedPointMethod instance and calculate
        final method = SimpleFixedPointMethod(
          function: functionText,
          x0: x0,
          es: error,
          maxIterations: maxIterations,
          decimalPlaces: _decimalPlaces,
        );
        
        final results = method.solve();

        // Navigate to solution screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleFixedPointSolutionScreen(
              results: results,
              function: _functionController.text,
              decimalPlaces: _decimalPlaces,
            ),
          ),
        );
      } catch (e) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'An error occurred while calculating:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Debug Information:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Function: ${_functionController.text}\n'
                  'x₀: ${_x0Controller.text}\n'
                  'Error/Iterations: ${_useError ? _errorController.text : _iterationsController.text}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        debugPrint('Calculation error: $e');
      }
    }
  }

  void _showFunctionDialog() {
    // Create a local copy of terms for the dialog
    List<Map<String, dynamic>> dialogTerms = List.from(_terms);
    
    _coefficientController.clear();
    _powerController.clear();
    _constantController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.1),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: -8,
                    ),
                    BoxShadow(
                      color: colorScheme.secondary.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with gradient background (fixed at top)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.secondary.withOpacity(0.1),
                            colorScheme.secondary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.secondary.withOpacity(0.2),
                                  colorScheme.tertiary.withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.secondary.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.secondary.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.functions_rounded,
                              color: colorScheme.secondary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BUILD POLYNOMIAL',
                                  style: TextStyle(
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Craft your function visually',
                                  style: TextStyle(
                                    color: colorScheme.secondary.withOpacity(0.5),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: colorScheme.secondary.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Scrollable content area (all content except header and footer)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Function Graph Preview
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutQuint,
                              height: 180,
                              margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? colorScheme.surface.withOpacity(0.8) 
                                    : colorScheme.secondary.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: dialogTerms.isEmpty 
                                      ? colorScheme.outline.withOpacity(0.2)
                                      : colorScheme.secondary.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: dialogTerms.isEmpty
                                      ? (isDark
                                          ? [
                                              colorScheme.surface.withOpacity(0.9),
                                              colorScheme.surface.withOpacity(0.8),
                                            ]
                                          : [
                                              colorScheme.secondary.withOpacity(0.04),
                                              colorScheme.secondary.withOpacity(0.02),
                                            ])
                                      : (isDark
                                          ? [
                                              colorScheme.secondary.withOpacity(0.1),
                                              colorScheme.secondary.withOpacity(0.08),
                                            ]
                                          : [
                                              colorScheme.secondary.withOpacity(0.08),
                                              colorScheme.secondary.withOpacity(0.05),
                                            ]),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: dialogTerms.isEmpty
                                        ? colorScheme.shadow.withOpacity(0.1)
                                        : colorScheme.secondary.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOutQuint,
                                switchOutCurve: Curves.easeInQuint,
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: dialogTerms.isEmpty
                                  ? Center(
                                      key: const ValueKey('empty-graph'),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                children: [
                                          Icon(
                                            Icons.show_chart_rounded,
                                            size: 48,
                                            color: colorScheme.secondary.withOpacity(0.2),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Add terms to see function graph',
                                            style: TextStyle(
                                              color: colorScheme.secondary.withOpacity(0.5),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ClipRRect(
                                      key: ValueKey('graph-${dialogTerms.length}'),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Stack(
                                        children: [
                                          // Graph background grid with subtle animation
                                          Positioned.fill(
                                            child: TweenAnimationBuilder<double>(
                                              duration: const Duration(milliseconds: 1500),
                                              curve: Curves.easeInOutSine,
                                              tween: Tween<double>(begin: 0, end: 1),
                                              builder: (context, value, child) {
                                                return CustomPaint(
                                                  painter: GridBackgroundPainter(
                                                    colorScheme: colorScheme,
                                                    isDark: isDark,
                                                    animationValue: value,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          // Function graph
                                          CustomPaint(
                                            size: const Size(double.infinity, 180),
                                            painter: FunctionGraphPainter(
                                              terms: dialogTerms,
                                              colorScheme: colorScheme,
                                              isDark: isDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              ),
                            ),
                            
                            // Current Function Display
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutQuad,
                              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: dialogTerms.isEmpty
                                      ? [
                                          colorScheme.primary.withOpacity(0.08),
                                          colorScheme.primary.withOpacity(0.04),
                                        ]
                                      : [
                                          colorScheme.secondary.withOpacity(0.15),
                                          colorScheme.primary.withOpacity(0.05),
                                        ],
                                  stops: const [0.3, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: dialogTerms.isEmpty
                                      ? colorScheme.outline.withOpacity(0.2)
                                      : colorScheme.secondary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: dialogTerms.isEmpty
                                        ? colorScheme.shadow.withOpacity(0.05)
                                        : colorScheme.secondary.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                    spreadRadius: -4,
                                  ),
                                ],
                                          ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'CURRENT FUNCTION',
                                              style: TextStyle(
                                          color: colorScheme.secondary.withOpacity(0.5),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1,
                                          fontSize: 12,
                                            ),
                                          ),
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                dialogTerms.clear();
                                              });
                                            },
                                            icon: Icon(
                                              Icons.refresh_rounded,
                                              color: colorScheme.error,
                                              size: 20,
                                            ),
                                            tooltip: 'Clear all terms',
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(32, 32),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                          if (dialogTerms.isNotEmpty)
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  dialogTerms.removeLast();
                                                });
                                              },
                                              icon: Icon(
                                                Icons.undo_rounded,
                                                color: colorScheme.primary,
                                                size: 20,
                                              ),
                                              tooltip: 'Remove last term',
                                              style: IconButton.styleFrom(
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: const Size(32, 32),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      switchInCurve: Curves.easeOutQuad,
                                      switchOutCurve: Curves.easeInQuad,
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.2),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Row(
                                        key: ValueKey('function-${dialogTerms.length}'),
                                        children: [
                                          Text(
                                            'g(x) = ',
                                              style: TextStyle(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 18,
                                            ),
                                          ),
                                          if (dialogTerms.isEmpty)
                                            Text(
                                              '0',
                                              style: TextStyle(
                                                color: colorScheme.secondary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                              ),
                                            )
                                          else
                                            Text(
                                              _buildFunctionStringFromTerms(dialogTerms),
                                              style: TextStyle(
                                                color: colorScheme.secondary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Quick Presets Section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Quick Presets
                                  Text(
                                    'QUICK PRESETS',
                                    style: TextStyle(
                                      color: colorScheme.secondary.withOpacity(0.5),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1,
                                      fontSize: 12,
                                              ),
                                            ),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildPresetButton(
                                          label: 'x² - 4',
                                          onTap: () {
                                            setState(() {
                                              dialogTerms = [
                                                {'coefficient': 1.0, 'power': 2, 'isVariable': true},
                                                {'coefficient': -4.0, 'power': 0, 'isVariable': false},
                                              ];
                                            });
                                          },
                                          colorScheme: colorScheme,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildPresetButton(
                                          label: 'x³ - 2x - 5',
                                          onTap: () {
                                            setState(() {
                                              dialogTerms = [
                                                {'coefficient': 1.0, 'power': 3, 'isVariable': true},
                                                {'coefficient': -2.0, 'power': 1, 'isVariable': true},
                                                {'coefficient': -5.0, 'power': 0, 'isVariable': false},
                                              ];
                                            });
                                          },
                                          colorScheme: colorScheme,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildPresetButton(
                                          label: 'x⁴ - 10',
                                          onTap: () {
                                            setState(() {
                                              dialogTerms = [
                                                {'coefficient': 1.0, 'power': 4, 'isVariable': true},
                                                {'coefficient': -10.0, 'power': 0, 'isVariable': false},
                                              ];
                                            });
                                          },
                                          colorScheme: colorScheme,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildPresetButton(
                                          label: '5x - 3',
                                          onTap: () {
                                            setState(() {
                                              dialogTerms = [
                                                {'coefficient': 5.0, 'power': 1, 'isVariable': true},
                                                {'coefficient': -3.0, 'power': 0, 'isVariable': false},
                                              ];
                                            });
                                          },
                                          colorScheme: colorScheme,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Variable Term Builder
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                              decoration: BoxDecoration(
                                color: colorScheme.secondary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ADD VARIABLE TERM',
                                    style: TextStyle(
                                      color: colorScheme.secondary.withOpacity(0.7),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      // Coefficient Input
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                              Text(
                                'COEFFICIENT',
                                style: TextStyle(
                                                color: colorScheme.secondary.withOpacity(0.5),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _coefficientController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: InputDecoration(
                                                hintText: 'Value',
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                                    color: colorScheme.secondary,
                                                    width: 2,
                                                  ),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                            ),
                                          ],
                                ),
                              ),
                                      const SizedBox(width: 16),
                                      // Power Input
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                              Text(
                                'POWER',
                                style: TextStyle(
                                  color: colorScheme.secondary.withOpacity(0.5),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _powerController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                                hintText: 'Power',
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                                    color: colorScheme.secondary,
                                                    width: 2,
                                                  ),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        if (_coefficientController.text.isNotEmpty && 
                                            _powerController.text.isNotEmpty) {
                                          setState(() {
                                            dialogTerms.add({
                                              'coefficient': double.parse(_coefficientController.text),
                                              'power': int.parse(_powerController.text),
                                              'isVariable': true,
                                            });
                                          });
                                          _coefficientController.clear();
                                          _powerController.clear();
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 20),
                                      label: const Text(
                                        'ADD VARIABLE TERM',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                                ],
                              ),
                            ),
                            
                            // Constant Term Builder
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              decoration: BoxDecoration(
                                color: colorScheme.secondary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                    'ADD CONSTANT TERM',
                                style: TextStyle(
                                      color: colorScheme.secondary.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                      fontSize: 14,
                                ),
                              ),
                                  const SizedBox(height: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                             
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _constantController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: InputDecoration(
                                  hintText: 'Enter constant value',
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                              color: colorScheme.secondary,
                                              width: 2,
                                    ),
                                  ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                        onPressed: () {
                                        if (_constantController.text.isNotEmpty) {
                                          setState(() {
                                            dialogTerms.add({
                                              'coefficient': double.parse(_constantController.text),
                                              'power': 0,
                                              'isVariable': false,
                                          });
                                          });
                                          _constantController.clear();
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 20),
                                      label: const Text(
                                        'ADD CONSTANT TERM',
                                      style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer with action buttons
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                  spreadRadius: -4,
                                ),
                              ],
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.tertiary,
                                ],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                              // Build function string from current terms
                              String functionText = _buildFunctionStringFromTerms(dialogTerms);
                              
                              // Update the main screen's state
                              this.setState(() {
                                // Store terms in main screen's state
                                _terms = List.from(dialogTerms);
                                // Update the main screen's function text
                                _functionController.text = functionText.isEmpty ? "Click to build function" : functionText;
                              });
                              
                              // Clear dialog values
                              _coefficientController.clear();
                              _powerController.clear();
                              _constantController.clear();
                              
                              // Close dialog
                              Navigator.pop(context);
                            },
                                borderRadius: BorderRadius.circular(20),
                                splashColor: Colors.white.withOpacity(0.2),
                                highlightColor: Colors.white.withOpacity(0.1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'APPLY FUNCTION',
                              style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: colorScheme.secondary.withOpacity(0.1),
        highlightColor: colorScheme.secondary.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.15),
                colorScheme.secondary.withOpacity(0.1),
              ],
              stops: const [0.3, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.functions_rounded,
                size: 16,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildFunctionStringFromTerms(List<Map<String, dynamic>> terms) {
    if (terms.isEmpty) return '';
    
    List<String> termStrings = [];
    
    for (var term in terms) {
      String termString = '';
      double coefficient = term['coefficient'];
      int power = term['power'];
      bool isVariable = term['isVariable'];
      
      // Format coefficient
      if (coefficient != 0) {
        if (coefficient == -1 && isVariable) {
          termString += '-';
        } else if (coefficient != 1 || !isVariable) {
          // Convert to integer if it's a whole number
          if (coefficient % 1 == 0) {
            termString += coefficient.toInt().toString();
          } else {
            termString += coefficient.toString();
          }
        }
      }
      
      // Add variable and power if it's a variable term
      if (isVariable) {
        termString += 'x';
        if (power != 1) {
          termString += _convertToSuperscript(power.toString());
        }
      }
      
      if (termString.isNotEmpty) {
        // Add plus sign if it's not the first term and coefficient is positive
        if (termStrings.isNotEmpty && !termString.startsWith('-')) {
          termStrings.add('+');
        }
        termStrings.add(termString);
      }
    }
    
    return termStrings.join(' ');
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('simple_fixed_point_history');
      
      if (historyJson != null) {
        final List<dynamic> decodedList = json.decode(historyJson);
        final loadedHistory = decodedList.map((item) {
          return {
            ...Map<String, dynamic>.from(item),
            'timestamp': DateTime.parse(item['timestamp']),
          };
        }).toList();
        _historyNotifier.value = loadedHistory;
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _saveHistoryToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyToSave = _historyNotifier.value.map((item) {
        return {
          ...item,
          'timestamp': (item['timestamp'] as DateTime).toIso8601String(),
        };
      }).toList();
      
      await prefs.setString('simple_fixed_point_history', json.encode(historyToSave));
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  void _saveToHistory() {
    if (_functionController.text.isNotEmpty && _x0Controller.text.isNotEmpty) {
      final historyItem = {
        'function': _functionController.text,
        'terms': List.from(_terms),
        'x0': _x0Controller.text,
        'error': _errorController.text,
        'iterations': _iterationsController.text,
        'useError': _useError,
        'timestamp': DateTime.now(),
      };
      
      // Check for exact duplicates (ignoring timestamp)
      bool isDuplicate = _historyNotifier.value.any((item) =>
        item['function'] == historyItem['function'] &&
        item['x0'] == historyItem['x0'] &&
        item['error'] == historyItem['error'] &&
        item['iterations'] == historyItem['iterations'] &&
        item['useError'] == historyItem['useError'] &&
        _areTermsEqual(item['terms'] as List<dynamic>, historyItem['terms'] as List<dynamic>)
      );

      if (!isDuplicate) {
        // Remove any older entries with the same function and x0
        final newHistory = _historyNotifier.value.where((item) =>
          !(item['function'] == historyItem['function'] && 
            item['x0'] == historyItem['x0'])
        ).toList();
        
        // Add the new item at the beginning
        newHistory.insert(0, historyItem);
        
        // Keep only the last 10 items
        if (newHistory.length > 10) {
          newHistory.removeLast();
        }
        
        _historyNotifier.value = newHistory;
        _saveHistoryToPrefs();
      }
    }
  }

  // Helper method to compare terms lists
  bool _areTermsEqual(List<dynamic> terms1, List<dynamic> terms2) {
    if (terms1.length != terms2.length) return false;
    
    for (int i = 0; i < terms1.length; i++) {
      final t1 = terms1[i];
      final t2 = terms2[i];
      if (t1['coefficient'] != t2['coefficient'] ||
          t1['power'] != t2['power'] ||
          t1['isVariable'] != t2['isVariable']) {
        return false;
      }
    }
    
    return true;
  }

  void _loadFromHistory(Map<String, dynamic> historyItem) {
    setState(() {
      _functionController.text = historyItem['function'];
      _terms = List.from(historyItem['terms']);
      _x0Controller.text = historyItem['x0'];
      _errorController.text = historyItem['error'];
      _iterationsController.text = historyItem['iterations'];
      _useError = historyItem['useError'];
    });
    
    // Trigger form validation
    Future.microtask(() {
      if (_formKey.currentState != null) {
        _formKey.currentState!.validate();
      }
    });
    
    Navigator.pop(context);
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          color: colorScheme.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FUNCTION HISTORY',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recent functions and their parameters',
                              style: TextStyle(
                                color: colorScheme.primary.withOpacity(0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                Flexible(
                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _historyNotifier,
                    builder: (context, history, child) {
                      if (history.isEmpty) {
                        return Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  // Animated circle with wave effect
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 1500),
                                    curve: Curves.elasticOut,
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Outer ring with gradient
                                            Container(
                                              width: 130,
                                              height: 130,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: SweepGradient(
                                                  colors: [
                                                    colorScheme.primary.withOpacity(0.1),
                                                    colorScheme.primary.withOpacity(0.3),
                                                    colorScheme.secondary.withOpacity(0.3),
                                                    colorScheme.secondary.withOpacity(0.1),
                                                    colorScheme.primary.withOpacity(0.1),
                                                  ],
                                                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                                                ),
                                              ),
                                            ),
                                            
                                            // Middle ring with pulsing animation
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.9, end: 1.0),
                                              duration: const Duration(milliseconds: 1500),
                                              curve: Curves.easeInOut,
                                              builder: (context, pulseValue, _) {
                                                return Container(
                                                  width: 110 * pulseValue,
                                                  height: 110 * pulseValue,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: colorScheme.surface,
                                                    border: Border.all(
                                  color: colorScheme.primary.withOpacity(0.2),
                                                      width: 2,
                                ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: colorScheme.primary.withOpacity(0.1),
                                                        blurRadius: 10,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            
                                            // Inner container with icon
                                            Container(
                                              width: 90,
                                              height: 90,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    colorScheme.surface,
                                                    colorScheme.surface,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: colorScheme.primary.withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                    spreadRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: TweenAnimationBuilder<double>(
                                                  tween: Tween(begin: 0.0, end: 1.0),
                                                  duration: const Duration(milliseconds: 600),
                                                  curve: Curves.easeOutBack,
                                                  builder: (context, iconValue, _) {
                                                    return Transform.scale(
                                                      scale: iconValue,
                                                      child: Icon(
                                                        Icons.history_rounded,
                                                        size: 45,
                                                        color: colorScheme.primary.withOpacity(0.7),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  
                                  // Animated title
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, titleValue, child) {
                                      return Opacity(
                                        opacity: titleValue,
                                        child: Transform.translate(
                                          offset: Offset(0, 10 * (1 - titleValue)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Your History Is Empty',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 22,
                                        letterSpacing: 0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  
                                const SizedBox(height: 16),
                                  
                                  // Description with staggered animation
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(milliseconds: 1000),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, descValue, child) {
                                        return Opacity(
                                          opacity: descValue,
                                          child: Transform.translate(
                                            offset: Offset(0, 20 * (1 - descValue)),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Calculations you perform will be saved here for easy access. Find roots efficiently with the Simple Fixed Point Method.',
                                        textAlign: TextAlign.center,
                                  style: TextStyle(
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                          fontSize: 15,
                                          height: 1.6,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: history.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final timestamp = item['timestamp'] as DateTime;
                          return Dismissible(
                            key: ValueKey(timestamp.toIso8601String()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: colorScheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.delete_rounded,
                                color: colorScheme.error,
                                size: 24,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: EdgeInsets.zero,
                                    child: Stack(
                                      children: [
                                        // Blurred background
                                        Positioned.fill(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                            child: Container(
                                              color: Colors.black.withOpacity(0.1),
                                            ),
                                          ),
                                        ),
                                        // Dialog content
                                        Center(
                                          child: Container(
                                            width: 400,
                                            margin: const EdgeInsets.symmetric(horizontal: 40),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                stops: const [0.0, 0.35, 0.7, 1.0],
                                                colors: [
                                                  const Color(0xFFB71C1C).withOpacity(0.8),  // Dark red
                                                  const Color(0xFF960000).withOpacity(0.85),  // Darker red
                                                  const Color(0xFF7F0000).withOpacity(0.9),  // Very dark red
                                                  const Color(0xFF550000).withOpacity(0.95),  // Extremely dark red
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(28),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFB71C1C).withOpacity(0.3),
                                                  blurRadius: 40,
                                                  offset: const Offset(0, 20),
                                                  spreadRadius: -12,
                                                ),
                                              ],
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.2),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(28),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter,
                                                      stops: const [0.0, 0.3, 0.6, 1.0],
                                                      colors: [
                                                        Colors.white.withOpacity(0.3),
                                                        Colors.white.withOpacity(0.15),
                                                        Colors.white.withOpacity(0.05),
                                                        Colors.white.withOpacity(0.0),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(32),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(20),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withOpacity(0.2),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: Colors.white.withOpacity(0.5),
                                                              width: 2,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.2),
                                                                blurRadius: 16,
                                                                offset: const Offset(0, 8),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons.delete_rounded,
                                                            color: Colors.white,
                                                            size: 36,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 24),
                                                        Text(
                                                          'Delete Function',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 28,
                                                            letterSpacing: 0.5,
                                                            shadows: [
                                                              Shadow(
                                                                color: Colors.black.withOpacity(0.3),
                                                                offset: const Offset(0, 2),
                                                                blurRadius: 4,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 24),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 24,
                                                            vertical: 16,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                              colors: [
                                                                Colors.black.withOpacity(0.4),
                                                                Colors.black.withOpacity(0.2),
                                                              ],
                                                            ),
                                                            borderRadius: BorderRadius.circular(20),
                                                            border: Border.all(
                                                              color: Colors.white.withOpacity(0.3),
                                                              width: 2,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.2),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 4),
                                                              ),
                                                            ],
                                                          ),
                                                          child: SingleChildScrollView(
                                                            scrollDirection: Axis.horizontal,
                                                            child: Text(
                                                              'g(x) = ${item['function']}',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 18,
                                                                height: 1.5,
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 24),
                                                        Text(
                                                          'Are you sure you want to delete this function?\nThis action cannot be undone.',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: Colors.white.withOpacity(0.9),
                                                            fontSize: 16,
                                                            height: 1.6,
                                                            letterSpacing: 0.3,
                                                            shadows: [
                                                              Shadow(
                                                                color: Colors.black.withOpacity(0.2),
                                                                offset: const Offset(0, 1),
                                                                blurRadius: 2,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 32),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: TextButton(
                                                                onPressed: () => Navigator.of(context).pop(false),
                                                                style: TextButton.styleFrom(
                                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                                  backgroundColor: Colors.white.withOpacity(0.2),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(16),
                                                                    side: BorderSide(
                                                                      color: Colors.white.withOpacity(0.3),
                                                                      width: 2,
                                                                    ),
                                                                  ),
                                                                ),
                                                                child: const Text(
                                                                  'CANCEL',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontWeight: FontWeight.w600,
                                                                    letterSpacing: 1.2,
                                                                    fontSize: 15,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 16),
                                                            Expanded(
                                                              child: ElevatedButton(
                                                                onPressed: () => Navigator.of(context).pop(true),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: Colors.white,
                                                                  foregroundColor: const Color(0xFFFF1744),
                                                                  elevation: 0,
                                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(16),
                                                                  ),
                                                                  shadowColor: Colors.black.withOpacity(0.3),
                                                                ),
                                                                child: const Text(
                                                                  'DELETE',
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.w600,
                                                                    letterSpacing: 1.2,
                                                                    fontSize: 15,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
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
                                  );
                                },
                              ) ?? false;
                            },
                            onDismissed: (direction) async {
                              final removedItem = history[index];
                              final newHistory = List<Map<String, dynamic>>.from(history)..removeAt(index);
                              
                              _historyNotifier.value = newHistory;
                              await _saveHistoryToPrefs();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('History item deleted'),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      onPressed: () {
                                        final updatedHistory = [removedItem, ...newHistory];
                                        _historyNotifier.value = updatedHistory;
                                        _saveHistoryToPrefs();
                                      },
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _loadFromHistory(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'g(x) = ${item['function']}',
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Initial guess: ${item['x0']}',
                                              style: TextStyle(
                                                color: colorScheme.primary.withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}',
                                              style: TextStyle(
                                                color: colorScheme.primary.withOpacity(0.3),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: colorScheme.primary.withOpacity(0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Container(
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
                    colorScheme.primary.withOpacity(0.03),
                    colorScheme.background,
                    colorScheme.secondary.withOpacity(0.04),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom App Bar with animated header
              AnimatedBuilder(
                animation: _headerAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - _headerAnimationController.value)),
                    child: Opacity(
                      opacity: _headerAnimationController.value,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            _buildBackButton(colorScheme),
                            const SizedBox(width: 20),
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
                                      'Simple Fixed Point METHOD',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        color: Colors.white,
                                      ).apply(fontSizeDelta: 2.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildHelpButton(colorScheme),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildStepCard(
                            step: 1,
                            title: 'Define Function',
                            subtitle: 'Enter your polynomial function',
                            icon: Icons.functions_rounded,
                            colorScheme: colorScheme,
                            isExpanded: true,
                            content: _buildFunctionInput(colorScheme),
                            actions: [
                              IconButton(
                                onPressed: _showHistoryDialog,
                                icon: Icon(
                                  Icons.history_rounded,
                                  color: colorScheme.primary.withOpacity(0.5),
                                ),
                                tooltip: 'Function History',
                              ),
                            ],
                          ),
                          _buildStepCard(
                            step: 2,
                            title: 'Initial Guess',
                            subtitle: 'Enter your initial approximation x₀',
                            icon: Icons.space_bar_rounded,
                            colorScheme: colorScheme,
                            isExpanded: _functionController.text.isNotEmpty,
                            content: _buildIntervalInputs(colorScheme),
                          ),
                          _buildStepCard(
                            step: 3,
                            title: 'Stopping Criteria',
                            subtitle: 'Choose when to stop iterations',
                            icon: Icons.stop_circle_outlined,
                            colorScheme: colorScheme,
                            isExpanded: _x0Controller.text.isNotEmpty,
                            content: _buildStoppingCriteria(colorScheme),
                          ),
                          const SizedBox(height: 24),
                          _buildNumberFormatSettings(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Action Bar
              _buildBottomActionBar(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(ColorScheme colorScheme) {
    return Hero(
      tag: 'back_button',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpButton(ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'How to use',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showTutorial,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.help_outline_rounded,
              size: 24.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required ColorScheme colorScheme,
    required bool isExpanded,
    required Widget content,
    List<Widget>? actions,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$step',
                        style: TextStyle(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        icon,
                        color: colorScheme.secondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.primary.withOpacity(0.5),
                          letterSpacing: 0.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions != null) ...actions,
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstChild: content,
              secondChild: const SizedBox(height: 0),
              crossFadeState: isExpanded 
                  ? CrossFadeState.showFirst 
                  : CrossFadeState.showSecond,
              sizeCurve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionInput(ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showFunctionDialog,
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontSize: 16,
                      ),
                      children: [
                        const TextSpan(text: 'g(x) = '),
                        TextSpan(
                          text: _functionController.text.isEmpty 
                              ? "Tap to build function" 
                              : _functionController.text,
                          style: TextStyle(
                            color: _functionController.text.isEmpty 
                                ? colorScheme.primary.withOpacity(0.5)
                                : colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_rounded,
                  color: colorScheme.primary.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalInputs(ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Column(
        children: [
          _buildInputField(
            controller: _x0Controller,
            hint: 'Initial guess',
            prefix: 'x₀ =',
            colorScheme: colorScheme,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-+]?([0-9]*[.])?[0-9]+')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoppingCriteria(ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRadioOption(
                  value: true,
                  groupValue: _useError,
                  label: 'Error %',
                  colorScheme: colorScheme,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildRadioOption(
                  value: false,
                  groupValue: _useError,
                  label: 'Iterations',
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInputField(
            controller: _useError ? _errorController : _iterationsController,
            hint: _useError ? 'Enter error percentage' : 'Enter number of iterations',
            prefix: _useError ? 'ε =' : 'n =',
            colorScheme: colorScheme,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                _useError 
                    ? RegExp(r'[-+]?([0-9]*[.])?[0-9]+')
                    : RegExp(r'[0-9]+')
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32.r),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 24.r,
            offset: Offset(0, -8.h),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          _buildActionButton(
            onTap: _clearFields,
            icon: Icons.refresh_rounded,
            label: 'RESET',
            colorScheme: colorScheme,
            isOutlined: true,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildActionButton(
              onTap: _calculateAndNavigate,
              icon: Icons.play_arrow_rounded,
              label: 'CALCULATE',
              colorScheme: colorScheme,
              isOutlined: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required bool isOutlined,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          decoration: BoxDecoration(
            gradient: isOutlined
                ? null
                : LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ),
            color: isOutlined ? colorScheme.surface : null,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isOutlined
                  ? colorScheme.outline.withOpacity(0.2)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              if (!isOutlined)
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20.r,
                  offset: Offset(0, 8.h),
                  spreadRadius: -4.r,
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isOutlined
                    ? colorScheme.primary
                    : Colors.white.withOpacity(0.9),
                size: 20.w,
              ),
              if (label.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    color: isOutlined
                        ? colorScheme.primary
                        : Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    fontSize: 14.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTutorial() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.help_outline_rounded,
                          color: colorScheme.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOW TO USE',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Follow these steps to find roots',
                              style: TextStyle(
                                color: colorScheme.primary.withOpacity(0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTutorialStep(
                          step: 1,
                          title: 'Define Your Function',
                          description: 'Tap the function input to build your polynomial equation using the function builder.',
                          icon: Icons.functions_rounded,
                          colorScheme: colorScheme,
                        ),
                        _buildTutorialStep(
                          step: 2,
                          title: 'Set the Interval',
                          description: 'Enter the lower (Xl) and upper (Xu) bounds of the interval where the root might exist.',
                          icon: Icons.space_bar_rounded,
                          colorScheme: colorScheme,
                        ),
                        _buildTutorialStep(
                          step: 3,
                          title: 'Choose Stopping Criteria',
                          description: 'Select either error percentage or number of iterations as your stopping condition.',
                          icon: Icons.stop_circle_outlined,
                          colorScheme: colorScheme,
                        ),
                        _buildTutorialStep(
                          step: 4,
                          title: 'Calculate',
                          description: 'Hit the calculate button to find the root using the Simple Fixed Point method.',
                          icon: Icons.play_arrow_rounded,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildActionButton(
                    onTap: () => Navigator.pop(context),
                    icon: Icons.check_rounded,
                    label: 'GOT IT',
                    colorScheme: colorScheme,
                    isOutlined: false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialStep({
    required int step,
    required String title,
    required String description,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 20.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: colorScheme.primary.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberFormatSettings(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.pin_rounded,
                  color: colorScheme.secondary,
                  size: 20,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DECIMAL PRECISION',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Adjust the number of decimal places',
                      style: TextStyle(
                        color: colorScheme.primary.withOpacity(0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Preview section with animated number
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.functions_rounded,
                  color: colorScheme.secondary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Text(
                        _formatExampleNumber(),
                        style: GoogleFonts.robotoMono(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.secondary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Slider section
          Row(
            children: [
              Text(
                '0',
                style: TextStyle(
                  color: colorScheme.primary.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: colorScheme.secondary,
                    inactiveTrackColor: colorScheme.secondary.withOpacity(0.1),
                    thumbColor: colorScheme.secondary,
                    overlayColor: colorScheme.secondary.withOpacity(0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 4,
                      pressedElevation: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24,
                    ),
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 3,
                    ),
                    activeTickMarkColor: colorScheme.secondary,
                    inactiveTickMarkColor: colorScheme.secondary.withOpacity(0.2),
                    valueIndicatorColor: colorScheme.secondary,
                    valueIndicatorTextStyle: TextStyle(
                      color: colorScheme.onSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    showValueIndicator: ShowValueIndicator.always,
                  ),
                  child: Slider(
                    value: _decimalPlaces.toDouble(),
                    min: 0,
                    max: 6,
                    divisions: 6,
                    label: _decimalPlaces.toString(),
                    onChanged: (value) {
                      setState(() => _decimalPlaces = value.round());
                    },
                  ),
                ),
              ),
              Text(
                '6',
                style: TextStyle(
                  color: colorScheme.primary.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Description text
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                _decimalPlaces == 1
                    ? '1 decimal place'
                    : '$_decimalPlaces decimal places',
                key: ValueKey<int>(_decimalPlaces),
                style: TextStyle(
                  color: colorScheme.primary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExampleNumber() {
    const number = 3.141592653589793;
    String formatted = number.toStringAsFixed(_decimalPlaces);
    // Remove trailing zeros
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0*$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required ColorScheme colorScheme,
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    Widget? prefixWidget;
    if (prefix != null) {
      prefixWidget = Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Text(
          '$prefix ',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (value) {
        setState(() {
          // Update _isValidInterval when x₀ input changes
          if (controller == _x0Controller) {
            debugPrint('Input changed. Setting _isValidInterval to: ${value.isNotEmpty}');
            debugPrint('Current x₀ value: $value');
          }
        });
        if (onChanged != null) {
          onChanged(value);
        }
      },
      style: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefix: prefixWidget,
        hintStyle: TextStyle(
          color: colorScheme.primary.withOpacity(0.5),
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: colorScheme.surface,
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: colorScheme.secondary,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.all(20.w),
      ),
      validator: (value) {
        // Skip validation for error field when using iterations
        if (controller == _errorController && !_useError) {
          return null;
        }
        // Skip validation for iterations field when using error
        if (controller == _iterationsController && _useError) {
          return null;
        }
        
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        
        return null;
      },
    );
  }

  Widget _buildRadioOption({
    required bool value,
    required bool groupValue,
    required String label,
    required ColorScheme colorScheme,
  }) {
    final isSelected = value == groupValue;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _useError = value;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.secondary
                  : colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected 
                        ? colorScheme.secondary 
                        : colorScheme.outline.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 12 : 0,
                    height: isSelected ? 12 : 0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colorScheme.secondary : Colors.transparent,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected 
                        ? colorScheme.primary 
                        : colorScheme.primary.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 