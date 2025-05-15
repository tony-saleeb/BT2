import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cramer_method.dart';
import './cramer_solution_screen.dart';
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

class CramerMethodScreen extends StatefulWidget {
  const CramerMethodScreen({Key? key}) : super(key: key);

  @override
  State<CramerMethodScreen> createState() => _CramerMethodScreenState();
}

class _CramerMethodScreenState extends State<CramerMethodScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeInAnimation;
  late final Animation<double> _slideAnimation;

  // Fixed matrix dimensions
  final int _rows = 3;
  final int _cols = 3;
  
  // Matrix input controllers
  final List<List<TextEditingController>> _coefficientControllers = [];
  final List<TextEditingController> _constantControllers = [];
  
  // UI States
  bool _formHasError = false;
  String _errorMessage = '';
  bool _isLoading = false;
  final FocusNode _firstFieldFocus = FocusNode();
  bool _isDisposed = false;

  // SharedPreferences instance
  SharedPreferences? _prefs;
  
  // List to store matrix history
  final List<Map<String, dynamic>> _matrixHistory = [];
  
  // Storage key for matrix history
  static const String _matrixHistoryKey = 'cramer_matrix_history';

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
    
    // Initialize controllers
    _initializeControllers();
    
    // Load saved history
    _loadMatrixHistory();
    
    // Start animation
    _animationController.forward();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      try {
        super.setState(fn);
      } catch (e) {
        // Silently ignore state errors after disposal
        print('Ignoring setState error: $e');
      }
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
            // Default to 0 if parsing fails
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
          // Default to 0 if parsing fails
          constants.add(0);
          print('Warning: Could not parse constant at row $i: $text');
        }
      }
    }
    
    return constants;
  }

  Future<void> _loadMatrixHistory() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final String? historyJson = _prefs?.getString(_matrixHistoryKey);
      if (historyJson != null && mounted) {
        final List<dynamic> decoded = json.decode(historyJson);
        setState(() {
          _matrixHistory.clear();
          _matrixHistory.addAll(decoded.cast<Map<String, dynamic>>());
        });
      }
    } catch (e) {
      debugPrint('Error loading matrix history: $e');
    }
  }

  Future<void> _saveMatrixHistory() async {
    try {
      final String historyJson = json.encode(_matrixHistory);
      await _prefs?.setString(_matrixHistoryKey, historyJson);
    } catch (e) {
      debugPrint('Error saving matrix history: $e');
    }
  }

  void _saveCurrentMatrixToHistory() {
    final coefficients = _getCoefficientsMatrix();
    final constants = _getConstantsVector();
    
    // Only save if there's at least one non-zero value
    bool hasNonZeroValue = false;
    for (final row in coefficients) {
      for (final value in row) {
        if (value != 0) {
          hasNonZeroValue = true;
          break;
        }
      }
      if (hasNonZeroValue) break;
    }
    
    if (!hasNonZeroValue) {
      for (final value in constants) {
        if (value != 0) {
          hasNonZeroValue = true;
          break;
        }
      }
    }
    
    if (!hasNonZeroValue) return;

    final matrixData = {
      'coefficients': coefficients,
      'constants': constants,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      // Check for duplicates
      bool isDuplicate = false;
      for (final item in _matrixHistory) {
        if (_compareMatrices(item['coefficients'], coefficients) && 
            _compareVectors(item['constants'], constants)) {
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        _matrixHistory.insert(0, matrixData);
        if (_matrixHistory.length > 10) {
          _matrixHistory.removeLast();
        }
        _saveMatrixHistory();
      }
    });
  }
  
  // Helper method to compare matrices
  bool _compareMatrices(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_compareVectors(a[i], b[i])) return false;
    }
    return true;
  }
  
  // Helper method to compare vectors
  bool _compareVectors(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _loadMatrixFromHistory(Map<String, dynamic> matrixData) {
    final List<List<dynamic>> coefficients = 
        (matrixData['coefficients'] as List).map((row) => List<dynamic>.from(row)).toList();
    final List<dynamic> constants = matrixData['constants'] as List;

    setState(() {
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _cols; j++) {
          _coefficientControllers[i][j].text = coefficients[i][j].toString();
        }
        _constantControllers[i].text = constants[i].toString();
      }
      
      _formHasError = false;
      _errorMessage = '';
    });
  }

  void _generateRandomValues() {
    final random = math.Random();
    
    setState(() {
      // Generate a simple solution with integer values (typically 1-5)
      List<int> solution = List.generate(
        _rows, 
        (_) => random.nextInt(5) + 1  // Values between 1 and 5
      );
      
      // Generate a coefficient matrix with integer values and non-zero determinant
      List<List<int>> coefficients = [];
      bool hasValidDeterminant = false;
      
      while (!hasValidDeterminant) {
        // Create a matrix with small integer values
        coefficients = List.generate(
          _rows, 
          (_) => List.generate(
            _cols,
            (_) => random.nextInt(7) - 3  // Values between -3 and 3
          )
        );
        
        // Ensure diagonal dominance for better numerical stability
        for (int i = 0; i < _rows; i++) {
          int sum = 0;
          for (int j = 0; j < _cols; j++) {
            if (i != j) sum += coefficients[i][j].abs();
          }
          // Make diagonal element larger than sum of other elements in row
          coefficients[i][i] = sum + random.nextInt(3) + 1;
          
          // Occasionally make diagonal negative for variety
          if (random.nextBool() && random.nextBool()) {
            coefficients[i][i] *= -1;
          }
        }
        
        // Convert to double matrix for determinant calculation
        final doubleCoeffs = coefficients.map(
          (row) => row.map((val) => val.toDouble()).toList()
        ).toList();
        
        // Check if determinant is non-zero
        double det = CramerMethod.calculateDeterminant(doubleCoeffs);
        hasValidDeterminant = det.abs() > 0.001;
      }
      
      // Calculate constants based on the solution (Ax = b)
      List<int> constants = List.filled(_rows, 0);
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _cols; j++) {
          constants[i] += coefficients[i][j] * solution[j];
        }
      }
      
      // Set the values to the controllers
      for (int i = 0; i < _rows; i++) {
        for (int j = 0; j < _cols; j++) {
          _coefficientControllers[i][j].text = coefficients[i][j].toString();
        }
        _constantControllers[i].text = constants[i].toString();
      }
      
      _formHasError = false;
      _errorMessage = '';
    });
  }

  bool _hasEmptyFields() {
    for (int i = 0; i < _rows; i++) {
      for (int j = 0; j < _cols; j++) {
        if (_coefficientControllers[i][j].text.trim().isEmpty) {
          return true;
        }
      }
      if (_constantControllers[i].text.trim().isEmpty) {
        return true;
      }
    }
    return false;
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

  bool _validateInput() {
    if (_hasEmptyFields()) {
      setState(() {
        _formHasError = true;
        _errorMessage = 'Please fill all matrix values';
      });
      return false;
    }
    
    // Check if matrix determinant is zero
    final coefficients = _getCoefficientsMatrix();
    final determinant = CramerMethod.calculateDeterminant(coefficients);
    
    if (determinant.abs() < 1e-10) {
      setState(() {
        _formHasError = true;
        _errorMessage = 'Matrix determinant is zero. System has no unique solution.';
      });
      return false;
    }
    
    return true;
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
    
    // Validate input
    if (!_validateInput()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Save current matrix to history
    _saveCurrentMatrixToHistory();
    
    // Create a small delay to show loading animation
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _isDisposed) return;
      
      // Get matrices
      final coefficients = _getCoefficientsMatrix();
      final constants = _getConstantsVector();
      
      // Solve using Cramer's method
      final result = CramerMethod.solve(
        coefficients: coefficients,
        constants: constants,
      );
      
      if (!mounted || _isDisposed) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Navigate to solution screen with safety check for mounting state
      if (mounted && !_isDisposed) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => CramerSolutionScreen(
              coefficients: coefficients,
              constants: constants,
              solution: result['solution'] as List<double>,
              determinants: result['determinants'] as Map<String, double>,
              steps: result['steps'] as List<String>,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Save history before disposing
    _saveCurrentMatrixToHistory();
    
    // Dispose controllers
    for (final row in _coefficientControllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    
    for (final controller in _constantControllers) {
      controller.dispose();
    }
    
    _animationController.dispose();
    _firstFieldFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return Container(); // Return empty container if disposed
    
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        // Don't process again if already disposed
        if (_isDisposed) return true;
        
        // Set as disposed to prevent further state changes
        _isDisposed = true;
        
        // First, dismiss the keyboard if it's open
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
        
        // Ensure clean disposal when back button is pressed
        if (_isLoading && mounted) {
          setState(() {
            _isLoading = false;
          });
          return false;
        }
        return true;
      },
      child: GestureDetector(
        // Dismiss keyboard when tapping outside any input fields
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: isDark ? colorScheme.background : Colors.grey[50],
          appBar: AppBar(
            title: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ).createShader(bounds),
              child: const Text(
                'CRAMER\'S RULE',
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
                      '3×3 Matrix • Cramer\'s Rule',
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
            'Enter the coefficients and constants to solve the system using Cramer\'s rule.',
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
                      'Cramer\'s rule uses determinants to find the solution. The matrix determinant must be non-zero.',
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
    // Add current matrix to history before showing
    if (!_hasEmptyFields()) {
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
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: _matrixHistory.length,
                        itemBuilder: (context, index) {
                          final matrixData = _matrixHistory[index];
                          final timestamp = DateTime.parse(matrixData['timestamp']);
                          
                          return Dismissible(
                            key: Key('history_${matrixData['timestamp']}'),
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
                              return await _showDeleteConfirmationDialog(matrixData);
                            },
                            onDismissed: (direction) {
                              setState(() {
                                _matrixHistory.removeAt(index);
                                _saveMatrixHistory();
                              });
                            },
                            dismissThresholds: {DismissDirection.endToStart: 0.5},
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(
                                  color: colorScheme.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  _loadMatrixFromHistory(matrixData);
                                  Navigator.pop(context);
                                },
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
                                            for (int i = 0; i < (matrixData['coefficients'] as List<dynamic>).length; i++) 
                                              Padding(
                                                padding: EdgeInsets.only(bottom: 6.h),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    for (int j = 0; j < (matrixData['coefficients'][i] as List<dynamic>).length; j++)
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
                                                          '${_formatNumber(matrixData['coefficients'][i][j])}',
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
                                                        '${_formatNumber(matrixData['constants'][i])}',
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
        );
      },
    );
  }

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
                          'Cramer\'s Rule',
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
                        content: 'Cramer\'s rule is a method for solving systems of linear equations using determinants. It expresses the solution in terms of the ratio of determinants formed from the coefficient matrix.',
                        icon: Icons.info_outline,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Formula',
                        content: 'If Ax = b is a system with coefficient matrix A and constant vector b, and D is the determinant of A, then variable xi = Di/D, where Di is the determinant of A with the ith column replaced by b.',
                        icon: Icons.functions,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Limitations',
                        content: 'Cramer\'s rule only applies to systems with a unique solution (where the determinant of the coefficient matrix is not zero). It may not be computationally efficient for large systems.',
                        icon: Icons.warning_amber,
                      ),
                      
                      SizedBox(height: 16.h),
                      
                      _buildInfoSection(
                        colorScheme,
                        title: 'Advantages',
                        content: 'Cramer\'s rule provides a direct formula for the solution, which makes it useful for theoretical analysis. It\'s also very intuitive and provides explicit expressions for each variable.',
                        icon: Icons.thumb_up,
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

  String _formatNumber(dynamic number) {
    if (number is num) {
      // Check if the number is an integer or has decimal places
      if (number == number.toInt()) {
        return number.toInt().toString();
      } else {
        return number.toString();
      }
    } else if (number is String) {
      try {
        // Try to parse the string as a number and format it
        double parsedNumber = double.parse(number);
        if (parsedNumber == parsedNumber.toInt()) {
          return parsedNumber.toInt().toString();
        } else {
          return parsedNumber.toString();
        }
      } catch (e) {
        // Return original string if parsing fails
        return number;
      }
    } else {
      return 'N/A';
    }
  }
} 