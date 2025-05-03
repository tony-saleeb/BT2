import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/gauss_jordan_method.dart';
import 'dart:math' as math;

class GaussJordanSolutionScreen extends StatefulWidget {
  final GaussJordanResult result;
  final bool usePartialPivoting;
  final int decimalPlaces;

  const GaussJordanSolutionScreen({
    Key? key,
    required this.result,
    required this.usePartialPivoting,
    required this.decimalPlaces,
  }) : super(key: key);

  @override
  State<GaussJordanSolutionScreen> createState() =>
      _GaussJordanSolutionScreenState();
}

class _GaussJordanSolutionScreenState extends State<GaussJordanSolutionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTabIndex = 0;
  bool _shouldRound = true;
  bool _disposed = false;  // Track disposal state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_currentTabIndex != _tabController.index && !_disposed) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  // Override setState to add safety checks
  @override
  void setState(VoidCallback fn) {
    if (!_disposed && mounted) {
      try {
        super.setState(fn);
      } catch (e) {
        // Silently ignore state errors after disposal
        print('Ignoring setState error: $e');
      }
    }
  }

  // Format number for display
  String _formatNumber(double? number) {
    if (number == null) return '--';
    
    String formattedNumber;
    if (_shouldRound) {
      formattedNumber = number.toStringAsFixed(widget.decimalPlaces);
      
      // Remove trailing zeros and decimal point if needed
      if (formattedNumber.contains('.')) {
        formattedNumber = formattedNumber.replaceAll(RegExp(r'0+$'), '');
        formattedNumber = formattedNumber.replaceAll(RegExp(r'\.$'), '');
      }
    } else {
      formattedNumber = number.toString();
    }
    
    return formattedNumber;
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        if (_disposed) return true;
        _disposed = true;
        
        // Dismiss keyboard if open
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
        
        return true;
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: isDark ? colorScheme.background : Colors.grey[50],
          appBar: AppBar(
            title: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ).createShader(bounds),
              child: Text(
                'SOLUTION',
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
          ),
          body: SafeArea(
            child: Stack(
              children: [
                // Background color
                Positioned.fill(
                  child: Container(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.02),
                  ),
                ),
                
                Column(
                  children: [
                    // Tab bar with improved design
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      child: Container(
                        height: 56.h,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.05),
                              blurRadius: 10.r,
                              offset: Offset(0, 4.h),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8.r,
                                offset: Offset(0, 2.h),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14.sp,
                          ),
                          isScrollable: true,
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18.w),
                                  SizedBox(width: 8.w),
                                  Text('Result'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.analytics_outlined, size: 18.w),
                                  SizedBox(width: 8.w),
                                  Text('Steps'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_outlined, size: 18.w),
                                  SizedBox(width: 8.w),
                                  Text('Verify'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildResultTab(colorScheme, isDark),
                          _buildStepsTab(colorScheme, isDark),
                          _buildVerificationTab(colorScheme, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Result tab showing final solution 
  Widget _buildResultTab(ColorScheme colorScheme, bool isDark) {
    // First check if we have a valid result
    if (widget.result.steps.isEmpty) {
      return _buildErrorMessage(
        'No solution steps available. The calculation may have failed.',
        colorScheme,
      );
    }
    
    if (!widget.result.isSolved || widget.result.solution.isEmpty) {
      // Provide a more specific error message when available
      final errorMsg = widget.result.errorMessage != null && widget.result.errorMessage!.isNotEmpty
          ? widget.result.errorMessage!
          : 'No solution available';
          
      return _buildErrorMessage(errorMsg, colorScheme);
    }
    
    final n = widget.result.solution.length;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solution card with final values
          _buildResultCard(colorScheme),
          SizedBox(height: 24.h),
          
          // Method explanation
          _buildMethodExplanationCard(colorScheme),
        ],
      ),
    );
  }

  // Widget to display final result with solution vector
  Widget _buildResultCard(ColorScheme colorScheme) {
    final n = widget.result.solution.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Modern badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                              size: 16.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Result',
                              style: GoogleFonts.inter(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Spacer(),
                    ],
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Modern title
                  Text(
                    'Solution Variables',
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  SizedBox(height: 8.h),
                  
                  // Subtitle
                  Text(
                    'System solved with Gauss-Jordan method',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  
                  SizedBox(height: 24.h),
                  
                  // Gradient divider
                  Container(
                    height: 2.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary.withOpacity(0.6),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.6, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Solution Values - Card-Based Layout
            ...List.generate(n, (i) {
              return Container(
                margin: EdgeInsets.only(bottom: 16.h),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main card for the solution value
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 20.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: i % 2 == 0
                              ? [
                                  colorScheme.primary.withOpacity(0.05),
                                  colorScheme.primary.withOpacity(0.1),
                                ]
                              : [
                                  colorScheme.tertiary.withOpacity(0.05),
                                  colorScheme.tertiary.withOpacity(0.1),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: (i % 2 == 0 ? colorScheme.primary : colorScheme.tertiary).withOpacity(0.1),
                            blurRadius: 10.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Empty space for the variable badge
                          SizedBox(width: 48.w),
                          
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: Row(
                                children: [
                                  // Center equals sign without lines
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                        decoration: BoxDecoration(
                                          color: i % 2 == 0
                                              ? colorScheme.primary.withOpacity(0.08)
                                              : colorScheme.tertiary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8.r),
                                          border: Border.all(
                                            color: i % 2 == 0
                                                ? colorScheme.primary.withOpacity(0.2)
                                                : colorScheme.tertiary.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '=',
                                          style: TextStyle(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.bold,
                                            color: i % 2 == 0
                                                ? colorScheme.primary
                                                : colorScheme.tertiary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 16.w),
                          
                          // Value
                          Container(
                            constraints: BoxConstraints(minWidth: 100.w),
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                              border: Border.all(
                                color: i % 2 == 0
                                    ? colorScheme.primary.withOpacity(0.2)
                                    : colorScheme.tertiary.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _formatNumber(widget.result.solution[i]),
                              style: GoogleFonts.robotoMono(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: i % 2 == 0 ? colorScheme.primary : colorScheme.tertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Variable badge with modern design
                    Positioned(
                      left: -8.w,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 54.w,
                          height: 54.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15.r,
                                offset: Offset(0, 5.h),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                color: i % 2 == 0
                                    ? colorScheme.primary
                                    : colorScheme.tertiary,
                              ),
                              child: Center(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'x',
                                        style: GoogleFonts.inter(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      TextSpan(
                                        text: '${i+1}',
                                        style: GoogleFonts.inter(
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
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
            }),
            
            SizedBox(height: 16.h),
            
            // Info section with custom design
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(isDark ? 0.2 : 0.3),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: colorScheme.secondary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: colorScheme.secondary,
                      size: 20.w,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Method Information',
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.sp,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'This solution was calculated using the Gauss-Jordan method.\n\nThe results are accurate based on the input coefficients and constants.',
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer.withOpacity(0.8),
                            fontSize: 13.sp,
                            height: 1.4,
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
    );
  }

  Widget _buildMethodExplanationCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  color: colorScheme.primary,
                  size: 24.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Gauss-Jordan Method',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              widget.usePartialPivoting
                  ? 'The Gauss-Jordan method with partial pivoting transforms a system of linear equations into reduced row echelon form through a series of elementary row operations, with row exchanges to maximize numerical stability.'
                  : 'The Gauss-Jordan method transforms a system of linear equations into reduced row echelon form through a series of elementary row operations, providing a direct solution to the system without requiring back substitution.',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'This solution was calculated in the following steps:',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.usePartialPivoting ? [
                  _buildMethodStep(
                    colorScheme,
                    '1. For each column k',
                    'Iterate through each column as the current pivot column',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '2. Partial Pivoting',
                    'Find row with largest absolute value in pivot column and swap',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '3. Scale Pivot Row',
                    'Divide pivot row by the pivot element to make pivot = 1',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '4. Eliminate All Other Rows',
                    'Create zeros in both above and below positions in the pivot column',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '5. Continue to Next Column',
                    'Repeat steps 1-4 until the matrix is in reduced row echelon form',
                  ),
                ] : [
                  _buildMethodStep(
                    colorScheme,
                    '1. Forward Elimination',
                    'Create zeros below each pivot element',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '2. Backward Elimination',
                    'Create zeros above each pivot element',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '3. Normalization',
                    'Scale each pivot row to make pivot values equal to 1',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodStep(
    ColorScheme colorScheme,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_forward,
            size: 14.w,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Steps tab showing the elimination process
  Widget _buildStepsTab(ColorScheme colorScheme, bool isDark) {
    if (widget.result.steps.isEmpty) {
      return _buildErrorMessage(
        'No steps available. The calculation may have failed.',
        colorScheme,
      );
    }

    if (!widget.result.isSolved && widget.result.errorMessage != null) {
      // Even if the solution failed, we can still show the steps that were completed
      return SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message at top
            _buildErrorMessageCard(widget.result.errorMessage!, colorScheme),
            SizedBox(height: 16.h),
            
            // Title section
            _buildStepsTitleSection(colorScheme),
            SizedBox(height: 16.h),
            
            // Generate step widgets
            _generateDetailedSteps(colorScheme, isDark),
            
            SizedBox(height: 24.h),
          ],
        ),
      );
    }

    if (!widget.result.isSolved || widget.result.steps.isEmpty) {
      return _buildErrorMessage(
        widget.result.errorMessage ?? 'No solution steps available',
        colorScheme,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section
          _buildStepsTitleSection(colorScheme),
          SizedBox(height: 16.h),
          
          // Generate step widgets with enhanced details
          _generateDetailedSteps(colorScheme, isDark),
          
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // New method to generate detailed step widgets similar to Gauss elimination
  Widget _generateDetailedSteps(ColorScheme colorScheme, bool isDark) {
    final List<Widget> stepWidgets = [];
    int stepCounter = 1;
    
    // Add the initial matrix as step 1
    if (widget.result.steps.isNotEmpty) {
      stepWidgets.add(
        _buildEnhancedStepCard(
          colorScheme: colorScheme,
          isDark: isDark,
          stepNumber: stepCounter++,
          matrix: widget.result.steps.first.matrix,
          operationTitle: 'Initial Matrix',
          operationDescription: widget.usePartialPivoting 
              ? 'Initial augmented matrix before applying partial pivoting Gauss-Jordan elimination.'
              : 'Initial augmented matrix before any operations.',
          step: widget.result.steps.first,
        ),
      );
    }
    
    // Process each step after the initial matrix
    for (int i = 1; i < widget.result.steps.length; i++) {
      final GaussJordanStep currentStep = widget.result.steps[i];
      final GaussJordanStep previousStep = widget.result.steps[i-1];
      
      String operationTitle = currentStep.description;
      String operationDescription = '';
      
      // Generate more detailed descriptions based on the operation type
      if (currentStep.isSwap && currentStep.swapRow1 != null && currentStep.swapRow2 != null) {
        // For row swaps
        int row1 = currentStep.swapRow1 ?? 0;
        int row2 = currentStep.swapRow2 ?? 0;
        
        if (widget.usePartialPivoting) {
          // Get pivot column from step description or default to the min of the two rows
          int pivotCol = currentStep.pivotCol ?? math.min(row1, row2);
          double val1 = previousStep.matrix[row1][pivotCol];
          double val2 = previousStep.matrix[row2][pivotCol];
          double absVal1 = val1.abs();
          double absVal2 = val2.abs();
          
          operationTitle = 'Partial Pivoting: Select Maximum Element in Column ${pivotCol + 1}';
          
          operationDescription = 'Identifying maximum element in column ${pivotCol + 1} for numerical stability:\n\n';
          
          // Describe the search for maximum element
          for (int r = pivotCol; r < previousStep.matrix.length; r++) {
            double value = previousStep.matrix[r][pivotCol];
            double absValue = value.abs();
            if (r == row1 || r == row2) {
              operationDescription += '• Row ${r + 1}: |${_formatNumber(value)}|' + 
                  (r == (absVal1 > absVal2 ? row1 : row2) ? ' ← Maximum element found' : '') + '\n';
            }
          }
          
          operationDescription += '\nSwapping rows ${row1 + 1} and ${row2 + 1} to position the maximum element ${_formatNumber(absVal1 > absVal2 ? val1 : val2)} as the pivot.';
        } else {
          operationTitle = 'Row Swap: R${row1 + 1} ↔ R${row2 + 1}';
          operationDescription = 'Swapped rows ${row1 + 1} and ${row2 + 1} to improve numerical stability.';
        }
      } 
      else if (operationTitle.contains('Scale row')) {
        // For pivot row scaling
        int rowIndex = currentStep.pivotRow ?? 0;
        int colIndex = currentStep.pivotCol ?? rowIndex;
        double pivotValue = previousStep.matrix[rowIndex][colIndex];
        
        if (widget.usePartialPivoting) {
          operationTitle = 'Scale Pivot Row: Make Pivot Element = 1';
          operationDescription = 'After positioning largest element in column ${colIndex + 1} as pivot, scaling row ${rowIndex + 1} to make pivot element = 1:';
        } else {
          operationTitle = 'Scale Pivot: R${rowIndex + 1} = (1/${_formatNumber(pivotValue)}) × R${rowIndex + 1}';
          operationDescription = 'Scaling row ${rowIndex + 1} to make the pivot element equal to 1:';
        }
        
        // Show the scaling calculation for each element in the row
        final int cols = previousStep.matrix[0].length;
        for (int col = 0; col < cols; col++) {
          double oldValue = previousStep.matrix[rowIndex][col];
          double newValue = currentStep.matrix[rowIndex][col];
          operationDescription += '\n\na${rowIndex + 1}${col + 1} = (${_formatNumber(oldValue)}) ÷ (${_formatNumber(pivotValue)}) = ${_formatNumber(newValue)}';
        }
      }
      else if (operationTitle.contains('Eliminate all other elements')) {
        // For elimination steps
        int pivotRow = currentStep.pivotRow ?? 0;
        int pivotCol = currentStep.pivotCol ?? 0;
        
        if (widget.usePartialPivoting) {
          operationTitle = 'Gaussian Elimination with Partial Pivoting';
          operationDescription = 'Using pivot at position (${pivotRow + 1}, ${pivotCol + 1}) with value 1.0 to create zeros in all other rows of column ${pivotCol + 1}:';
        } else {
          operationTitle = 'Elimination: Zero out all elements in column ${pivotCol + 1}';
          operationDescription = 'Creating zeros in all positions in column ${pivotCol + 1} (except pivot):';
        }
        
        // Build a description of the elimination for each affected row
        for (int row = 0; row < previousStep.matrix.length; row++) {
          if (row != pivotRow) {
            double factor = previousStep.matrix[row][pivotCol];
            if (factor != 0) {
              operationDescription += '\n\nRow ${row + 1}: R${row + 1} = R${row + 1} - (${_formatNumber(factor)}) × R${pivotRow + 1}';
              
              // Optional: Add detailed calculation for a few elements
              int maxDetailCols = 2; // Limit the number of detailed calculations to avoid clutter
              int cols = math.min(previousStep.matrix[0].length, pivotCol + maxDetailCols + 1);
              for (int col = pivotCol; col < cols; col++) {
                double origValue = previousStep.matrix[row][col];
                double subtractValue = factor * previousStep.matrix[pivotRow][col];
                double newValue = currentStep.matrix[row][col];
                operationDescription += '\n   a${row + 1}${col + 1} = (${_formatNumber(origValue)}) - (${_formatNumber(factor)} × ${_formatNumber(previousStep.matrix[pivotRow][col])}) = ${_formatNumber(newValue)}';
              }
              if (cols < previousStep.matrix[0].length) {
                operationDescription += '\n   ... and so on for the rest of the row';
              }
            }
          }
        }
      }
      
      // Add the step widget
      stepWidgets.add(
        _buildEnhancedStepCard(
          colorScheme: colorScheme,
          isDark: isDark,
          stepNumber: stepCounter++,
          matrix: currentStep.matrix,
          operationTitle: operationTitle,
          operationDescription: operationDescription,
          step: currentStep,
      ),
    );
  }

    return Column(children: stepWidgets);
  }
  
  // Enhanced step card matching the Gauss elimination design
  Widget _buildEnhancedStepCard({
    required ColorScheme colorScheme,
    required bool isDark,
    required int stepNumber,
    required List<List<double>> matrix,
    required String operationTitle,
    required String operationDescription,
    required GaussJordanStep step,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 16.h),
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step header
              Row(
                children: [
                  Container(
                  width: 32.w,
                  height: 32.w,
                    decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  child: Center(
                    child: Text(
                      stepNumber.toString(),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                    'Step $stepNumber: $operationTitle',
                      style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              
            // Matrix display matching Gauss elimination style
            _buildMatrixView(
              matrix,
              colorScheme,
              showRowNumbers: true,
              showColNumbers: true,
              isStepMatrix: true,
              highlightPivot: step.pivotRow != null && step.pivotCol != null,
              pivotRow: step.pivotRow,
              pivotCol: step.pivotCol,
              highlightSwapRows: step.isSwap,
              swapRow1: step.swapRow1,
              swapRow2: step.swapRow2,
            ),
            
            // Operation description section
            if (operationDescription.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.functions,
                          color: colorScheme.secondary,
                          size: 18.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Operation Details',
                            style: TextStyle(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      operationDescription,
                      style: GoogleFonts.robotoMono(
                        fontSize: 13.sp,
                        height: 1.5,
                        color: colorScheme.onSurface,
                  ),
                ),
            ],
          ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Enhanced matrix view to match Gauss elimination style
  Widget _buildMatrixView(
    List<List<double>> matrix,
    ColorScheme colorScheme, {
    bool showRowNumbers = false,
    bool showColNumbers = false,
    bool highlightDiagonal = false,
    bool isStepMatrix = false,
    bool highlightPivot = false,
    int? pivotRow,
    int? pivotCol,
    bool highlightSwapRows = false,
    int? swapRow1,
    int? swapRow2,
  }) {
    if (matrix.isEmpty) {
      return const SizedBox();
    }

    final numRows = matrix.length;
    final numCols = matrix[0].length;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (showColNumbers) ...[
            Row(
              children: [
                if (showRowNumbers) SizedBox(width: 32.w),
                ...List.generate(numCols - 1, (j) {
                  return Container(
                    width: 64.w,
                    height: 24.h,
                    alignment: Alignment.center,
          child: Text(
                      'x${j + 1}',
            style: TextStyle(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
                Container(
                  width: 64.w,
                  height: 24.h,
                  alignment: Alignment.center,
                  child: Text(
                    'b',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
            ),
          ),
        ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
          ...List.generate(numRows, (i) {
            return Row(
          children: [
                if (showRowNumbers) ...[
            Container(
                    width: 32.w,
                    height: 40.h,
                    alignment: Alignment.center,
                    child: Text(
                      'R${i + 1}',
                      style: TextStyle(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                ),
              ),
            ),
                ],
                ...List.generate(numCols, (j) {
                  final isDiagonal = i == j;
                  final isLastColumn = j == numCols - 1;
                  final isPivot = highlightPivot && i == pivotRow && j == pivotCol;
                  final isSwappedRow = highlightSwapRows && (i == swapRow1 || i == swapRow2);
                  
                  // Determine cell background color
                  Color? bgColor;
                  Color borderColor;
                  double borderWidth = 1;
                  
                  if (isPivot) {
                    bgColor = colorScheme.primary.withOpacity(0.1);
                    borderColor = colorScheme.primary.withOpacity(0.5);
                    borderWidth = 2;
                  } else if (isSwappedRow) {
                    bgColor = colorScheme.secondary.withOpacity(0.1);
                    borderColor = colorScheme.secondary.withOpacity(0.3);
                  } else if (isLastColumn) {
                    bgColor = colorScheme.surfaceVariant.withOpacity(0.3);
                    borderColor = colorScheme.secondary.withOpacity(0.3);
                  } else if (highlightDiagonal && isDiagonal) {
                    bgColor = colorScheme.primary.withOpacity(0.1);
                    borderColor = colorScheme.primary.withOpacity(0.5);
                    borderWidth = 2;
                  } else {
                    bgColor = colorScheme.surface;
                    borderColor = colorScheme.outline.withOpacity(0.2);
                  }
                        
                        return Container(
                    width: 64.w,
                    height: 40.h,
                          margin: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                      color: bgColor,
                            borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                          ),
                    alignment: Alignment.center,
                          child: Text(
                            _formatNumber(matrix[i][j]),
                            style: GoogleFonts.robotoMono(
                        fontSize: 14.sp,
                        fontWeight: isPivot || isLastColumn || (highlightDiagonal && isDiagonal)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isPivot
                                  ? colorScheme.primary
                            : isLastColumn
                                ? colorScheme.secondary
                                : (highlightDiagonal && isDiagonal)
                                    ? colorScheme.primary
                                    : isSwappedRow
                                        ? colorScheme.secondary
                                      : colorScheme.onSurface,
                            ),
                      overflow: TextOverflow.visible,
                          ),
                        );
                }),
              ],
            );
          }),
        ],
            ),
    );
  }

  Widget _buildStepsTitleSection(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: colorScheme.primary,
                  size: 24.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Solution Steps',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
              ),
            ),
          ],
        ),
            SizedBox(height: 12.h),
              Text(
              'Below are the detailed steps of the Gauss-Jordan elimination process. Each step shows the matrix after a specific operation.',
                style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontSize: 14.sp,
                height: 1.4,
                ),
              ),
            ],
          ),
        ),
    );
  }

  // Verification tab showing verification of the solution
  Widget _buildVerificationTab(ColorScheme colorScheme, bool isDark) {
    if (!widget.result.isSolved || widget.result.solution.isEmpty) {
      return _buildErrorMessage(
        widget.result.errorMessage ?? 'No solution to verify',
        colorScheme,
      );
    }

    final n = widget.result.solution.length;
    final originalMatrix = widget.result.originalMatrix;
    
    // Compute verification by multiplying original coefficients with solution
    List<double> computedResults = [];
    for (int i = 0; i < n; i++) {
      double sum = 0;
      for (int j = 0; j < n; j++) {
        sum += originalMatrix[i][j] * widget.result.solution[j];
      }
      computedResults.add(sum);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title card
          _buildVerificationTitleCard(colorScheme),
          SizedBox(height: 24.h),
          
          // Verification table
          _buildVerificationTable(computedResults, colorScheme, isDark),
          
          SizedBox(height: 24.h),
          
          // Explanation
          _buildVerificationExplanation(colorScheme),
        ],
      ),
    );
  }

  Widget _buildVerificationTitleCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: colorScheme.tertiary,
                  size: 24.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Solution Verification',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              'This section verifies that the solution satisfies the original system of equations by substituting back the solution values into the original equations.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationTable(
    List<double> computedResults,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final n = widget.result.solution.length;
    final originalMatrix = widget.result.originalMatrix;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verification by Substitution',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 16.h),
            
            // Verification table
            ...List.generate(
              n,
              (i) => Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: i % 2 == 0
                      ? colorScheme.surface
                      : colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Equation header
                    Row(
                      children: [
                        Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Equation ${i + 1}',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 12.h),
                    
                    // Original equation
                    Row(
                      children: [
                        Text(
                          'Original:',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _formatEquation(originalMatrix[i], n),
                            style: GoogleFonts.robotoMono(
                              fontSize: 14.sp,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8.h),
                    
                    // Substitution
                    Row(
                      children: [
                        Text(
                          'Substitution:',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _formatSubstitution(originalMatrix[i], n),
                            style: GoogleFonts.robotoMono(
                              fontSize: 14.sp,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8.h),
                    
                    // Result
                    Row(
                      children: [
                        Text(
                          'Result:',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${_formatNumber(computedResults[i])} ≈ ${_formatNumber(originalMatrix[i][n])}',
                          style: GoogleFonts.robotoMono(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: _isApproximatelyEqual(
                                    computedResults[i], originalMatrix[i][n])
                                ? colorScheme.tertiary
                                : colorScheme.error,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          _isApproximatelyEqual(computedResults[i], originalMatrix[i][n])
                              ? Icons.check_circle
                              : Icons.error,
                          color: _isApproximatelyEqual(computedResults[i], originalMatrix[i][n])
                              ? colorScheme.tertiary
                              : colorScheme.error,
                          size: 18.w,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Overall verification result
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: _areAllResultsValid(computedResults)
                    ? colorScheme.tertiary.withOpacity(0.1)
                    : colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _areAllResultsValid(computedResults)
                      ? colorScheme.tertiary.withOpacity(0.3)
                      : colorScheme.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _areAllResultsValid(computedResults)
                        ? Icons.verified_outlined
                        : Icons.error_outline,
                    color: _areAllResultsValid(computedResults)
                        ? colorScheme.tertiary
                        : colorScheme.error,
                    size: 24.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _areAllResultsValid(computedResults)
                          ? 'Solution verified! All equations are satisfied.'
                          : 'Some equations are not satisfied exactly. There may be numerical errors.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: _areAllResultsValid(computedResults)
                            ? colorScheme.tertiary
                            : colorScheme.error,
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

  Widget _buildVerificationExplanation(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Verification',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Verification involves substituting the solution values back into the original system of equations to check if they satisfy the equations.\n\nSmall numerical differences may occur due to floating-point arithmetic precision.',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEquation(List<double> row, int n) {
    final buffer = StringBuffer();
    
    for (int j = 0; j < n; j++) {
      if (j > 0) {
        buffer.write(row[j] >= 0 ? ' + ' : ' - ');
        buffer.write('${_formatNumber(row[j].abs())}x${j + 1}');
      } else {
        buffer.write('${_formatNumber(row[j])}x${j + 1}');
      }
    }
    
    buffer.write(' = ${_formatNumber(row[n])}');
    return buffer.toString();
  }

  String _formatSubstitution(List<double> row, int n) {
    final buffer = StringBuffer();
    
    for (int j = 0; j < n; j++) {
      if (j > 0) {
        buffer.write(row[j] >= 0 ? ' + ' : ' - ');
        buffer.write('${_formatNumber(row[j].abs())}(${_formatNumber(widget.result.solution[j])})');
      } else {
        buffer.write('${_formatNumber(row[j])}(${_formatNumber(widget.result.solution[j])})');
      }
    }
    
    return buffer.toString();
  }

  bool _isApproximatelyEqual(double a, double b) {
    return (a - b).abs() < 1e-9;
  }

  bool _areAllResultsValid(List<double> computedResults) {
    final n = computedResults.length;
    
    for (int i = 0; i < n; i++) {
      if (!_isApproximatelyEqual(computedResults[i], widget.result.originalMatrix[i][n])) {
        return false;
      }
    }
    
    return true;
  }

  // Display an error message
  Widget _buildErrorMessage(String message, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 48.w,
            ),
            SizedBox(height: 16.h),
            Text(
              message,
              style: TextStyle(
                fontSize: 16.sp,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            
            // Show steps button if we have any steps
            if (widget.result.steps.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  _tabController.animateTo(1); // Switch to Steps tab
                },
                icon: Icon(Icons.analytics_outlined),
                label: Text('View Solution Steps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
              
            SizedBox(height: 16.h),
            
            // Add suggestion to try with different input
            Text(
              'Try using the "Fill with random values" button in the method screen to generate a solvable system.',
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Error message in card form for steps tab
  Widget _buildErrorMessageCard(String message, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: colorScheme.error.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 24.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error in Solution Process',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'The steps below show the calculation progress before the error occurred.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onErrorContainer.withOpacity(0.8),
                      fontSize: 13.sp,
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
} 