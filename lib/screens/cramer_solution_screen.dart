import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class CramerSolutionScreen extends StatefulWidget {
  final List<List<double>> coefficients;
  final List<double> constants;
  final List<double> solution;
  final Map<String, double> determinants;
  final List<String> steps;

  const CramerSolutionScreen({
    Key? key,
    required this.coefficients,
    required this.constants,
    required this.solution,
    required this.determinants,
    required this.steps,
  }) : super(key: key);

  @override
  State<CramerSolutionScreen> createState() => _CramerSolutionScreenState();
}

class _CramerSolutionScreenState extends State<CramerSolutionScreen> {
  bool _shouldRound = true;
  bool _disposed = false;
  final int _decimalPlaces = 4;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted && !_disposed) {
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
      formattedNumber = number.toStringAsFixed(_decimalPlaces);
      
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
    if (_disposed) return Container();
    
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : Color(0xFFF8F9FF),
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
        actions: [
          IconButton(
            icon: Icon(_shouldRound 
                ? Icons.calculate_outlined 
                : Icons.calculate,
              color: colorScheme.primary,
            ),
            tooltip: _shouldRound ? 'Showing rounded values' : 'Showing exact values',
            onPressed: () {
              setState(() {
                _shouldRound = !_shouldRound;
              });
            },
          ),
          SizedBox(width: 8),
        ],
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
            // Main content
            ListView(
              padding: EdgeInsets.only(bottom: 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // Main content container
                Container(
                  margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? colorScheme.surface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(
                      color: isDark 
                          ? colorScheme.primary.withOpacity(0.1)
                          : colorScheme.primary.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withOpacity(0.2),
                                    colorScheme.primary.withOpacity(0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.15),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.functions,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SOLUTION SUMMARY',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.primary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Using Cramer\'s Rule with determinants',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // System Determinant
                      _buildSection(
                        title: 'SYSTEM DETERMINANT',
                        content: _buildMainDeterminant(colorScheme, isDark),
                        colorScheme: colorScheme,
                        borderTop: true,
                      ),
                      
                      // Variable Solutions
                      _buildSection(
                        title: 'SOLUTION',
                        content: _buildSolutionVariables(colorScheme, isDark),
                        colorScheme: colorScheme,
                        borderTop: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget content,
    required ColorScheme colorScheme,
    bool borderTop = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: borderTop 
            ? Border(top: BorderSide(color: colorScheme.outline.withOpacity(0.12), width: 1))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary.withOpacity(0.15),
                    colorScheme.secondary.withOpacity(0.08),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.secondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          
          // Section content
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildMainDeterminant(ColorScheme colorScheme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [
                  colorScheme.surfaceVariant.withOpacity(0.4),
                  colorScheme.surfaceVariant.withOpacity(0.3),
                ]
              : [
                  colorScheme.primary.withOpacity(0.12),
                  colorScheme.primary.withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Matrix A and its determinant
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Matrix
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label
                      Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Matrix A',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? colorScheme.primary : colorScheme.primary.withOpacity(0.9),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      
                      // Matrix values
                      Container(
                        decoration: BoxDecoration(
                          color: isDark 
                              ? colorScheme.surface.withOpacity(0.7)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.05),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(8),
                        child: Column(
                          children: [
                            for (int i = 0; i < widget.coefficients.length; i++)
                              Padding(
                                padding: EdgeInsets.only(bottom: i < widget.coefficients.length - 1 ? 4 : 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int j = 0; j < widget.coefficients[i].length; j++)
                                      Container(
                                        width: 44,
                                        padding: EdgeInsets.symmetric(vertical: 4),
                                        margin: EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          _formatNumber(widget.coefficients[i][j]),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: GoogleFonts.firaCode().fontFamily,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
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
                
                // Determinant
                Container(
                  padding: EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'det(A)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatNumber(widget.determinants['D'] ?? 0),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontFamily: GoogleFonts.firaCode().fontFamily,
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
    );
  }

  Widget _buildSolutionVariables(ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        // Final solution values with expanded information
        Container(
          margin: EdgeInsets.only(bottom: 20),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.2),
                colorScheme.tertiary.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Solution header
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'FINAL VALUES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.tertiary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Spacer(),
                    // Solution formula
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'x = ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: GoogleFonts.firaCode().fontFamily,
                              color: colorScheme.secondary,
                            ),
                          ),
                          Text(
                            'det(Aᵢ)/det(A)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500, 
                              fontFamily: GoogleFonts.firaCode().fontFamily,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Solution values row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < widget.solution.length; i++)
                    _buildSolutionValue(
                      'x${i + 1}',
                      widget.solution[i],
                      colorScheme,
                    ),
                ],
              ),
            ],
          ),
        ),

        // Determinant matrices
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      colorScheme.surfaceVariant.withOpacity(0.25),
                      colorScheme.surfaceVariant.withOpacity(0.2),
                    ]
                  : [
                      colorScheme.secondary.withOpacity(0.12),
                      colorScheme.secondary.withOpacity(0.05),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.07),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: colorScheme.secondary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'DETERMINANT CALCULATIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.secondary,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Divider(
                height: 1, 
                thickness: 1, 
                color: colorScheme.outline.withOpacity(0.1),
                indent: 20,
                endIndent: 20,
              ),
              
              // Matrices with replaced columns
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                physics: BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < widget.solution.length; i++) ...[
                      _buildReplacedMatrix(
                        'x${i + 1}',
                        'A${i + 1}',
                        _getReplacedMatrix(i),
                        i,
                        widget.determinants['D${i + 1}'] ?? 0,
                        colorScheme,
                        isDark,
                      ),
                      if (i < widget.solution.length - 1)
                        SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildReplacedMatrix(
    String varName,
    String matrixName,
    List<List<double>> matrix,
    int replacedColumn,
    double determinant,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 4,
            offset: Offset(0, 2),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.25),
                  colorScheme.primary.withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'For $varName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  matrixName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: GoogleFonts.firaCode().fontFamily,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Matrix content
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                for (int i = 0; i < matrix.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i < matrix.length - 1 ? 4 : 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int j = 0; j < matrix[i].length; j++)
                          Container(
                            width: 44,
                            padding: EdgeInsets.symmetric(vertical: 4),
                            margin: EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: replacedColumn == j
                                  ? colorScheme.tertiary.withOpacity(0.25)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                              border: replacedColumn == j
                                  ? Border.all(
                                      color: colorScheme.tertiary.withOpacity(0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Text(
                              _formatNumber(matrix[i][j]),
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: GoogleFonts.firaCode().fontFamily,
                                fontWeight: FontWeight.w500,
                                color: replacedColumn == j
                                    ? colorScheme.tertiary
                                    : colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Determinant
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.surfaceVariant.withOpacity(0.5),
                  colorScheme.surfaceVariant.withOpacity(0.3),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(9),
                bottomRight: Radius.circular(9),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'det($matrixName)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: GoogleFonts.firaCode().fontFamily,
                    color: colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatNumber(determinant),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.firaCode().fontFamily,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSolutionValue(String name, double value, ColorScheme colorScheme) {
    return Container(
      width: 90,
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: name == 'x1' 
              ? [
                  Color(0xFFE1EFFF),
                  Color(0xFFD6E8FF),
                ]
              : name == 'x2'
                  ? [
                      Color(0xFFE6E0FF),
                      Color(0xFFDDD5FF),
                    ]
                  : [
                      Color(0xFFFFE0D6),
                      Color(0xFFFFD5C8),
                    ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: name == 'x1'
                ? colorScheme.primary.withOpacity(0.2)
                : name == 'x2' 
                    ? colorScheme.secondary.withOpacity(0.2)
                    : colorScheme.tertiary.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 3),
            spreadRadius: 0.5,
          ),
        ],
        border: Border.all(
          color: name == 'x1'
              ? colorScheme.primary.withOpacity(0.2)
              : name == 'x2'
                  ? colorScheme.secondary.withOpacity(0.2)
                  : colorScheme.tertiary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 3,
            margin: EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: name == 'x1'
                  ? colorScheme.primary
                  : name == 'x2'
                      ? colorScheme.secondary
                      : colorScheme.tertiary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: name == 'x1'
                  ? Color(0xFF0D47A1)
                  : name == 'x2'
                      ? Color(0xFF4A148C)
                      : Color(0xFFBF360C),
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: name == 'x1'
                  ? colorScheme.primary.withOpacity(0.12)
                  : name == 'x2'
                      ? colorScheme.secondary.withOpacity(0.12)
                      : colorScheme.tertiary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: name == 'x1'
                    ? colorScheme.primary.withOpacity(0.2)
                    : name == 'x2'
                        ? colorScheme.secondary.withOpacity(0.2)
                        : colorScheme.tertiary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              _formatNumber(value),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                fontFamily: GoogleFonts.firaCode().fontFamily,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get a matrix with column replaced by constants vector
  List<List<double>> _getReplacedMatrix(int colIndex) {
    List<List<double>> result = List.generate(
      widget.coefficients.length,
      (i) => List.from(widget.coefficients[i]),
    );
    
    for (int i = 0; i < widget.coefficients.length; i++) {
      result[i][colIndex] = widget.constants[i];
    }
    
    return result;
  }

  String _buildEquationString(int row) {
    StringBuffer equation = StringBuffer();
    
    for (int j = 0; j < widget.coefficients[row].length; j++) {
      double coefficient = widget.coefficients[row][j];
      if (j > 0) {
        equation.write(coefficient >= 0 ? ' + ' : ' - ');
        equation.write('${coefficient.abs().toStringAsFixed(2)}x${j + 1}');
      } else {
        equation.write('${coefficient.toStringAsFixed(2)}x${j + 1}');
      }
    }
    
    equation.write(' = ${widget.constants[row].toStringAsFixed(2)}');
    return equation.toString();
  }
} 