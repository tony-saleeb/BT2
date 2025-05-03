// ignore_for_file: unused_element, unnecessary_to_list_in_spreads, prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numerical/models/secant_method.dart';
import 'package:numerical/screens/secant_solution_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

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

// Add the superscript map at the top level to make it accessible to all helper methods
final Map<String, String> _superscriptMap = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
};

class SecantMethodScreen extends StatefulWidget {
  const SecantMethodScreen({super.key});

  @override
  State<SecantMethodScreen> createState() => _SecantMethodScreenState();
}

class _SecantMethodScreenState extends State<SecantMethodScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  var _functionController = TextEditingController();
  final _x0Controller = TextEditingController();  // First initial guess (x-1)
  final _x1Controller = TextEditingController();  // Second initial guess (x0)
  final _errorController = TextEditingController();
  final _iterationsController = TextEditingController();
  final _coefficientController = TextEditingController();
  final _powerController = TextEditingController();
  final _constantController = TextEditingController();
  
  bool _useError = true;
  bool _isVariableMode = true;
  bool _isValidInitialPoints = false;
  int _decimalPlaces = 3;
  List<Map<String, dynamic>> _terms = [];

  late final AnimationController _headerAnimationController;
  late final AnimationController _variableTermAnimationController;
  late final AnimationController _constantTermAnimationController;

  String _convertToSuperscript(String number) {
    // Convert each digit to its superscript equivalent
    String result = '';
    for (int i = 0; i < number.length; i++) {
      final digit = number[i];
      result += _superscriptMap[digit] ?? digit;
    }
    return result;
  }

  String? _selectedTrigType;

  // Add these line with other class variables
  late final ValueNotifier<List<Map<String, dynamic>>> _historyNotifier;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    _variableTermAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _constantTermAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _historyNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
    
    _initializeControllers();
    
    // Add listeners to validate initial points whenever text changes
    _x0Controller.addListener(_validateInitialPoints);
    _x1Controller.addListener(_validateInitialPoints);
    
    // Load history when initializing
    _loadHistory();
  }

  void _initializeControllers() {
    _functionController = TextEditingController();
    _x0Controller.clear();
    _x1Controller.clear();
    _errorController.clear();
    _iterationsController.clear();
    _coefficientController.clear();
    _powerController.clear();
    _constantController.clear();
  }



  @override
  void dispose() {
    _headerAnimationController.dispose();
    _variableTermAnimationController.dispose();
    _constantTermAnimationController.dispose();
    _functionController.dispose();
    
    // Remove listeners before disposing
    _x0Controller.removeListener(_validateInitialPoints);
    _x1Controller.removeListener(_validateInitialPoints);
    
    _x0Controller.dispose();
    _x1Controller.dispose();
    _errorController.dispose();
    _iterationsController.dispose();
    _coefficientController.dispose();
    _powerController.dispose();
    _constantController.dispose();
    _historyNotifier.dispose();
    super.dispose();
  }

  void _clearFields() {
    setState(() {
      _functionController.clear();
      _x0Controller.clear();
      _x1Controller.clear();
      _errorController.clear();
      _iterationsController.clear();
      _coefficientController.clear();
      _powerController.clear();
      _constantController.clear();
      _terms.clear();
      _isValidInitialPoints = false;
    });
  }

  void _addTerm() {
    if (_coefficientController.text.isEmpty || _powerController.text.isEmpty) {
      return;
    }
    
    double coefficient = double.tryParse(_coefficientController.text) ?? 0;
    int power = int.tryParse(_powerController.text) ?? 0;
    
    setState(() {
      _terms.add({
        'coefficient': coefficient,
        'power': power,
        'isVariable': true,
        'trigType': _selectedTrigType,
      });
      
      _coefficientController.clear();
      _powerController.clear();
      _selectedTrigType = null;
      
      _updateFunctionText();
    });
  }

  void _addConstant() {
    if (_constantController.text.isEmpty) {
      return;
    }
    
    double constant = double.tryParse(_constantController.text) ?? 0;
    
    setState(() {
      _terms.add({
        'coefficient': constant,
        'power': 0,
        'isVariable': false,
      });
      
      _constantController.clear();
      
      _updateFunctionText();
    });
  }

  void _updateFunctionText() {
    List<String> termStrings = [];
    
    for (var term in _terms) {
      String termStr = '';
      double coefficient = term['coefficient'] ?? 0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;
      String? trigType = term['trigType'] as String?;
      
      if (trigType != null) {
        String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
        double absCoef = coefficient.abs();
        String coefStr = absCoef == 1 ? '' : '${absCoef.toString()} ';
        String powerStr = power != 1 ? '(${power}x)' : 'x';
        termStr = '$sign$coefStr$trigType$powerStr';
      } else if (isVariable) {
        if (coefficient == 0) {
          continue;
        }
        
        String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
        double absCoef = coefficient.abs();
        String coefStr = absCoef == 1 && power > 0 ? '' : '${absCoef.toString()} ';
        
        if (power == 0) {
          termStr = '$sign$absCoef';
        } else if (power == 1) {
          termStr = '$sign${coefStr}x';
        } else {
          // Use superscript for the power
          String superscriptPower = _convertToSuperscript(power.toString());
          termStr = '$sign${coefStr}x$superscriptPower';
        }
      } else {
        if (coefficient == 0) {
          continue;
        }
        
        String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
        double absCoef = coefficient.abs();
        termStr = '$sign${absCoef == absCoef.toInt() ? absCoef.toInt() : absCoef}';
      }
      
      termStrings.add(termStr);
    }
    
    _functionController.text = termStrings.join(' ');
  }

  void _removeTerm(int index) {
    setState(() {
      _terms.removeAt(index);
      _updateFunctionText();
    });
  }

  void _calculateAndNavigate() {
    // Check if we have a function defined
    if (_terms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please define a function first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Validate the inputs first
    _validateInitialPoints();
    
    if (!_formKey.currentState!.validate()) {
      return;  // Don't proceed if validation fails
    }
    
    // Check if the initial points are the same
    try {
      final x0 = double.parse(_x0Controller.text);
      final x1 = double.parse(_x1Controller.text);
      
      if (x0 == x1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Initial points must be different from each other'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    } catch (e) {
      // Handle parsing errors (should be caught by validation)
      return;
    }
    
    if (!_isValidInitialPoints) {
      // Show a warning for potentially invalid initial points, but allow continuing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('These points may not be suitable for finding a root. Continue anyway?'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'CONTINUE',
            textColor: Colors.white,
            onPressed: () {
              // Continue with calculation despite the warning
              _performCalculation();
            },
          ),
        ),
      );
      return;
    }
    
    // Proceed with calculation
    _performCalculation();
  }

  void _performCalculation() {
      try {
        // Get the values
        final x0 = double.parse(_x0Controller.text);
        final x1 = double.parse(_x1Controller.text);
        
        // Get stopping condition
        final error = _useError 
            ? double.parse(_errorController.text)
            : 0.001; // Default error
        
        final maxIterations = _useError 
            ? 50 // Default max iterations
            : int.parse(_iterationsController.text);

        // Create SecantMethod instance and calculate
        final secantMethod = SecantMethod(_terms, decimalPlaces: _decimalPlaces);
        
        final results = secantMethod.solve(
          x0: x0,
          x1: x1,
          es: error,
          maxi: maxIterations,
        );

        // Add this line to save to history
        _saveToHistory();

        // Navigate to solution screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecantSolutionScreen(
            results: results.map((result) => {
              'iteration': result.iteration,
              'xi_minus1': result.xi_minus1,
              'fxi_minus1': result.fxi_minus1,
              'xi': result.xi,
              'fxi': result.fxi,
              'xi_plus1': result.xi_plus1,
              'fxi_plus1': result.fxi_plus1,
              'ea': result.ea,
              'isRoot': result.isRoot,
              'debugSteps': result.debugSteps,
            }).toList(),
              function: _functionController.text,
            xMinus1: x0,
            x0: x1,
              es: error,
              maxIterations: maxIterations,
              useError: _useError,
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
            content: Text(
              e.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
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
                            colorScheme.primary.withOpacity(0.1),
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
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Craft your function visually',
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
                    
                    // Scrollable content area
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
                                    : colorScheme.primary.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: dialogTerms.isEmpty 
                                      ? colorScheme.outline.withOpacity(0.2)
                                      : colorScheme.tertiary.withOpacity(0.4),
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
                                              colorScheme.primary.withOpacity(0.04),
                                              colorScheme.secondary.withOpacity(0.02),
                                            ])
                                      : (isDark
                                          ? [
                                              colorScheme.tertiary.withOpacity(0.1),
                                              colorScheme.primary.withOpacity(0.08),
                                            ]
                                          : [
                                              colorScheme.tertiary.withOpacity(0.08),
                                              colorScheme.secondary.withOpacity(0.05),
                                            ]),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: dialogTerms.isEmpty
                                        ? colorScheme.shadow.withOpacity(0.1)
                                        : colorScheme.tertiary.withOpacity(0.2),
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
                                            color: colorScheme.primary.withOpacity(0.2),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Add terms to see function graph',
                                            style: TextStyle(
                                              color: colorScheme.primary.withOpacity(0.5),
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
                                          color: colorScheme.primary.withOpacity(0.5),
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
                                          'f(x) = ',
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
                                      color: colorScheme.primary.withOpacity(0.5),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
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
                              margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                                  // Variable term builder content
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
                                    child: AnimatedBuilder(
                                      animation: _variableTermAnimationController,
                                      builder: (context, child) {
                                        // Calculate the animation color
                                        final Color buttonColor = ColorTween(
                                          begin: colorScheme.secondary,
                                          end: Colors.green,
                                        ).evaluate(_variableTermAnimationController)!;
                                        
                                        // Calculate scale for emoji animation
                                        final double emojiScale = _variableTermAnimationController.value;
                                        
                                        return FilledButton.icon(
                                          onPressed: () {
                                            if (_coefficientController.text.isNotEmpty && _powerController.text.isNotEmpty) {
                                              setState(() {
                                                dialogTerms.add({
                                                  'coefficient': double.parse(_coefficientController.text),
                                                  'power': int.parse(_powerController.text),
                                                  'isVariable': true,
                                                });
                                                });
                                                _coefficientController.clear();
                                                _powerController.clear();
                                              showSuccessAnimation(_variableTermAnimationController);
                                            }
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: buttonColor,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          icon: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(Icons.add_rounded, size: 20),
                                              // Emoji animation
                                              if (_variableTermAnimationController.value > 0)
                                                Positioned(
                                                  right: -5,
                                                  top: -8,
                                                  child: Transform.scale(
                                                    scale: emojiScale,
                                                    child: const Text(
                                                      '✅',
                                                      style: TextStyle(fontSize: 14),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          label: const Text(
                                            'ADD TERM',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        );
                                      }
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                            
                            // Constant Term Builder
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
                                  // Constant term builder content
                                  Text(
                                    'ADD CONSTANT',
                                    style: TextStyle(
                                      color: colorScheme.secondary.withOpacity(0.7),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
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
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: AnimatedBuilder(
                                      animation: _constantTermAnimationController,
                                      builder: (context, child) {
                                        // Calculate the animation color
                                        final Color buttonColor = ColorTween(
                                          begin: colorScheme.secondary,
                                          end: Colors.green,
                                        ).evaluate(_constantTermAnimationController)!;
                                        
                                        // Calculate scale for emoji animation
                                        final double emojiScale = _constantTermAnimationController.value;
                                        
                                        return FilledButton.icon(
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
                                              showSuccessAnimation(_constantTermAnimationController);
                                            }
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: buttonColor,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          icon: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(Icons.add_rounded, size: 20),
                                              // Emoji animation
                                              if (_constantTermAnimationController.value > 0)
                                                Positioned(
                                                  right: -5,
                                                  top: -8,
                                                  child: Transform.scale(
                                                    scale: emojiScale,
                                                    child: const Text(
                                                      '✅',
                                                      style: TextStyle(fontSize: 14),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          label: const Text(
                                            'ADD CONSTANT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        );
                                      }
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Terms List
                            if (dialogTerms.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                  'CURRENT TERMS',
                                  style: TextStyle(
                                        color: colorScheme.primary.withOpacity(0.5),
                                    fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                    fontSize: 12,
                                  ),
                                ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: dialogTerms.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final term = entry.value;
                                        return _buildTermTile(
                                          term: term,
                                          onDelete: () {
                                      setState(() {
                                        dialogTerms.removeAt(index);
                                      });
                                    },
                                          colorScheme: colorScheme,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer
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

  String _formatPolynomial(List<Map<String, dynamic>> terms) {
    List<String> termStrings = [];
    
    for (var term in terms) {
      String termStr = '';
      double coefficient = term['coefficient'] ?? 0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;
      String? trigType = term['trigType'] as String?;
      
      if (trigType != null) {
        String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
        double absCoef = coefficient.abs();
        String coefStr = absCoef == 1 ? '' : '${absCoef.toString()} ';
        String powerStr = power != 1 ? '(${power}x)' : 'x';
        termStr = '$sign$coefStr$trigType$powerStr';
      } else if (isVariable) {
        if (coefficient == 0) {
          continue;
        }
        
        String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
        double absCoef = coefficient.abs();
        String coefStr = absCoef == 1 && power > 0 ? '' : '${absCoef.toString()} ';
        
        if (power == 0) {
          termStr = '$sign${absCoef == absCoef.toInt() ? absCoef.toInt() : absCoef}';
        } else if (power == 1) {
          termStr = '$sign${coefStr}x';
        } else {
          // Use superscript for the power
          String superscriptPower = _convertToSuperscript(power.toString());
          termStr = '$sign${coefStr}x$superscriptPower';
        }
      } else {
        if (coefficient == 0) {
          continue;
        }
        
        String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
        double absCoef = coefficient.abs();
        termStr = '$sign${absCoef == absCoef.toInt() ? absCoef.toInt() : absCoef}';
      }
      
      termStrings.add(termStr);
    }
    
    return termStrings.isEmpty ? '0' : termStrings.join(' ');
  }

  Widget _buildAddTermSection(ColorScheme colorScheme, StateSetter setState, List<Map<String, dynamic>> terms) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD TERMS',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          // Tabs for variable vs constant
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  isSelected: _isVariableMode,
                  label: 'VARIABLE TERM',
                  icon: Icons.functions,
                  colorScheme: colorScheme,
                  onTap: () {
                    setState(() {
                      _isVariableMode = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleButton(
                  isSelected: !_isVariableMode,
                  label: 'CONSTANT',
                  icon: Icons.tag,
                  colorScheme: colorScheme,
                  onTap: () {
                    setState(() {
                      _isVariableMode = false;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Variable term form
          if (_isVariableMode) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _coefficientController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: 'Coefficient',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _powerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Power',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_coefficientController.text.isNotEmpty && _powerController.text.isNotEmpty) {
                    double coefficient = double.tryParse(_coefficientController.text) ?? 0;
                    int power = int.tryParse(_powerController.text) ?? 0;
                    
                    setState(() {
                      terms.add({
                        'coefficient': coefficient,
                        'power': power,
                        'isVariable': true,
                        'trigType': _selectedTrigType,
                      });
                      
                      _coefficientController.clear();
                      _powerController.clear();
                      _selectedTrigType = null;
                    });
                  }
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('ADD VARIABLE TERM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Constant term form
            TextFormField(
              controller: _constantController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Constant',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_constantController.text.isNotEmpty) {
                    double constant = double.tryParse(_constantController.text) ?? 0;
                    
                    setState(() {
                      terms.add({
                        'coefficient': constant,
                        'power': 0,
                        'isVariable': false,
                      });
                      
                      _constantController.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('ADD CONSTANT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required bool isSelected, 
    required String label, 
    required IconData icon,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected 
                    ? colorScheme.primary
                    : colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? colorScheme.primary
                      : colorScheme.primary.withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsList(ColorScheme colorScheme, StateSetter setState, List<Map<String, dynamic>> terms) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT TERMS',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...terms.asMap().entries.map((entry) {
            final index = entry.key;
            final term = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatSingleTerm(term),
                        style: TextStyle(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
                      onPressed: () {
                        setState(() {
                          terms.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatSingleTerm(Map<String, dynamic> term) {
    double coefficient = term['coefficient'] ?? 0;
    int power = term['power'] ?? 0;
    bool isVariable = term['isVariable'] ?? false;
    String? trigType = term['trigType'] as String?;
    
    // Format coefficient to remove decimal point for integer values
    String formatCoefficient(double value) {
      if (value == value.round().toDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    
    if (trigType != null) {
      String coefStr = coefficient == 1 ? '' : formatCoefficient(coefficient) + ' ';
      String powerStr = power != 1 ? '(${power}x)' : 'x';
      return '$coefStr$trigType$powerStr';
    } else if (isVariable) {
      if (coefficient == 0) {
        return '0';
      } else if (power == 0) {
        return formatCoefficient(coefficient);
      } else if (power == 1) {
        return '${formatCoefficient(coefficient)}x';
      } else {
        String superscriptPower = _convertToSuperscript(power.toString());
        return '${formatCoefficient(coefficient)}x$superscriptPower';
      }
    } else {
      return formatCoefficient(coefficient);
    }
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
        child: Column(
          children: [
            // Top content including header and scrollable content
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom App Bar with animated header
                    _buildHeader(context),
                    // Main Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Form(
                          key: _formKey,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Column(
                              children: [
                                _buildStepCard(
                                  step: 1,
                                  title: 'Define Function',
                                  subtitle: 'Enter your polynomial function',
                                  icon: Icons.functions_rounded,
                                  colorScheme: colorScheme,
                                  isExpanded: true,
                                  content: _buildFunctionSection(context),
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
                                  title: 'Initial Points',
                                  subtitle: 'Define the initial points [x-1, x₀]',
                                  icon: Icons.circle_outlined,
                                  colorScheme: colorScheme,
                                  isExpanded: _functionController.text.isNotEmpty,
                                  content: _buildInitialValuesSection(context),
                                ),
                                _buildStepCard(
                                  step: 3,
                                  title: 'Stopping Criteria',
                                  subtitle: 'Choose when to stop iterations',
                                  icon: Icons.stop_circle_outlined,
                                  colorScheme: colorScheme,
                                  isExpanded: _isValidInitialPoints && _x0Controller.text.isNotEmpty && _x1Controller.text.isNotEmpty,
                                  content: _buildStoppingCriteriaSection(context),
                                ),
                                const SizedBox(height: 24),
                                _buildNumberFormatSettings(context),
                                SizedBox(height: 5.h), // Fixed bottom padding to prevent content from being hidden
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fixed bottom action bar
            SafeArea(
              top: false,
              child: Container(
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
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _clearFields,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: colorScheme.primary,
                        size: 20.w,
                      ),
                      label: Text(
                        'RESET',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        foregroundColor: colorScheme.primary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.tertiary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 20.r,
                              offset: Offset(0, 8.h),
                              spreadRadius: -4.r,
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _calculateAndNavigate,
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20.w,
                          ),
                          label: Text(
                            'CALCULATE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 16.h,
                            ),
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedBuilder(
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
                            'SECANT METHOD',
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
                          title: 'Set Initial Points',
                          description: 'Enter two initial points (x₀ and x₁) that will be used to start the iteration process.',
                          icon: Icons.circle_outlined,
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
                          title: 'Adjust Decimal Precision',
                          description: 'Use the slider to set the number of decimal places for the calculations and results.',
                          icon: Icons.pin_rounded,
                          colorScheme: colorScheme,
                        ),
                        _buildTutorialStep(
                          step: 5,
                          title: 'Calculate',
                          description: 'Press the Calculate button to find the root using the Secant Method.',
                          icon: Icons.play_arrow_rounded,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 16),
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

  Widget _buildFunctionSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
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
                        const TextSpan(text: 'f(x) = '),
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

  Widget _buildInitialValuesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bothFieldsHaveValues = _x0Controller.text.isNotEmpty && _x1Controller.text.isNotEmpty;
    final functionDefined = _terms.isNotEmpty;
    
    // Different validation states
    bool samePoints = false;
    bool noFunction = !functionDefined;
    
    // Try to compute whether the points are the same
    if (bothFieldsHaveValues) {
      try {
        final x0 = double.parse(_x0Controller.text);
        final x1 = double.parse(_x1Controller.text);
        samePoints = x0 == x1;
      } catch (e) {
        // Ignore parsing errors
      }
    }
    
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _x0Controller,
                  hint: 'First point',
                  prefix: 'x-1 =',
                  colorScheme: colorScheme,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-+]?([0-9]*[.])?[0-9]+')),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildInputField(
                  controller: _x1Controller,
                  hint: 'Second point',
                  prefix: 'x0 =',
                  colorScheme: colorScheme,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-+]?([0-9]*[.])?[0-9]+')),
                  ],
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      // Trigger update to show the stopping criteria section
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
          if (noFunction && bothFieldsHaveValues)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Define a function before validating points',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          if (samePoints && bothFieldsHaveValues)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colorScheme.error,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Initial points must be different values',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          if (bothFieldsHaveValues && functionDefined && !samePoints && !_isValidInitialPoints)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'These points may not be suitable for finding a root. Try values that bracket a root.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (bothFieldsHaveValues && functionDefined && _isValidInitialPoints)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Valid initial points for this function',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoppingCriteriaSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
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
            prefix: _useError ? 'es =' : 'n =',
            colorScheme: colorScheme,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(_useError 
                  ? RegExp(r'[0-9]*\.?[0-9]*') 
                  : RegExp(r'[0-9]+')),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefix,
    void Function(String)? onChanged,
  }) {
    final isInitialPointsField = (controller == _x0Controller || controller == _x1Controller);
    final showValidationIndicator = isInitialPointsField && controller.text.isNotEmpty;
    
    // Need to check for same points separately from general validation issues
    bool hasSamePointsError = false;
    bool hasValidationWarning = false;
    
    if (isInitialPointsField && _x0Controller.text.isNotEmpty && _x1Controller.text.isNotEmpty) {
      try {
        final x0 = double.parse(_x0Controller.text);
        final x1 = double.parse(_x1Controller.text);
        hasSamePointsError = x0 == x1;
        
        // If points are different but initial points are not considered valid
        hasValidationWarning = !hasSamePointsError && !_isValidInitialPoints && _terms.isNotEmpty;
      } catch (e) {
        // Parsing error will be caught by validator
      }
    }
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (value) {
        if (onChanged != null) {
          onChanged(value);
        }
        if (isInitialPointsField) {
          _validateInitialPoints();
          setState(() {}); // Ensure UI updates
        }
      },
      style: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w500,
        fontSize: 16.sp,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix != null ? '$prefix ' : null,
        prefixStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
          fontSize: 16.sp,
        ),
        hintStyle: TextStyle(
          color: colorScheme.primary.withOpacity(0.5),
          fontWeight: FontWeight.w400,
          fontSize: 16.sp,
        ),
        filled: true,
        fillColor: colorScheme.surface,
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontSize: 12.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: hasSamePointsError
                ? colorScheme.error.withOpacity(0.5)
                : hasValidationWarning
                    ? Colors.orange.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: hasSamePointsError
                ? colorScheme.error
                : hasValidationWarning
                    ? Colors.orange
                    : colorScheme.secondary,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        suffixIcon: showValidationIndicator
            ? Icon(
                _isValidInitialPoints 
                    ? Icons.check_circle 
                    : hasValidationWarning 
                        ? Icons.warning_amber_rounded
                        : Icons.error,
                color: _isValidInitialPoints 
                    ? Colors.green 
                    : hasValidationWarning
                        ? Colors.orange
                        : colorScheme.error,
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        if (hasSamePointsError) {
          return 'Initial points must be different';
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _useError = value;
          });
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: value == groupValue
                  ? colorScheme.secondary
                  : colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              if (value == groupValue)
                BoxShadow(
                  color: colorScheme.secondary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == groupValue
                        ? colorScheme.secondary
                        : colorScheme.outline.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: value == groupValue
                      ? Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.secondary,
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: value == groupValue
                      ? colorScheme.primary
                      : colorScheme.primary.withOpacity(0.7),
                  fontWeight: value == groupValue
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberFormatSettings(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
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
                const SizedBox(width: 16),
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
      ),
    );
  }

  String _formatExampleNumber() {
    return (3.14159265359).toStringAsFixed(_decimalPlaces);
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
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    step.toString(),
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
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
              crossFadeState: isExpanded 
                  ? CrossFadeState.showFirst 
                  : CrossFadeState.showSecond,
              firstChild: content,
              secondChild: const SizedBox(height: 0),
            ),
          ),
        ],
      ),
    );
  }

  void _validateInitialPoints() {
    final hasX0 = _x0Controller.text.isNotEmpty;
    final hasX1 = _x1Controller.text.isNotEmpty;
    
    // First set valid to false by default
    if (_isValidInitialPoints) {
      setState(() {
        _isValidInitialPoints = false;
      });
    }
    
    // If both fields don't have values, we can't validate
    if (!hasX0 || !hasX1) {
      debugPrint('Initial Points Validation: incomplete - x0=$hasX0, x1=$hasX1');
      return;
    }
    
    // Try to parse the values
    double x0Value, x1Value;
    try {
      x0Value = double.parse(_x0Controller.text);
      x1Value = double.parse(_x1Controller.text);
    } catch (e) {
      debugPrint('Initial Points Validation: error - ${e.toString()}');
      return;
    }
    
    // Check if points are different (basic validation)
    final areDifferent = (x0Value != x1Value);
    
    if (!areDifferent) {
      debugPrint('Initial Points Validation: Invalid - points are the same');
      return;
    }
    
    // If we don't have a function defined, we can't fully validate
    if (_terms.isEmpty) {
      debugPrint('Initial Points Validation: function not defined');
      return;
    }
    
    try {
      // Create a temporary SecantMethod to evaluate function values
      final tempMethod = SecantMethod(_terms, decimalPlaces: _decimalPlaces);
      
      // Get function values at initial points
      final fx0 = tempMethod.f(x0Value);
      final fx1 = tempMethod.f(x1Value);
      
      // Check if function values have opposite signs (which is ideal for secant method)
      final haveOppositeSigns = fx0 * fx1 <= 0;
      
      // Check if points are reasonably close to each other (within a factor)
      final areReasonablyClose = (x1Value - x0Value).abs() < 100;  // arbitrary threshold
      
      // Consider points valid if they have opposite signs or are close enough
      final isValid = areDifferent && (haveOppositeSigns || areReasonablyClose);
      
      setState(() {
        _isValidInitialPoints = isValid;
      });
      
      debugPrint('Initial Points Validation: x0=$x0Value (f(x0)=$fx0), x1=$x1Value (f(x1)=$fx1), valid=$_isValidInitialPoints');
      debugPrint('Initial Points have opposite signs: $haveOppositeSigns, are close enough: $areReasonablyClose');
    } catch (e) {
      debugPrint('Initial Points Validation: error evaluating function - ${e.toString()}');
      return;
    }
  }

  // Add these history-related methods before the _calculateAndNavigate method

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('secant_method_history');
      
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
      
      await prefs.setString('secant_method_history', json.encode(historyToSave));
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  void _saveToHistory() {
    if (_functionController.text.isNotEmpty && _x0Controller.text.isNotEmpty && _x1Controller.text.isNotEmpty) {
      final historyItem = {
        'function': _functionController.text,
        'terms': List.from(_terms),
        'x0': _x0Controller.text,
        'x1': _x1Controller.text,
        'error': _errorController.text,
        'iterations': _iterationsController.text,
        'useError': _useError,
        'timestamp': DateTime.now(),
      };
      
      // Remove any older entries with the same function and initial points
      final newHistory = _historyNotifier.value.where((item) =>
        !(item['function'] == historyItem['function'] && 
          item['x0'] == historyItem['x0'] &&
          item['x1'] == historyItem['x1'])
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

  void _loadFromHistory(Map<String, dynamic> historyItem) {
    setState(() {
      _functionController.text = historyItem['function'];
      _terms = List.from(historyItem['terms']);
      _x0Controller.text = historyItem['x0'];
      _x1Controller.text = historyItem['x1'];
      _errorController.text = historyItem['error'];
      _iterationsController.text = historyItem['iterations'];
      _useError = historyItem['useError'];
    });
    
    // Validate initial points after loading
    _validateInitialPoints();
    
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
                          color: colorScheme.primary.withOpacity(0.7),
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
                                        'Calculations you perform will be saved here for easy access. Find roots efficiently with the Secant Method.',
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
                                                              'f(x) = ${item['function']}',
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
                                              'f(x) = ${item['function']}',
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Initial Points: [${item['x0']}, ${item['x1']}]',
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

  Widget _buildHistoryChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final paint = Paint()
      ..color = isDark
          ? colorScheme.primary.withOpacity(0.05 * animationValue)
          : colorScheme.primary.withOpacity(0.03 * animationValue)
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridBackgroundPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
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
    final paint = Paint()
      ..color = colorScheme.secondary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;

    // Scale and translate coordinates to fit the view
    const scale = 20.0;
    final translateX = size.width / 2;
    final translateY = size.height / 2;

    // Plot points
    for (double x = -size.width / (2 * scale); x <= size.width / (2 * scale); x += 0.1) {
      double y = 0;
      
      // Calculate y value based on terms
      for (final term in terms) {
        final coefficient = term['coefficient'] as double;
        final power = term['power'] as int;
        final isVariable = term['isVariable'] as bool;
        
        if (isVariable) {
          y += coefficient * pow(x, power);
        } else {
          y += coefficient;
        }
      }

      // Transform coordinates to screen space
      final screenX = x * scale + translateX;
      final screenY = -y * scale + translateY;

      if (!started) {
        path.moveTo(screenX, screenY);
        started = true;
      } else {
        path.lineTo(screenX, screenY);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FunctionGraphPainter oldDelegate) =>
      !listEquals(oldDelegate.terms, terms);
} 

// Add back missing helper methods

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

Widget _buildTermTile({
  required Map<String, dynamic> term,
  required VoidCallback onDelete,
  required ColorScheme colorScheme,
}) {
  final coefficient = term['coefficient'] as double;
  final power = term['power'] as int;
  final isVariable = term['isVariable'] ?? false;
  
  String termText = '';
  if (coefficient != 0) {
    if (coefficient == -1 && isVariable) {
      termText += '-';
    } else if (coefficient != 1 || !isVariable) {
      if (coefficient % 1 == 0) {
        termText += coefficient.toInt().toString();
      } else {
        termText += coefficient.toString();
      }
    }
  }
  
  if (isVariable) {
    termText += 'x';
    if (power != 1) {
      // Use superscript for exponents when displaying
      String powerText = power.toString();
      String superscript = '';
      for (int i = 0; i < powerText.length; i++) {
        superscript += _superscriptMap[powerText[i]] ?? powerText[i];
      }
      termText += superscript;
    }
  }
  
  return TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 400),
    tween: Tween<double>(begin: 0.7, end: 1.0),
    curve: Curves.elasticOut,
    builder: (context, value, child) {
      return Transform.scale(
        scale: value,
        child: child,
      );
    },
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isVariable 
                ? colorScheme.secondary.withOpacity(0.2) 
                : colorScheme.primary.withOpacity(0.2),
            isVariable 
                ? colorScheme.tertiary.withOpacity(0.1) 
                : colorScheme.secondary.withOpacity(0.1),
          ],
          stops: const [0.3, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVariable
              ? colorScheme.secondary.withOpacity(0.3)
              : colorScheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: (isVariable ? colorScheme.secondary : colorScheme.primary).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onDelete,
          splashColor: colorScheme.error.withOpacity(0.1),
          highlightColor: colorScheme.error.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  termText,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _buildFunctionStringFromTerms(List<Map<String, dynamic>> terms) {
  if (terms.isEmpty) return '0';

  List<String> termStrings = [];
  
  for (var term in terms) {
    String termStr = '';
    double coefficient = term['coefficient'] ?? 0;
    int power = term['power'] ?? 0;
    bool isVariable = term['isVariable'] ?? false;
    String? trigType = term['trigType'] as String?;
    
    if (coefficient == 0) continue;
    
    String sign = coefficient < 0 ? '-' : (termStrings.isNotEmpty ? '+ ' : '');
    double absCoef = coefficient.abs();
    
    // Format the coefficient: show integer values without decimal point
    String coefStr = '';
    if (absCoef == (absCoef.round()).toDouble()) {
      // Integer value
      coefStr = absCoef.toInt().toString();
    } else {
      // Decimal value
      coefStr = absCoef.toString();
    }
    
    if (trigType != null) {
      // Handle trigonometric functions
      String formattedCoef = absCoef == 1 ? '' : '$coefStr ';
      String powerStr = power != 1 ? '(${power}x)' : 'x';
      termStr = '$sign$formattedCoef$trigType$powerStr';
    } else if (isVariable) {
      // For coefficient of 1, don't show the coefficient if there's a variable with power > 0
      String formattedCoef = absCoef == 1 && power > 0 ? '' : '$coefStr ';
      
      if (power == 0) {
        termStr = '$sign$coefStr';
      } else if (power == 1) {
        termStr = '$sign${formattedCoef}x';
      } else {
        // Use powerToString helper method for superscript conversion
        String superscriptPower = '';
        // Convert each digit to its superscript equivalent
        String powerStr = power.toString();
        for (int i = 0; i < powerStr.length; i++) {
          final digit = powerStr[i];
          superscriptPower += _superscriptMap[digit] ?? digit;
        }
        termStr = '$sign${formattedCoef}x$superscriptPower';
      }
    } else {
      termStr = '$sign$coefStr';
    }
    
    termStrings.add(termStr);
  }
  
  return termStrings.join(' ');
}

void showSuccessAnimation(AnimationController controller) {
  controller.forward().then((_) {
    Future.delayed(const Duration(milliseconds: 800), () {
      controller.reverse();
    });
  });
} 

// Add this helper method for building tip items
Widget _buildTipItem(ColorScheme colorScheme, String number, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          number,
          style: TextStyle(
            color: colorScheme.primary.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
} 