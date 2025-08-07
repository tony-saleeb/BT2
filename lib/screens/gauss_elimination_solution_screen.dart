// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/gauss_elimination_method.dart';

class GaussEliminationSolutionScreen extends StatefulWidget {
  final GaussEliminationResult result;
  final bool useMultipliers;
  final int decimalPlaces;

  const GaussEliminationSolutionScreen({
    super.key,
    required this.result,
    required this.useMultipliers,
    required this.decimalPlaces,
  });

  @override
  State<GaussEliminationSolutionScreen> createState() =>
      _GaussEliminationSolutionScreenState();
}

class _GaussEliminationSolutionScreenState extends State<GaussEliminationSolutionScreen> with SingleTickerProviderStateMixin {
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
        // Don't process again if already disposed
        if (_disposed) return true;
        
        // Set as disposed to prevent further state changes
        _disposed = true;
        
        // Dismiss keyboard if open
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
        }
        
        // Clean up the tab controller
        _tabController.removeListener(() {});
        
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
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18.w),
                                  SizedBox(width: 8.w),
                                  const Text('Result'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timeline, size: 18.w),
                                  SizedBox(width: 8.w),
                                  const Text('Steps'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.grid_on_rounded, size: 18.w),
                                  SizedBox(width: 8.w),
                                  const Text('Matrix'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Tab content with animated transitions
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildResultTab(colorScheme),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildStepsTab(colorScheme),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildMatrixTab(colorScheme),
                          ),
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

  Widget _buildResultTab(ColorScheme colorScheme) {
    if (!widget.result.isSolved) {
      return _buildErrorView(colorScheme);
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSolutionCard(colorScheme),
          SizedBox(height: 24.h),
          _buildMethodExplanationCard(colorScheme),
        ],
      ),
    );
  }
  
  Widget _buildSolutionCard(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Solution Header
            Container(
              margin: EdgeInsets.only(bottom: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge and title row
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
                      
                      const Spacer(),
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
                    'System solved with Gauss elimination method',
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
                        stops: const [0.0, 0.6, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20.h),
            
            // Solution Values - Card-Based Layout
            ...List.generate(widget.result.solution.length, (i) {
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
                          'This solution was calculated using the Gauss Elimination method.\n\nThe results are accurate based on the input coefficients and constants.',
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
                  'Gauss Elimination Method',
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
              'The Gauss Elimination method solves systems of linear equations by transforming the system matrix into an upper triangular matrix through a series of elementary row operations, and then solving for the unknowns using back substitution.',
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
                children: [
                  _buildMethodStep(
                    colorScheme,
                    '1. Forward Elimination',
                    'Transform the system matrix into upper triangular form',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '2. Back Substitution',
                    'Solve for the variables starting from the last equation',
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
          child: Center(
            child: Icon(
              Icons.arrow_forward,
              color: colorScheme.primary,
              size: 16.w,
            ),
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
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepsTab(ColorScheme colorScheme) {
    if (!widget.result.isSolved) {
      return _buildErrorView(colorScheme);
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round toggle
          Card(
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
              child: Row(
                children: [
                  Text(
                    'Display Format:',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Row(
                      children: [
                        Switch(
                          value: _shouldRound,
                          onChanged: (value) {
                            setState(() {
                              _shouldRound = value;
                            });
                          },
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          _shouldRound ? 'Rounded' : 'Full Precision',
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          
          // Group computation steps by pivot operations
          _buildGroupedSteps(colorScheme),
        ],
      ),
    );
  }
  
  Widget _buildGroupedSteps(ColorScheme colorScheme) {
    // We need to process the computation steps from the debug data
    final computationSteps = widget.result.debug['computation_steps'];
    if (computationSteps == null || computationSteps.isEmpty) {
      return Center(
        child: Text(
          'No computation steps available',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16.sp,
          ),
        ),
      );
    }
  
    // Initialize
    List<Widget> stepWidgets = [];
    int stepCounter = 1;
    
    // First step is always the initial matrix
    if (computationSteps.isNotEmpty) {
      stepWidgets.add(
        _buildStepCard(
          colorScheme: colorScheme,
          stepNumber: stepCounter++,
          stepData: computationSteps[0],
          matrix: widget.result.originalMatrix,
          operationTitle: 'Initial Matrix',
          operationDescription: 'Initial augmented matrix before any operations.',
        ),
      );
    }
    
    // Process each computation step
    for (int i = 1; i < computationSteps.length; i++) {
      final stepData = computationSteps[i];
      final operationType = stepData['operation_type'];
      
      // When we find a row_elimination step
      if (operationType == 'row_elimination') {
        final pivotRow = stepData['pivot_row'];
        final operationRow = stepData['operation_row'];
        final multiplier = stepData['multiplier'];
        
        // Build operation description
        String operationTitle = 'Row Operation: R${operationRow + 1} = R${operationRow + 1} - m × R${pivotRow + 1}';
        String operationDescription = 'Step-by-step elimination using multiplier:';
        
        // Get the previous state matrix
        List<List<double>> prevMatrix = i > 1 ? computationSteps[i-1]['matrix'] : widget.result.originalMatrix;
        
        // Create a detailed calculation description
        operationDescription += '\n\nm${operationRow + 1}${pivotRow + 1} = (${_formatNumber(prevMatrix[operationRow][pivotRow])}) ÷ (${_formatNumber(prevMatrix[pivotRow][pivotRow])}) = ${_formatNumber(multiplier)}';
        
        // For each element in the row, show the calculation
        final numCols = prevMatrix[0].length;
        for (int col = pivotRow; col < numCols; col++) {
          double origValue = prevMatrix[operationRow][col];
          double newValue = stepData['matrix'][operationRow][col];
          
          operationDescription += '\n\na${operationRow + 1}${col + 1} = (${_formatNumber(origValue)}) - (${_formatNumber(multiplier)} × ${_formatNumber(prevMatrix[pivotRow][col])}) = ${_formatNumber(newValue)}';
        }
        
        // Add the step widget
        stepWidgets.add(
          _buildStepCard(
            colorScheme: colorScheme,
            stepNumber: stepCounter++,
            stepData: stepData,
            matrix: stepData['matrix'],
            operationTitle: operationTitle,
            operationDescription: operationDescription,
          ),
        );
      }
      // For other types of operations (pivot completion, swaps, etc.)
      else {
        String operationTitle = stepData['description'] ?? 'Matrix Operation';
        String operationDescription = '';
        
        if (operationType == 'pivot_complete') {
          operationDescription = 'Completed pivot operations for this column.';
        } else if (stepData['description'].toString().contains('Swap')) {
          final parts = stepData['description'].toString().split(' ');
          if (parts.length >= 3) {
            int row1 = int.tryParse(parts[2]) ?? -1;
            int row2 = int.tryParse(parts[4]) ?? -1;
            if (row1 >= 0 && row2 >= 0) {
              operationDescription = 'Swapped rows ${row1 + 1} and ${row2 + 1} to improve numerical stability.';
            }
          }
        }
        
        // Add the step widget
        stepWidgets.add(
          _buildStepCard(
            colorScheme: colorScheme,
            stepNumber: stepCounter++,
            stepData: stepData,
            matrix: stepData['matrix'],
            operationTitle: operationTitle,
            operationDescription: operationDescription,
          ),
        );
      }
    }
    
    return Column(children: stepWidgets);
  }
  
  Widget _buildStepCard({
    required ColorScheme colorScheme,
    required int stepNumber,
    required dynamic stepData,
    required dynamic matrix,
    required String operationTitle,
    required String operationDescription,
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
            
            // Matrix
            _buildMatrixView(
              matrix,
              colorScheme,
              showRowNumbers: true,
              showColNumbers: true,
              isStepMatrix: true,
              highlightPivot: stepData['pivot_row'] != null && stepData['pivot_col'] != null,
              pivotRow: stepData['pivot_row'],
              pivotCol: stepData['pivot_col'],
              operationRow: stepData['operation_row'],
            ),
            
            // If we have a detailed operation description, show it
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

  Widget _buildMatrixTab(ColorScheme colorScheme) {
    if (!widget.result.isSolved) {
      return _buildErrorView(colorScheme);
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original Matrix
          Card(
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
                        Icons.view_in_ar_outlined,
                        color: colorScheme.primary,
                        size: 24.w,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Original Matrix',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildMatrixView(
                    widget.result.originalMatrix,
                    colorScheme,
                    showRowNumbers: true,
                    showColNumbers: true,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          
          // Final Matrix
          Card(
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
                        Icons.view_in_ar_outlined,
                        color: colorScheme.primary,
                        size: 24.w,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Final Upper Triangular Matrix',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildMatrixView(
                    widget.result.steps.isNotEmpty 
                      ? widget.result.steps.last 
                      : widget.result.originalMatrix,
                    colorScheme,
                    showRowNumbers: true,
                    showColNumbers: true,
                    highlightDiagonal: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixView(
    dynamic matrix,
    ColorScheme colorScheme, {
    bool showRowNumbers = false,
    bool showColNumbers = false,
    bool highlightDiagonal = false,
    bool isStepMatrix = false,
    bool highlightPivot = false,
    int? pivotRow,
    int? pivotCol,
    int? operationRow,
  }) {
    // Handle different types of matrix data
    List<List<double>> matrixData;
    
    if (matrix is List<List<List<double>>>) {
      // If this is a list of matrices, take the first one
      if (matrix.isEmpty) return const SizedBox();
      matrixData = matrix[0];
    } else if (matrix is List<List<double>>) {
      matrixData = matrix;
    } else if (matrix is List && matrix.isNotEmpty && matrix[0] is List) {
      // Try to convert it to the right format
      try {
        matrixData = (matrix).map((row) {
          if (row is List) {
            return List<double>.from(row);
          }
          return <double>[];
        }).toList();
      } catch (e) {
        return const SizedBox();
      }
    } else {
      return const SizedBox();
    }
    
    if (matrixData.isEmpty) {
      return const SizedBox();
    }

    final numRows = matrixData.length;
    final numCols = matrixData[0].length;
    
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
                  
                  return Container(
                    width: 64.w,
                    height: 40.h,
                    margin: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: isLastColumn
                          ? colorScheme.surfaceVariant.withOpacity(0.3)
                          : (highlightDiagonal && isDiagonal
                              ? colorScheme.primary.withOpacity(0.1)
                              : colorScheme.surface),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: isLastColumn
                            ? colorScheme.secondary.withOpacity(0.3)
                            : (highlightDiagonal && isDiagonal
                                ? colorScheme.primary.withOpacity(0.5)
                                : colorScheme.outline.withOpacity(0.2)),
                        width: highlightDiagonal && isDiagonal ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _formatNumber(matrixData[i][j]),
                      style: GoogleFonts.robotoMono(
                        fontSize: 14.sp,
                        fontWeight: (highlightDiagonal && isDiagonal)
                            || isLastColumn
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isLastColumn
                            ? colorScheme.secondary
                            : (highlightDiagonal && isDiagonal
                                ? colorScheme.primary
                                : colorScheme.onSurface),
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

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 64.w,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error Solving System',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              widget.result.errorMessage ?? 'Unknown error occurred.',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 12.h,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build stats item
} 