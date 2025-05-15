import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/gauss_jordan_method.dart';
import './gauss_jordan_solution_screen.dart';
import 'package:flutter/rendering.dart';

// Custom painter for grid pattern background
class GridPainter extends CustomPainter {
  final Color color;
  final double gridSize;

  GridPainter({required this.color, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom text editing controller to ensure backspace works properly
class MatrixInputController extends TextEditingController {
  MatrixInputController({String? text}) : super(text: text);

  @override
  set value(TextEditingValue newValue) {
    // Ensure we never block any text operations including deletion
    super.value = newValue;
  }
}

class GaussJordanMethodScreen extends StatefulWidget {
  const GaussJordanMethodScreen({Key? key}) : super(key: key);

  @override
  State<GaussJordanMethodScreen> createState() => _GaussJordanMethodScreenState();
}

class _GaussJordanMethodScreenState extends State<GaussJordanMethodScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeInAnimation;
  late final Animation<double> _slideAnimation;

  // Fixed matrix dimensions
  final int _rows = 3;
  final int _cols = 3;
  
  // Matrix input controllers
  final List<List<TextEditingController>> _coefficientControllers = [];
  final List<TextEditingController> _constantControllers = [];
  
  // Options
  bool _usePartialPivoting = false;
  bool _formHasError = false;
  String _errorMessage = '';

  // UI States
  bool _isLoading = false;
  final FocusNode _firstFieldFocus = FocusNode();
  bool _isDisposed = false;

  // SharedPreferences instance
  SharedPreferences? _prefs;
  
  // List to store matrix history
  final List<Map<String, dynamic>> _matrixHistory = [];
  
  // Storage key for matrix history
  static const String _matrixHistoryKey = 'gauss_jordan_matrix_history';

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    // Initialize controllers with empty fields
    _initializeControllers();
    
    // Load saved history
    _loadMatrixHistory();
    
    // Start animation
    _animationController.forward();
  }

  // Generate a valid example system when needed
  void _generateValidExampleSystem() {
    // Create an identity matrix with reasonable constants
    for (int i = 0; i < _rows; i++) {
      for (int j = 0; j < _cols; j++) {
        _coefficientControllers[i][j].text = (i == j) ? '1' : '0';
      }
      // Use simple sequential constants: 2, 4, 6
      _constantControllers[i].text = '${(i + 1) * 2}';
    }
  }

  void _initializeControllers() {
    // Clear any existing controllers
    _coefficientControllers.clear();
    _constantControllers.clear();
    
    // Initialize coefficient controllers with empty fields
    for (int i = 0; i < _rows; i++) {
      final rowControllers = <TextEditingController>[];
      for (int j = 0; j < _cols; j++) {
        rowControllers.add(MatrixInputController(text: ''));
      }
      _coefficientControllers.add(rowControllers);
    }
    
    // Initialize constant controllers with empty fields
    for (int i = 0; i < _rows; i++) {
      _constantControllers.add(MatrixInputController(text: ''));
    }
    
    // Set focus to the first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _coefficientControllers.isNotEmpty && 
          _coefficientControllers[0].isNotEmpty) {
        _coefficientControllers[0][0].selection = TextSelection.fromPosition(
          TextPosition(offset: _coefficientControllers[0][0].text.length)
        );
        FocusScope.of(context).requestFocus(_firstFieldFocus);
      }
    });
  }

  void _loadMatrixHistory() {
    // Call the async implementation
    _loadMatrixHistoryAsync();
  }

  Future<void> _loadMatrixHistoryAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      
      final historyJson = prefs.getString(_matrixHistoryKey);
      if (historyJson != null && mounted) {
        setState(() {
          final historyList = jsonDecode(historyJson) as List<dynamic>;
          _matrixHistory.clear();
          for (final item in historyList) {
            _matrixHistory.add(Map<String, dynamic>.from(item as Map));
          }
        });
      }
    } catch (e) {
      // Handle any errors gracefully
      print('Error loading matrix history: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Clean up controllers and focus nodes
    for (final row in _coefficientControllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    
    for (final controller in _constantControllers) {
      controller.dispose();
    }
    
    _firstFieldFocus.dispose();
    _animationController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [colorScheme.primary, colorScheme.tertiary],
          ).createShader(bounds),
          child: const Text(
            'GAUSS-JORDAN METHOD',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Random values button
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: colorScheme.primary,
            ),
            onPressed: _generateRandomValues,
            tooltip: 'Fill with random values',
          ),
          // Info button
          IconButton(
            icon: Icon(
              Icons.lightbulb_outline,
              color: colorScheme.primary,
            ),
            onPressed: _showInfoDialog,
            tooltip: 'Method information',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Background pattern (subtle grid for a mathematical feel)
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: CustomPaint(
                  painter: GridPainter(
                    color: isDark ? Colors.white : Colors.black,
                    gridSize: 20.0,
                  ),
                ),
              ),
            ),
            
            // Main content
            FadeTransition(
              opacity: _fadeInAnimation,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: child,
                  );
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(colorScheme),
                      SizedBox(height: 24.h),
                      _buildMatrixInput(colorScheme),
                      SizedBox(height: 24.h),
                      _buildOptionsSection(colorScheme),
                      SizedBox(height: 32.h),
                      _buildActionButtons(colorScheme),
                      SizedBox(height: 16.h),
                      if (_formHasError) _buildErrorMessage(colorScheme),
                      SizedBox(height: 70.h), // Extra space for bottom padding
                    ],
                  ),
                ),
              ),
            ),
            
            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Solving system...',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 10.r,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.calculate_outlined,
                  color: colorScheme.primary,
                  size: 24.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System of Linear Equations',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '3×3 Matrix • Gauss-Jordan Method',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'Enter the coefficients and constants to solve the system using Gauss-Jordan elimination method.',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixInput(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.grid_on_rounded,
                    color: colorScheme.primary,
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Matrix Input',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                Spacer(),
                // History button
                IconButton(
                  onPressed: _showMatrixHistory,
                  tooltip: 'History',
                  icon: Icon(
                    Icons.history,
                    color: colorScheme.secondary,
                    size: 20.w,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.secondaryContainer.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            // Matrix input section
            Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                // Ensure text editing works properly
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: colorScheme.primary,
                  selectionColor: colorScheme.primary.withOpacity(0.2),
                  selectionHandleColor: colorScheme.primary,
                ),
              ),
              child: Column(
                children: [
                  // Column headers
                  Padding(
                    padding: EdgeInsets.only(left: 32.w, bottom: 8.h, right: 32.w),
                    child: Row(
                      children: [
                        ...List.generate(_cols, (j) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                'x${j + 1}',
                                style: TextStyle(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          );
                        }),
                        SizedBox(width: 16.w),
                        Container(
                          width: 60.w,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 18.w),
                          child: Text(
                            'b',
                            style: TextStyle(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Matrix rows
                  ...List.generate(_rows, (i) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          // Row label
                          Container(
                            width: 24.w,
                            alignment: Alignment.center,
                            child: Text(
                              'R${i + 1}',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          
                          // Coefficient inputs
                          ...List.generate(_cols, (j) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: _buildMatrixField(
                                  controller: _coefficientControllers[i][j],
                                  colorScheme: colorScheme,
                                  isFirstField: i == 0 && j == 0,
                                ),
                              ),
                            );
                          }),
                          
                          SizedBox(width: 8.w),
                          
                          // Equals sign
                          Container(
                            width: 24.w,
                            alignment: Alignment.center,
                            child: Text(
                              '=',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 8.w),
                          
                          // Constant input
                          Container(
                            width: 60.w,
                            child: _buildMatrixField(
                              controller: _constantControllers[i],
                              colorScheme: colorScheme,
                              isConstant: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            SizedBox(height: 16.h),
            // Hint text
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.secondary,
                    size: 18.w,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Enter the coefficients of your 3×3 system. Use the "=" column for constants.',
                      style: TextStyle(
                        color: colorScheme.secondary,
                        fontSize: 12.sp,
                        fontStyle: FontStyle.italic,
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
  }
  
  Widget _buildMatrixField({
    required TextEditingController controller,
    required ColorScheme colorScheme,
    bool isConstant = false,
    bool isFirstField = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: isFirstField ? _firstFieldFocus : null,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 15.sp,
        color: isConstant 
            ? colorScheme.tertiary 
            : colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        fillColor: isConstant 
            ? colorScheme.tertiary.withOpacity(0.05)
            : null,
        hintText: '0',
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.3),
          fontWeight: FontWeight.w300,
        ),
      ),
      // Use custom input formatters to ensure proper input handling
      inputFormatters: [
        // Allow only valid numeric input including decimal point, comma and negative sign
        FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*[.,]?[0-9]*$')),
      ],
      // Explicitly handle text changes
      onChanged: (value) {
        if (_formHasError) {
          setState(() {
            _formHasError = false;
            _errorMessage = '';
          });
        }
        
        // Validate as user types
        if (value.isNotEmpty) {
          // Check if this is a valid number by trying to parse it
          final normalizedValue = value.replaceAll(',', '.');
          if (double.tryParse(normalizedValue) == null) {
            setState(() {
              _formHasError = true;
              _errorMessage = 'Please enter valid numbers only';
            });
          }
        }
      },
    );
  }

  Widget _buildOptionsSection(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: colorScheme.primary,
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Solution Settings',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24.h),
            
            // Method Options
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 8.w, bottom: 12.h),
                  child: Text(
                    'Algorithm Options',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
                
                // Partial Pivoting Option
                _buildOptionSwitch(
                  title: 'Partial Pivoting',
                  description: 'Improves numerical stability',
                  isSelected: _usePartialPivoting,
                  onChanged: (value) {
                    setState(() {
                      _usePartialPivoting = value;
                    });
                  },
                  icon: Icons.swap_vert_rounded,
                  colorScheme: colorScheme,
                  backgroundColor: colorScheme.tertiaryContainer.withOpacity(isDark ? 0.2 : 0.3),
                  activeColor: colorScheme.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSwitch({
    required String title,
    required String description,
    required bool isSelected,
    required Function(bool) onChanged,
    required IconData icon,
    required ColorScheme colorScheme,
    required Color backgroundColor,
    required Color activeColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: isSelected ? [
          BoxShadow(
            color: activeColor.withOpacity(0.2),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ] : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: isSelected 
                  ? activeColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              color: isSelected ? activeColor : colorScheme.onSurface.withOpacity(0.6),
              size: 20.w,
            ),
          ),
          
          SizedBox(width: 16.w),
          
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected 
                        ? activeColor
                        : colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          
          // Switch
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isSelected,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: activeColor,
              inactiveThumbColor: colorScheme.outline,
              inactiveTrackColor: colorScheme.surfaceVariant.withOpacity(0.4),
              thumbIcon: MaterialStateProperty.resolveWith<Icon?>(
                (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return Icon(
                      Icons.check,
                      color: activeColor,
                      size: 12.w,
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 48.h,
          width: 220.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.tertiary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.3),
                blurRadius: 10.r,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _solve,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18.w,
                  color: Colors.white,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Solve System',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Container(
          height: 48.h,
          width: 100.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: 6.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: OutlinedButton(
            onPressed: _resetForm,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                color: isDark 
                  ? colorScheme.primary.withOpacity(0.6)
                  : colorScheme.primary.withOpacity(0.4),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              backgroundColor: isDark
                  ? colorScheme.surface.withOpacity(0.1)
                  : Colors.white.withOpacity(0.8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ).createShader(bounds),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18.w,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 6.w),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: 24.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<List<double>> _getCoefficientsMatrix() {
    final List<List<double>> coefficients = [];
    
    for (int i = 0; i < _rows; i++) {
      final List<double> row = [];
      for (int j = 0; j < _cols; j++) {
        final text = _coefficientControllers[i][j].text.trim();
        if (text.isEmpty) {
          row.add(0);
        } else {
          try {
            // Be more permissive with input formats
            // Handle both decimal points and commas
            final normalized = text.replaceAll(',', '.');
            row.add(double.parse(normalized));
          } catch (e) {
            // Default to 0 if parsing fails (this should be caught earlier in validation)
            row.add(0);
            print('Warning: Could not parse coefficient at ($i,$j): $text');
          }
        }
      }
      coefficients.add(row);
    }
    
    return coefficients;
  }

  List<double> _getConstantsVector() {
    final List<double> constants = [];
    
    for (int i = 0; i < _rows; i++) {
      final text = _constantControllers[i].text.trim();
      if (text.isEmpty) {
        constants.add(0);
      } else {
        try {
          // Be more permissive with input formats
          // Handle both decimal points and commas
          final normalized = text.replaceAll(',', '.');
          constants.add(double.parse(normalized));
        } catch (e) {
          // Default to 0 if parsing fails (this should be caught earlier in validation)
          constants.add(0);
          print('Warning: Could not parse constant at row $i: $text');
        }
      }
    }
    
    return constants;
  }
  
  Future<void> _saveMatrixHistory() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      
      // Convert timestamp to save format
      final historyToSave = _matrixHistory.map((item) {
        final saveItem = Map<String, dynamic>.from(item);
        if (item['timestamp'] is DateTime) {
          saveItem['timestamp'] = (item['timestamp'] as DateTime).millisecondsSinceEpoch;
        }
        return saveItem;
      }).toList();
      
      await prefs.setString(_matrixHistoryKey, jsonEncode(historyToSave));
    } catch (e) {
      // Handle any errors gracefully
      print('Error saving matrix history: $e');
    }
  }

  void _solve() {
    // Don't proceed if already disposed
    if (_isDisposed) return;
    
    // Dismiss keyboard to avoid focus issues
    FocusScope.of(context).unfocus();
    
    // Clear previous errors
    setState(() {
      _formHasError = false;
      _errorMessage = '';
      _isLoading = true;
    });
    
    // Check if any required field is empty
    if (_hasEmptyFields()) {
      setState(() {
        _formHasError = true;
        _isLoading = false;
      });
      return;
    }
    
    // Save current matrix to history if it has any values
    if (_hasAnyValue()) {
      _saveCurrentMatrixToHistory();
    }
    
    // Use Future.delayed to ensure UI updates before computation
    Future.delayed(Duration.zero, () async {
      try {
        // Get matrix values
        final coefficients = _getCoefficientsMatrix();
        final constants = _getConstantsVector();
        
        // Validate input values
        bool hasValidInput = true;
        String errorMsg = '';
        
        // Check if any of the input values couldn't be parsed properly
        for (int i = 0; i < _rows; i++) {
          for (int j = 0; j < _cols; j++) {
            final text = _coefficientControllers[i][j].text.trim();
            if (text.isNotEmpty && double.tryParse(text) == null) {
              hasValidInput = false;
              errorMsg = 'Invalid number format in row ${i+1}, column ${j+1}';
              break;
            }
          }
          if (!hasValidInput) break;
          
          final text = _constantControllers[i].text.trim();
          if (text.isNotEmpty && double.tryParse(text) == null) {
            hasValidInput = false;
            errorMsg = 'Invalid number format in row ${i+1}, constant';
            break;
          }
        }
        
        if (!hasValidInput) {
          setState(() {
            _formHasError = true;
            _errorMessage = errorMsg;
            _isLoading = false;
          });
          return;
        }
        
        // Solve the system
        final result = GaussJordanMethod.solve(
          coefficientMatrix: coefficients,
          constantVector: constants,
          usePartialPivoting: _usePartialPivoting,
        );
        
        // Debug the result
        print('Result isSolved: ${result.isSolved}');
        print('Result solution: ${result.solution}');
        if (!result.isSolved) {
          print('Error message: ${result.errorMessage}');
        }
        
        if (!mounted || _isDisposed) return;
        
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to solution screen with safety check for mounting state
        if (mounted && !_isDisposed) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => GaussJordanSolutionScreen(
                result: result,
                usePartialPivoting: _usePartialPivoting,
                decimalPlaces: 4,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          ).then((_) {
            // When we return from the solution screen, ensure we're still mounted
            if (mounted) {
              // Reattach focus listeners if needed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    // Just refresh the UI
                  });
                }
              });
            }
          });
        }
      } catch (e) {
        // If any error occurs during solving
        if (mounted) {
          setState(() {
            _isLoading = false;
            _formHasError = true;
            _errorMessage = 'Error solving system: ${e.toString()}';
          });
        }
        print('Error solving system: $e');
      }
    });
  }

  bool _hasEmptyFields() {
    // Don't treat empty fields as missing values - they are interpreted as zeros
    // Instead check if the matrix is valid in other ways
    
    // For a valid linear system, we need at least as many equations as variables
    if (_rows != _cols) {
      setState(() {
        _errorMessage = 'Matrix must be square (equal rows and columns)';
      });
      return true;
    }

    // Get actual coefficient values (empty fields will be 0)
    final coefficients = _getCoefficientsMatrix();
    
    // At least one value must be non-zero for a valid system
    bool atLeastOneNonZero = false;
    for (int i = 0; i < _rows; i++) {
      for (int j = 0; j < _cols; j++) {
        if (coefficients[i][j].abs() > 1e-10) {
          atLeastOneNonZero = true;
          break;
        }
      }
      if (atLeastOneNonZero) break;
    }
    
    if (!atLeastOneNonZero) {
      setState(() {
        _errorMessage = 'Coefficient matrix cannot be all zeros. Please enter at least one non-zero coefficient.';
      });
      return true;
    }
    
    // Check if the matrix has any all-zero rows, which would make it singular
    for (int i = 0; i < _rows; i++) {
      bool allZeros = true;
      for (int j = 0; j < _cols; j++) {
        if (coefficients[i][j].abs() > 1e-10) {
          allZeros = false;
          break;
        }
      }
      
      if (allZeros) {
        setState(() {
          _errorMessage = 'Row ${i+1} contains all zeros. This would make the matrix singular.';
        });
        return true;
      }
    }
    
    // Check if any columns are all zeros (except the last column which would be constants)
    for (int j = 0; j < _cols; j++) {
      bool allZeros = true;
      for (int i = 0; i < _rows; i++) {
        if (coefficients[i][j].abs() > 1e-10) {
          allZeros = false;
          break;
        }
      }
      
      if (allZeros) {
        setState(() {
          _errorMessage = 'Column ${j+1} contains all zeros. This would make the matrix singular.';
        });
        return true;
      }
    }
    
    // Check for potential linear dependence (simplistic check)
    if (_rows >= 2) {
      for (int i = 0; i < _rows; i++) {
        for (int k = i + 1; k < _rows; k++) {
          // Check if row k is a multiple of row i
          double ratio = 0.0;
          bool foundNonZero = false;
          bool isMultiple = true;
          
          // Find first non-zero element to calculate ratio
          for (int j = 0; j < _cols; j++) {
            if (coefficients[i][j].abs() > 1e-10) {
              foundNonZero = true;
              ratio = coefficients[k][j] / coefficients[i][j];
              break;
            }
          }
          
          if (foundNonZero) {
            // Check if all other elements have the same ratio
            for (int j = 0; j < _cols; j++) {
              if (coefficients[i][j].abs() > 1e-10) {
                double currentRatio = coefficients[k][j] / coefficients[i][j];
                if ((currentRatio - ratio).abs() > 1e-8) {
                  isMultiple = false;
                  break;
                }
              } else if (coefficients[k][j].abs() > 1e-10) {
                // If this element is 0 in row i but not in row k, they're not multiples
                isMultiple = false;
                break;
              }
            }
            
            if (isMultiple) {
              setState(() {
                _errorMessage = 'Rows ${i+1} and ${k+1} appear to be linearly dependent. This would make the matrix singular.';
              });
              return true;
            }
          }
        }
      }
    }
    
    return false; // All checks passed
  }

  void _resetForm() {
    setState(() {
      _formHasError = false;
      _errorMessage = '';
      
      // Clear all fields
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _cols; j++) {
          _coefficientControllers[i][j].text = '';
        }
        _constantControllers[i].text = '';
      }
    });
    
    // Set focus to first field
    FocusScope.of(context).requestFocus(_firstFieldFocus);
  }
  
  void _generateRandomValues() {
    final random = math.Random();
    
    // Generate a valid, solvable system instead of completely random values
    setState(() {
      if (_usePartialPivoting) {
        // Generate a matrix that will demonstrate partial pivoting
        // This matrix will have smaller values on the diagonal and larger values below
        for (int i = 0; i < _rows; i++) {
          for (int j = 0; j < _cols; j++) {
            int value;
            if (i == j) {
              // Diagonal elements are small but non-zero
              value = random.nextInt(3) + 1; // 1, 2, or 3
            } else if (i > j) {
              // Below diagonal elements are larger (to trigger pivoting)
              value = random.nextInt(5) + 4; // 4, 5, 6, 7, or 8
            } else {
              // Above diagonal elements are varied
              value = random.nextInt(5) - 2; // -2, -1, 0, 1, or 2
            }
            _coefficientControllers[i][j].text = value.toString();
          }
        }
        
        // Now create a random solution vector with values between -5 and 5
        List<int> solution = List.generate(_rows, (i) => random.nextInt(11) - 5);
        
        // Calculate the right-hand side (constants) based on the coefficient matrix and solution
        for (int i = 0; i < _rows; i++) {
          int constant = 0;
          for (int j = 0; j < _cols; j++) {
            String coefText = _coefficientControllers[i][j].text;
            int coef = int.tryParse(coefText) ?? 0;
            constant += coef * solution[j];
          }
          
          // Set the constant value
          _constantControllers[i].text = constant.toString();
        }
      } else {
        // Generate a non-singular coefficient matrix with a known solution
        
        // First, create a simple diagonal-dominant matrix (always non-singular)
        for (int i = 0; i < _rows; i++) {
          for (int j = 0; j < _cols; j++) {
            int value;
            if (i == j) {
              // Diagonal elements are sum of other elements plus a random value
              value = _rows * 2 + random.nextInt(3) + 1; // Ensures diagonal dominance
            } else {
              // Off-diagonal elements are small but more varied
              value = random.nextInt(5) - 2; // -2, -1, 0, 1, or 2
            }
            _coefficientControllers[i][j].text = value.toString();
          }
        }
        
        // Now create a random solution vector with values between -5 and 5
        List<int> solution = List.generate(_rows, (i) => random.nextInt(11) - 5);
        
        // Calculate the right-hand side (constants) based on the coefficient matrix and solution
        for (int i = 0; i < _rows; i++) {
          int constant = 0;
          for (int j = 0; j < _cols; j++) {
            String coefText = _coefficientControllers[i][j].text;
            int coef = int.tryParse(coefText) ?? 0;
            constant += coef * solution[j];
          }
          
          // Set the constant value
          _constantControllers[i].text = constant.toString();
        }
      }
      
      // Reset error state
      _formHasError = false;
      _errorMessage = '';
    });
  }

  // Format a number for display
  String _formatNumber(double number) {
    // Check if the number is an integer (no decimal part)
    if (number == number.toInt()) {
      return number.toInt().toString();
    }
    return number.toString();
  }
  
  // Check if any field has a value
  bool _hasAnyValue() {
    for (int i = 0; i < _rows; i++) {
      for (int j = 0; j < _cols; j++) {
        if (_coefficientControllers[i][j].text.isNotEmpty) {
          return true;
        }
      }
      if (_constantControllers[i].text.isNotEmpty) {
        return true;
      }
    }
    return false;
  }
  
  // Load a matrix from history
  void _loadMatrixFromHistory(Map<String, dynamic> historyItem) {
    // Close the dialog
    Navigator.pop(context);
    
    // Cast data to ensure proper types
    final List<dynamic> coefficientsRaw = historyItem['coefficients'] as List<dynamic>;
    final List<dynamic> constantsRaw = historyItem['constants'] as List<dynamic>;
    
    // Fill controllers with values from history
    for (int i = 0; i < _rows; i++) {
      for (int j = 0; j < _cols; j++) {
        // Get the coefficient value, ensuring proper type conversion
        final dynamic coeffValue = coefficientsRaw[i][j];
        final String stringValue = coeffValue is double 
            ? coeffValue.toString() 
            : (coeffValue.toString());
        
        _coefficientControllers[i][j].text = stringValue.endsWith('.0') 
            ? stringValue.substring(0, stringValue.length - 2) 
            : stringValue;
      }
      
      // Get the constant value, ensuring proper type conversion
      final dynamic constValue = constantsRaw[i];
      final String stringValue = constValue is double 
          ? constValue.toString() 
          : (constValue.toString());
      
      _constantControllers[i].text = stringValue.endsWith('.0') 
          ? stringValue.substring(0, stringValue.length - 2) 
          : stringValue;
    }
  }
  
  void _saveCurrentMatrixToHistory() {
    // Extract current matrix values
    final Map<String, dynamic> historyItem = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'coefficients': List.generate(
        _rows,
        (i) => List.generate(
          _cols,
          (j) => _coefficientControllers[i][j].text.isEmpty
              ? 0.0
              : double.tryParse(_coefficientControllers[i][j].text) ?? 0.0,
        ),
      ),
      'constants': List.generate(
        _rows,
        (i) => _constantControllers[i].text.isEmpty
            ? 0.0
            : double.tryParse(_constantControllers[i].text) ?? 0.0,
      ),
    };
    
    // Check if this matrix is already in history
    bool isDuplicate = false;
    for (final item in _matrixHistory) {
      if (_compareMatrices(item['coefficients'], historyItem['coefficients']) &&
          _compareVectors(item['constants'], historyItem['constants'])) {
        isDuplicate = true;
        break;
      }
    }
    
    // Add to history if not a duplicate
    if (!isDuplicate) {
      setState(() {
        // Limit history to 10 items
        if (_matrixHistory.length >= 10) {
          _matrixHistory.removeAt(0);
        }
        _matrixHistory.add(historyItem);
      });
      
      // Save to persistent storage
      _saveMatrixHistory();
    }
  }
  
  // Compare two matrices
  bool _compareMatrices(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_compareVectors(a[i], b[i])) return false;
    }
    return true;
  }
  
  // Compare two vectors
  bool _compareVectors(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _showMatrixHistory() {
    // Add current matrix to history before showing
    if (_hasAnyValue()) {
      _saveCurrentMatrixToHistory();
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history,
                        color: colorScheme.primary,
                        size: 20.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Matrix History',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // History list
              Expanded(
                child: _matrixHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 64.w,
                              color: colorScheme.onSurface.withOpacity(0.2),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No history yet',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 16.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Previously entered matrices will appear here',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.3),
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // List of history items
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              itemCount: _matrixHistory.length,
                              itemBuilder: (context, index) {
                                // Reverse the index to show newest first
                                final reversedIndex = _matrixHistory.length - 1 - index;
                                final historyItem = _matrixHistory[reversedIndex];
                                
                                // Format timestamp
                                final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
                                  historyItem['timestamp'] is int
                                      ? historyItem['timestamp']
                                      : 0,
                                );
                                final String formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
                                
                                return Dismissible(
                                  key: Key('history_${historyItem['timestamp']}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20.w),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 24.w,
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await _showDeleteConfirmationDialog(historyItem);
                                  },
                                  onDismissed: (direction) {
                                    setState(() {
                                      _matrixHistory.removeAt(reversedIndex);
                                      _saveMatrixHistory();
                                    });
                                  },
                                  dismissThresholds: {DismissDirection.endToStart: 0.5},
                                  child: Card(
                                    margin: EdgeInsets.only(bottom: 12.h),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      side: BorderSide(
                                        color: colorScheme.outline.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () => _loadMatrixFromHistory(historyItem),
                                      onLongPress: () {
                                        // Provide haptic feedback
                                        HapticFeedback.mediumImpact();
                                        
                                        // Show a hint tooltip
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  Icons.swipe,
                                                  color: Colors.white,
                                                  size: 20.w,
                                                ),
                                                SizedBox(width: 12.w),
                                                Text('Swipe left to delete this matrix'),
                                              ],
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: colorScheme.tertiary,
                                            duration: const Duration(seconds: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10.r),
                                            ),
                                            margin: EdgeInsets.all(16.w),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: Padding(
                                        padding: EdgeInsets.all(12.w),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Timestamp with swipe hint
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14.w,
                                                  color: colorScheme.onSurface.withOpacity(0.5),
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} • ${timestamp.day}/${timestamp.month}/${timestamp.year}',
                                                  style: TextStyle(
                                                    color: colorScheme.onSurface.withOpacity(0.5),
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                                Spacer(),
                                                // Hint to swipe
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.swipe_left,
                                                      size: 14.w,
                                                      color: colorScheme.primary.withOpacity(0.6),
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: colorScheme.primary.withOpacity(0.6),
                                                        fontSize: 12.sp,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            
                                            SizedBox(height: 12.h),
                                            
                                            // Matrix preview with improved styling
                                            Container(
                                              padding: EdgeInsets.all(8.w),
                                              decoration: BoxDecoration(
                                                color: colorScheme.surface,
                                                borderRadius: BorderRadius.circular(8.r),
                                                border: Border.all(
                                                  color: colorScheme.outline.withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  for (int i = 0; i < (historyItem['coefficients'] as List<dynamic>).length; i++) 
                                                    Padding(
                                                      padding: EdgeInsets.only(bottom: 6.h),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          for (int j = 0; j < (historyItem['coefficients'][i] as List<dynamic>).length; j++)
                                                            Container(
                                                              width: 40.w,
                                                              alignment: Alignment.center,
                                                              margin: EdgeInsets.symmetric(horizontal: 2.w),
                                                              padding: EdgeInsets.symmetric(vertical: 4.h),
                                                              decoration: BoxDecoration(
                                                                color: colorScheme.primary.withOpacity(0.05),
                                                                borderRadius: BorderRadius.circular(4.r),
                                                              ),
                                                              child: Text(
                                                                '${_formatNumber(historyItem['coefficients'][i][j])}',
                                                                style: TextStyle(
                                                                  fontSize: 12.sp,
                                                                  color: colorScheme.onSurface,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          
                                                          Container(
                                                            width: 20.w,
                                                            alignment: Alignment.center,
                                                            child: Text(
                                                              '=',
                                                              style: TextStyle(
                                                                fontSize: 12.sp,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          
                                                          Container(
                                                            width: 40.w,
                                                            alignment: Alignment.center,
                                                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                                                            padding: EdgeInsets.symmetric(vertical: 4.h),
                                                            decoration: BoxDecoration(
                                                              color: colorScheme.tertiary.withOpacity(0.05),
                                                              borderRadius: BorderRadius.circular(4.r),
                                                            ),
                                                            child: Text(
                                                              '${_formatNumber(historyItem['constants'][i])}',
                                                              style: TextStyle(
                                                                fontSize: 12.sp,
                                                                color: colorScheme.tertiary,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add the showDeleteConfirmationDialog method
  Future<bool?> _showDeleteConfirmationDialog(Map<String, dynamic> historyItem) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Enhanced blurred background with animation
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0, end: 0.2),
                    builder: (context, value, child) {
                      return Container(
                        color: Colors.black.withOpacity(value),
                      );
                    },
                  ),
                ),
              ),
              // Dialog content with enhanced glass effect
              Center(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutQuint,
                  tween: Tween<double>(begin: 0.9, end: 1.0),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width > 500 ? 400.w : MediaQuery.of(context).size.width * 0.85,
                    margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 500 ? 40.w : 16.w),
                    constraints: BoxConstraints(maxWidth: 350.w),
                    decoration: BoxDecoration(
                      // Enhanced gradient with more layers
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.35, 0.7, 1.0],
                        colors: [
                          const Color(0xFFC62828).withOpacity(0.8),  // Brighter red
                          const Color(0xFFB71C1C).withOpacity(0.85),  // Dark red
                          const Color(0xFF960000).withOpacity(0.9),  // Darker red
                          const Color(0xFF7F0000).withOpacity(0.95),  // Very dark red
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32.r),
                      // Enhanced shadow for depth
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB71C1C).withOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                          spreadRadius: -12,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                          spreadRadius: 0,
                        ),
                      ],
                      // Enhanced border for glass effect
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32.r),
                      // Enhanced blur for glass effect
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            // Enhanced gradient overlay for light effect
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.3, 0.6, 1.0],
                              colors: [
                                Colors.white.withOpacity(0.4),
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.05),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Enhanced icon container with glow
                                Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.15),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.delete_rounded,
                                    color: Colors.white,
                                    size: 36.w,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                
                                // Enhanced title with glow effect
                                ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.9),
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: Text(
                                    'Delete Matrix',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22.sp,
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
                                ),
                                SizedBox(height: 16.h),
                                
                                // Matrix Preview Container with enhanced glass effect
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    // Enhanced glass effect with gradient
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.black.withOpacity(0.3),
                                        Colors.black.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
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
                                  // Using FittedBox to ensure the matrix fits within the dialog
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: 220.w),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (int i = 0; i < (historyItem['coefficients'] as List<dynamic>).length; i++) 
                                            Padding(
                                              padding: EdgeInsets.only(bottom: i < 2 ? 3.h : 0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  for (int j = 0; j < (historyItem['coefficients'][i] as List<dynamic>).length; j++)
                                                    Container(
                                                      width: 28.w,
                                                      height: 22.h,
                                                      alignment: Alignment.center,
                                                      margin: EdgeInsets.symmetric(horizontal: 1.w),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(3.r),
                                                      ),
                                                      child: Text(
                                                        '${_formatNumber(historyItem['coefficients'][i][j])}',
                                                        style: TextStyle(
                                                          fontSize: 9.sp,
                                                          color: Colors.white.withOpacity(0.9),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  Container(
                                                    width: 12.w,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '=',
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 28.w,
                                                    height: 22.h,
                                                    alignment: Alignment.center,
                                                    margin: EdgeInsets.only(left: 1.w),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.25),
                                                      borderRadius: BorderRadius.circular(3.r),
                                                    ),
                                                    child: Text(
                                                      '${_formatNumber(historyItem['constants'][i])}',
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                
                                // Enhanced warning message with glass effect
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.amber,
                                        size: 16.w,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          'This matrix will be permanently removed from history',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: 24.h),
                                
                                // Enhanced action buttons
                                Row(
                                  children: [
                                    // Cancel button with glass effect
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 16.h),
                                          backgroundColor: Colors.white.withOpacity(0.2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20.r),
                                            side: BorderSide(
                                              color: Colors.white.withOpacity(0.4),
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
                                    SizedBox(width: 12.w),
                                    // Delete button
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFFFF1744),
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(vertical: 16.h),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20.r),
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
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to show info dialog about Gauss-Jordan
  void _showInfoDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 500.w,
          ),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: isDark ? colorScheme.surface : Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      color: colorScheme.primary,
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gauss-Jordan Method',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Linear System Solver',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              
              // Make the content scrollable to avoid overflow
              Flexible(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content sections
                      _buildInfoSection(
                        colorScheme,
                        title: 'Description',
                        content: 'Gauss-Jordan elimination is an algorithm for obtaining reduced row echelon form of a matrix, which transforms the system into a form where the solution is immediately evident.',
                        icon: Icons.info_outline,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Steps of the Algorithm',
                        content: '1. Forward Elimination: Convert elements below each pivot to zero\n2. Backward Elimination: Convert elements above each pivot to zero\n3. Normalization: Scale pivot rows to make each pivot equal to 1',
                        icon: Icons.play_arrow,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Advantages',
                        content: 'The Gauss-Jordan method provides a systematic approach to solving systems of linear equations and computing matrix inverses in a single algorithm.',
                        icon: Icons.functions,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Partial Pivoting',
                        content: 'Improves numerical stability by selecting the largest absolute value in a column as the pivot element during elimination.',
                        icon: Icons.swap_vert,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24.h),
              
              // Close button - centered with gradient style
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 48.h,
                  width: 160.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.tertiary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8.r,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'GOT IT',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
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
  
  // Helper to build info sections
  Widget _buildInfoSection(
    ColorScheme colorScheme, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: colorScheme.primary,
              size: 20.w,
            ),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.sp,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
} 