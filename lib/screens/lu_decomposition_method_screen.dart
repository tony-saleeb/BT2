import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/lu_decomposition_method.dart';
import './lu_decomposition_solution_screen.dart';
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

class LUDecompositionMethodScreen extends StatefulWidget {
  const LUDecompositionMethodScreen({Key? key}) : super(key: key);

  @override
  State<LUDecompositionMethodScreen> createState() => _LUDecompositionMethodScreenState();
}

class _LUDecompositionMethodScreenState extends State<LUDecompositionMethodScreen>
    with SingleTickerProviderStateMixin {
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Matrix dimensions
  final int _rows = 3;
  final int _cols = 3;

  // Controllers for matrix input
  late List<List<TextEditingController>> _coefficientControllers;
  late List<TextEditingController> _constantControllers;
  
  // Focus node for first field (for auto-focus)
  final FocusNode _firstFieldFocus = FocusNode();
  
  // Method options
  bool _usePartialPivoting = false;
  
  // UI state
  bool _isLoading = false;
  bool _formHasError = false;
  String _errorMessage = '';
  
  // Matrix history for saving recent matrices
  List<Map<String, dynamic>> _matrixHistory = [];
  
  // Storage key for matrix history
  static const String _matrixHistoryKey = 'lu_decomposition_matrix_history';
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Create animations
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    // Initialize controllers
    _initializeControllers();
    
    // Load saved history
    _loadMatrixHistory();
    
    // Start animation
    _animationController.forward();
    
    // Focus first field after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_firstFieldFocus.canRequestFocus) {
        _firstFieldFocus.requestFocus();
      }
    });
  }
  
  @override
  void dispose() {
    // Clean up all controllers
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
  
  void _initializeControllers() {
    // Initialize coefficient controllers
    _coefficientControllers = List.generate(
      _rows,
      (i) => List.generate(
        _cols,
        (j) => MatrixInputController(),
      ),
    );
    
    // Initialize constant controllers
    _constantControllers = List.generate(
      _rows,
      (i) => MatrixInputController(),
    );
  }
  
  Future<void> _loadMatrixHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_matrixHistoryKey);
      
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _matrixHistory = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Handle errors silently in production
      debugPrint('Error loading matrix history: $e');
    }
  }
  
  Future<void> _saveMatrixHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(_matrixHistory);
      await prefs.setString(_matrixHistoryKey, historyJson);
    } catch (e) {
      // Handle errors silently in production
      debugPrint('Error saving matrix history: $e');
    }
  }
  
  void _resetForm() {
    setState(() {
      // Clear all input fields
      for (final row in _coefficientControllers) {
        for (final controller in row) {
          controller.clear();
        }
      }
      
      for (final controller in _constantControllers) {
        controller.clear();
      }
      
      // Reset error state
      _formHasError = false;
      _errorMessage = '';
      
      // Focus the first field
      _firstFieldFocus.requestFocus();
    });
  }
  
  void _generateRandomValues() {
    final random = math.Random();
    
    // Generate random integer values between -10 and 10
    setState(() {
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _cols; j++) {
          final value = random.nextInt(21) - 10; // Range: -10 to 10
          _coefficientControllers[i][j].text = value.toString();
        }
        
        final constant = random.nextInt(21) - 10; // Range: -10 to 10
        _constantControllers[i].text = constant.toString();
      }
      
      // Reset error state
      _formHasError = false;
      _errorMessage = '';
    });
  }
  
  void _solve() async {
    // Clear any previous errors
    setState(() {
      _formHasError = false;
      _errorMessage = '';
      _isLoading = true;
    });
    
    try {
      // Read coefficient matrix and constants vector
      final coeffMatrix = List.generate(
        _rows,
        (i) => List.generate(
          _cols,
          (j) {
            final textValue = _coefficientControllers[i][j].text;
            if (textValue.isEmpty) return 0.0;
            return double.tryParse(textValue) ?? 0.0;
          },
        ),
      );
      
      final constants = List.generate(
        _rows,
        (i) {
          final textValue = _constantControllers[i].text;
          if (textValue.isEmpty) return 0.0;
          return double.tryParse(textValue) ?? 0.0;
        },
      );
      
      // Check if matrix is valid (not all zeros)
      bool hasNonZero = false;
      for (final row in coeffMatrix) {
        for (final value in row) {
          if (value != 0) {
            hasNonZero = true;
            break;
          }
        }
        if (hasNonZero) break;
      }
      
      if (!hasNonZero) {
        setState(() {
          _formHasError = true;
          _errorMessage = 'Coefficient matrix must have at least one non-zero value.';
          _isLoading = false;
        });
        return;
      }
      
      // Save the current matrix to history
      _saveCurrentMatrixToHistory();
      
      // Call the static solve method
      final result = LUDecompositionMethod.solve(
        coefficients: coeffMatrix,
        constants: constants,
        usePartialPivoting: _usePartialPivoting,
        decimalPlaces: 4,
      );
      
      // Add a slight delay to show the loading animation
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate to solution screen
      if (!mounted) return;
      
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return LUDecompositionSolutionScreen(
              result: result,
              usePartialPivoting: _usePartialPivoting,
              decimalPlaces: 4,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
      
    } catch (e) {
      setState(() {
        _formHasError = true;
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Method to show info dialog about LU Decomposition
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
                          'LU Decomposition Method',
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
                        content: 'LU Decomposition is a method used to factor a square matrix as the product of a lower triangular matrix (L) and an upper triangular matrix (U).',
                        icon: Icons.info_outline,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Steps of the Algorithm',
                        content: '1. Factor matrix A into L and U\n2. Solve Ly = b for y using forward substitution\n3. Solve Ux = y for x using back substitution',
                        icon: Icons.play_arrow,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Practical Applications',
                        content: 'Used for solving linear systems, computing determinants, and finding matrix inverses with high efficiency for multiple right-hand sides.',
                        icon: Icons.functions,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Partial Pivoting',
                        content: 'Improves numerical stability by permuting rows to ensure large pivot elements, helping prevent division by small numbers during elimination.',
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
            'LU DECOMPOSITION',
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
                      '3×3 Matrix • LU Decomposition',
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
            'Enter the coefficients and constants to solve the system using LU Decomposition method.',
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
        // Allow numeric input with decimals and negative sign
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
      ],
      // Explicitly handle text changes
      onChanged: (value) {
        if (_formHasError) {
          setState(() {
            _formHasError = false;
          });
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

  void _showMatrixHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    child: Builder(
                      builder: (context) {
                        if (_matrixHistory.isEmpty) {
                          return Center(
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
                          );
                        } else {
                          return ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            itemCount: _matrixHistory.length,
                            itemBuilder: (context, index) {
                              final displayIndex = _matrixHistory.length - 1 - index;
                              final historyItem = _matrixHistory[displayIndex];
                              final uniqueKey = ValueKey(historyItem['timestamp'].toString());
                              // Handle timestamp in different formats
                              DateTime timestamp;
                              if (historyItem['timestamp'] is int) {
                                timestamp = DateTime.fromMillisecondsSinceEpoch(historyItem['timestamp']);
                              } else if (historyItem['timestamp'] is DateTime) {
                                timestamp = historyItem['timestamp'] as DateTime;
                              } else {
                                timestamp = DateTime.now();
                              }
                              final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                              final dateString = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
                              return Dismissible(
                                key: uniqueKey,
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20.w),
                                  child: Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 24.w,
                                  ),
                                ),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await _showDeleteConfirmationDialog(historyItem);
                                },
                                onDismissed: (direction) async {
                                  if (displayIndex >= 0 && displayIndex < _matrixHistory.length) {
                                    _matrixHistory.removeAt(displayIndex);
                                    await _saveMatrixHistory();
                                    await _loadMatrixHistory();
                                    setModalState(() {});
                                  }
                                },
                                child: InkWell(
                                  onTap: () {
                                    _loadMatrixFromHistory(historyItem);
                                    Navigator.pop(context);
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
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
                                  child: Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                    padding: EdgeInsets.all(12.w),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: colorScheme.outline.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Timestamp
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 14.w,
                                              color: colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                            SizedBox(width: 6.w),
                                            Text(
                                              '$timeString • $dateString',
                                              style: TextStyle(
                                                color: colorScheme.onSurface.withOpacity(0.5),
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                            Spacer(),
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
                                        // Matrix preview (same as before)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            ...List.generate((historyItem['coefficients'] as List<dynamic>).length, (i) {
                                              return Padding(
                                                padding: EdgeInsets.only(bottom: 6.h),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    ...List.generate((historyItem['coefficients'][i] as List<dynamic>).length, (j) {
                                                      return Container(
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
                                                      );
                                                    }),
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
                                              );
                                            }),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Show delete confirmation dialog
  Future<bool?> _showDeleteConfirmationDialog(Map<String, dynamic> historyItem) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
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
                                          ...List.generate((historyItem['coefficients'] as List<dynamic>).length, (i) {
                                            return Padding(
                                              padding: EdgeInsets.only(bottom: i < 2 ? 3.h : 0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  ...List.generate((historyItem['coefficients'][i] as List<dynamic>).length, (j) {
                                                    return Container(
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
                                                    );
                                                  }),
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
                                            );
                                          }),
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

  // Helper to check if at least one field has a value
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

  // Save current matrix to history
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

  // Format a number for display
  String _formatNumber(double number) {
    String formattedNumber = number.toString();
    if (formattedNumber.endsWith('.0')) {
      formattedNumber = formattedNumber.substring(0, formattedNumber.length - 2);
    }
    return formattedNumber;
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
} 