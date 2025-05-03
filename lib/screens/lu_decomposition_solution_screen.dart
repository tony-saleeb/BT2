import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lu_decomposition_method.dart';

class LUDecompositionSolutionScreen extends StatefulWidget {
  final LUDecompositionResult result;
  final bool usePartialPivoting;
  final int decimalPlaces;

  const LUDecompositionSolutionScreen({
    Key? key,
    required this.result,
    required this.usePartialPivoting,
    required this.decimalPlaces,
  }) : super(key: key);

  @override
  State<LUDecompositionSolutionScreen> createState() => _LUDecompositionSolutionScreenState();
}

class _LUDecompositionSolutionScreenState extends State<LUDecompositionSolutionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _useRoundedValues = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Unfocus any text fields when switching tabs
        FocusScope.of(context).unfocus();
      }
    });
  }
  
  @override
  void dispose() {
    _disposed = true;
    _tabController.dispose();
    super.dispose();
  }
  
  // Format numbers for display
  String _formatNumber(double? number) {
    if (number == null) return '--';
    
    String formattedNumber;
    if (_useRoundedValues) {
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
  
  // Main UI for solution page
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

  // Result tab showing final solution and verification
  Widget _buildResultTab(ColorScheme colorScheme, bool isDark) {
    if (!widget.result.isSolved || widget.result.solution.isEmpty) {
      return _buildErrorMessage('No solution available', colorScheme);
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
  
  // L matrix tab showing lower triangular matrix
  Widget _buildLMatrixTab(ColorScheme colorScheme, bool isDark) {
    if (!widget.result.isSolved || widget.result.lMatrix.isEmpty) {
      return _buildErrorMessage('L matrix not available', colorScheme);
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Matrix header
          _buildSectionHeader(
            'Lower Triangular Matrix (L)',
            'The matrix containing multipliers used during elimination',
            Icons.arrow_downward_rounded,
            colorScheme,
          ),
          
          SizedBox(height: 16.h),
          
          // Show matrix
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: _buildMatrixDisplay(
                widget.result.lMatrix, 
                colorScheme,
                showRowNumbers: true,
                showColNumbers: false,
                highlightDiagonal: true,
              ),
            ),
          ),
          
          SizedBox(height: 24.h),
          
          _buildInfoCard(
            colorScheme,
            title: 'About L Matrix',
            content: 'In LU decomposition, L is a lower triangular matrix with 1\'s on the diagonal. It captures the multipliers used during elimination that would transform A into U.',
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
  
  // U matrix tab showing upper triangular matrix
  Widget _buildUMatrixTab(ColorScheme colorScheme, bool isDark) {
    if (!widget.result.isSolved || widget.result.uMatrix.isEmpty) {
      return _buildErrorMessage('U matrix not available', colorScheme);
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Matrix header
          _buildSectionHeader(
            'Upper Triangular Matrix (U)',
            'The result of the forward elimination phase',
            Icons.arrow_upward_rounded,
            colorScheme,
          ),
          
          SizedBox(height: 16.h),
          
          // Show matrix
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: _buildMatrixDisplay(
                widget.result.uMatrix, 
                colorScheme,
                showRowNumbers: true,
                showColNumbers: false,
                highlightDiagonal: true,
              ),
            ),
          ),
          
          SizedBox(height: 24.h),
          
          _buildInfoCard(
            colorScheme,
            title: 'About U Matrix',
            content: 'The U matrix is an upper triangular matrix that results from the decomposition. We can solve Ux = y through back substitution to find our solution vector.',
            icon: Icons.info_outline,
          ),
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
                    'System solved with LU decomposition method',
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
                          'This solution was calculated using the LU Decomposition method.\n\nThe results are accurate based on the input coefficients and constants.',
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
  
  // Widget to display method explanation
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
                  'LU Decomposition Method',
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
              'The LU Decomposition method factors a matrix A into a lower triangular matrix L and an upper triangular matrix U, such that A = LU. This factorization simplifies solving linear systems, computing determinants, and finding matrix inverses.',
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
                    '1. LU Factorization',
                    'Decompose the matrix A into L and U matrices',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '2. Forward Substitution',
                    'Solve LC = B for intermediate vector C',
                  ),
                  SizedBox(height: 8.h),
                  _buildMethodStep(
                    colorScheme,
                    '3. Back Substitution',
                    'Solve UX = C for solution vector X',
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
  
  // Display section headers
  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: colorScheme.primary,
              size: 24.w,
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.only(left: 36.w),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  // Display an info card
  Widget _buildInfoCard(
    ColorScheme colorScheme, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              content,
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
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
          ],
        ),
      ),
    );
  }
  
  // Matrix view widget
  Widget _buildMatrixDisplay(
    List<List<double>> matrix,
    ColorScheme colorScheme, {
    bool highlightDiagonal = false,
    bool upperTriangular = false,
    bool lowerTriangular = false,
    int? highlightRow,
    int? highlightCol,
    bool showRowNumbers = false,
    bool showColNumbers = false,
  }) {
    final rows = matrix.length;
    final cols = matrix[0].length;
    
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
                ...List.generate(cols, (j) {
                  // For augmented matrix, use 'b' for the last column
                  final isLastColumn = j == cols - 1;
                  final label = isLastColumn && cols > rows ? 'b' : 'x${j + 1}';
                  
                  return Container(
                    width: 64.w,
                    height: 24.h,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ],
            ),
            SizedBox(height: 8.h),
          ],
          ...List.generate(rows, (i) {
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
                ...List.generate(cols, (j) {
                  final isDiagonal = i == j;
                  final isLastColumn = j == cols - 1;
                  final isZero = matrix[i][j].abs() < 1e-10;
                  final shouldShow = !(upperTriangular && i > j) && !(lowerTriangular && i < j);
                  
                  return Container(
                    width: 64.w,
                    height: 40.h,
                    margin: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: isLastColumn && cols > rows
                          ? colorScheme.surfaceVariant.withOpacity(0.3)
                          : (highlightDiagonal && isDiagonal
                              ? colorScheme.primary.withOpacity(0.1)
                              : colorScheme.surface),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: isLastColumn && cols > rows
                            ? colorScheme.secondary.withOpacity(0.3)
                            : (isDiagonal && highlightDiagonal
                                ? colorScheme.primary.withOpacity(0.5)
                                : colorScheme.outline.withOpacity(0.2)),
                        width: highlightDiagonal && isDiagonal ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      shouldShow ? _formatNumber(matrix[i][j]) : (isZero ? '0' : _formatNumber(matrix[i][j])),
                      style: GoogleFonts.robotoMono(
                        fontSize: 14.sp,
                        fontWeight: (highlightDiagonal && isDiagonal)
                            || (isLastColumn && cols > rows)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isLastColumn && cols > rows
                            ? colorScheme.secondary
                            : (highlightDiagonal && isDiagonal
                                ? colorScheme.primary
                                : isZero 
                                    ? colorScheme.onSurface.withOpacity(0.5) 
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

  // Steps tab showing the decomposition process
  Widget _buildStepsTab(ColorScheme colorScheme, bool isDark) {
    if (!widget.result.isSolved || widget.result.lMatrix.isEmpty) {
      return _buildErrorMessage('Step-by-step details not available', colorScheme);
    }
    
    // Get matrices and dimensions for calculations
    final matrixA = widget.result.originalMatrix;
    final matrixL = widget.result.lMatrix;
    final matrixU = widget.result.uMatrix;
    final vectorB = widget.result.originalB;
    final vectorY = widget.result.yVector;
    final vectorX = widget.result.solution;
    final n = matrixA.length;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
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
                            value: _useRoundedValues,
                            onChanged: (value) {
                              setState(() {
                                _useRoundedValues = value;
                              });
                            },
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            _useRoundedValues ? 'Rounded' : 'Full Precision',
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
            SizedBox(height: 24.h),
            
            // Original matrix display as first step
            _buildStepCard(
              colorScheme: colorScheme,
              stepNumber: 1,
              title: 'Initial Matrix',
              description: 'Original matrix A before decomposition.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMatrixDisplay(
                    matrixA,
                    colorScheme,
                    showRowNumbers: true,
                    showColNumbers: true,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Elimination steps with modern design
            ..._buildDetailedEliminationSteps(matrixA, matrixL, matrixU, colorScheme),
            
            SizedBox(height: 16.h),
            
            // Final L and U matrices
            _buildStepCard(
              colorScheme: colorScheme,
              stepNumber: n,
              title: 'Final Decomposition',
              description: 'The matrix A has been factored into L and U matrices where A = LU.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Side by side L and U matrices
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          children: [
                            Text(
                              'L Matrix (Lower)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: colorScheme.secondary,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: colorScheme.secondary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(8.w),
                                child: _buildMatrixDisplay(matrixL, colorScheme, lowerTriangular: true, highlightDiagonal: true, showColNumbers: false, showRowNumbers: true),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 16.w),
                        Column(
                          children: [
                            Text(
                              'U Matrix (Upper)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: colorScheme.tertiary,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: colorScheme.tertiary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(8.w),
                                child: _buildMatrixDisplay(matrixU, colorScheme, upperTriangular: true, highlightDiagonal: true, showColNumbers: false, showRowNumbers: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Forward Substitution
            _buildStepCard(
              colorScheme: colorScheme,
              stepNumber: n + 1,
              title: 'Step 2: Solve LC = B',
              description: 'Forward substitution to find the intermediate vector C.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show vector B
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Vector B: ',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < n; i++)
                                Padding(
                                  padding: EdgeInsets.only(bottom: i < n - 1 ? 8.h : 0),
                                  child: Text(
                                    'b${i + 1} = ${_formatNumber(vectorB[i])}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Solution container with improved styling
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: colorScheme.secondary.withOpacity(0.3),
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
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Forward Substitution Results',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        for (int i = 0; i < n; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: i < n - 1 ? 12.h : 0, left: 8.w),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: GoogleFonts.robotoMono().fontFamily,
                                  fontSize: 16.sp,
                                  color: colorScheme.onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'c${i+1} = ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${_formatNumber(vectorY![i])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Back Substitution
            _buildStepCard(
              colorScheme: colorScheme,
              stepNumber: n + 2,
              title: 'Step 3: Solve UX = C',
              description: 'Back substitution to find the solution vector X.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Solution container with improved styling
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: colorScheme.tertiary.withOpacity(0.3),
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
                              color: colorScheme.tertiary,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Back Substitution Results',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        for (int i = n - 1; i >= 0; i--)
                          Padding(
                            padding: EdgeInsets.only(bottom: i > 0 ? 12.h : 0, left: 8.w),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: GoogleFonts.robotoMono().fontFamily,
                                  fontSize: 16.sp,
                                  color: colorScheme.onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'x${i+1} = ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${_formatNumber(vectorX[i])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Final Solution
            _buildStepCard(
              colorScheme: colorScheme,
              stepNumber: n + 3,
              title: 'Final Solution',
              description: 'The complete solution vector X.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < n; i++)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: i < n - 1 ? 12.h : 0),
                            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: i.isEven 
                                ? colorScheme.primary.withOpacity(0.05) 
                                : colorScheme.surface,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36.w,
                                  height: 36.w,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'x${i+1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Text(
                                  '=',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    _formatNumber(vectorX[i]),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
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
          ],
        ),
      ),
    );
  }
  
  // Helper method to build step cards in Gauss style
  Widget _buildStepCard({
    required ColorScheme colorScheme,
    required int stepNumber,
    required String title,
    required String description,
    required Widget child,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
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
            ),
            SizedBox(height: 16.h),
            
            // Step content
            child,
          ],
        ),
      ),
    );
  }

  // New implementation for elimination steps in Gauss style
  List<Widget> _buildDetailedEliminationSteps(
    List<List<double>> matrixA, 
    List<List<double>> matrixL, 
    List<List<double>> matrixU, 
    ColorScheme colorScheme
  ) {
    final n = matrixA.length;
    final List<Widget> stepWidgets = [];
    
    for (int k = 0; k < n - 1; k++) {
      final stepNumber = k + 2; // Start at 2 because first step is the initial matrix
      
      stepWidgets.add(
        _buildStepCard(
          colorScheme: colorScheme,
          stepNumber: stepNumber,
          title: 'Elimination of Column ${k+1}',
          description: 'Find multipliers and eliminate elements below the diagonal in column ${k+1}.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Multipliers container with improved styling
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12.r),
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
                          size: 20.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Multipliers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    
                    // Multipliers in a more stylized format
                    for (int i = k + 1; i < n; i++)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: i < n - 1 ? 8.h : 0),
                        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: colorScheme.onSurface,
                              fontFamily: GoogleFonts.robotoMono().fontFamily,
                            ),
                            children: [
                              TextSpan(text: 'L${i+1},${k+1} = '),
                              TextSpan(
                                text: '${_formatNumber(matrixL[i][k])}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: 16.h),
              
              // Elimination operation description
              Text(
                'Result after elimination:',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              
              // Display U matrix after this elimination step with improved borders
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: _buildMatrixDisplay(
                  matrixU, 
                  colorScheme,
                  highlightRow: k,
                  highlightCol: k,
                  showRowNumbers: true,
                  showColNumbers: true,
                  upperTriangular: true,
                ),
              ),
              
              // Operation explanation
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withOpacity(0.08),
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
                          Icons.info_outline,
                          color: colorScheme.tertiary,
                          size: 18.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Operation Details',
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Each row below the pivot is modified by subtracting a multiple of the pivot row. The multiplier becomes an element in the L matrix.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
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
    
    return stepWidgets;
  }

  // Verification tab showing verification of the solution
  Widget _buildVerificationTab(ColorScheme colorScheme, bool isDark) {
    if (!widget.result.isSolved) {
      return _buildErrorMessage('Verification not available', colorScheme);
    }
    
    // Get matrices and vectors for verification
    final matrixA = widget.result.originalMatrix;
    final matrixL = widget.result.lMatrix;
    final matrixU = widget.result.uMatrix;
    final vectorB = widget.result.originalB;
    final vectorC = widget.result.yVector; // The intermediate vector (previously called y)
    final vectorX = widget.result.solution;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          _buildSectionHeader(
            'Solution Verification',
            'Confirming the accuracy of our results',
            Icons.verified_outlined,
            colorScheme,
          ),
          
          SizedBox(height: 16.h),
          
          // Ax = b verification
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science,
                        color: colorScheme.primary,
                        size: 24.w,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'A × X = B',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                          color: colorScheme.primary,
                          fontFamily: GoogleFonts.robotoMono().fontFamily,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  
                  Text(
                    'Verifying that our solution satisfies the original system:',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Solution verification info
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solution Quality:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              widget.result.error != null && widget.result.error! < 1e-8
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: widget.result.error != null && widget.result.error! < 1e-8
                                  ? Colors.green
                                  : Colors.orange,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              widget.result.error != null && widget.result.error! < 1e-8
                                  ? 'Accurate solution (A×X ≈ B)'
                                  : 'Solution has some numerical errors',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: widget.result.error != null && widget.result.error! < 1e-8
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        
                        if (widget.result.error != null) ...[
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: widget.result.error! < 1e-8 
                                   ? Colors.green 
                                   : (widget.result.error! < 1e-4 ? Colors.orange : Colors.red),
                                size: 20.w,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Error: ${_formatNumber(widget.result.error!)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                  color: widget.result.error! < 1e-8 
                                     ? Colors.green 
                                     : (widget.result.error! < 1e-4 ? Colors.orange : Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // Show verification of LC = B and UX = C
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verifying Decomposition Steps',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Step 1: A = LU
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: colorScheme.primary,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Step 1: A = L × U',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'The matrix A is factored into lower triangular L and upper triangular U matrices',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Step 2: LC = B
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: colorScheme.secondary,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Step 2: L × C = B',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'We solve for intermediate vector C using forward substitution',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Step 3: UX = C
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: colorScheme.tertiary,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Step 3: U × X = C',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'We solve for solution vector X using back substitution',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // Info card about verification
          _buildInfoCard(
            colorScheme,
            title: 'About Verification',
            content: 'Verification is essential to ensure the numerical accuracy of the solution. Due to floating-point arithmetic, small errors may accumulate during the decomposition and substitution processes. The error metrics show how close our solution is to the exact mathematical solution.',
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
} 