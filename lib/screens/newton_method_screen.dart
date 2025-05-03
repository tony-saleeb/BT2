import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numerical/models/newton_method.dart';
import 'package:numerical/screens/newton_solution_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

class NewtonMethodScreen extends StatefulWidget {
  const NewtonMethodScreen({super.key});

  @override
  State<NewtonMethodScreen> createState() => _NewtonMethodScreenState();
}

class _NewtonMethodScreenState extends State<NewtonMethodScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  var _functionController = TextEditingController();
  final _x0Controller = TextEditingController();  // Initial guess
  final _errorController = TextEditingController();
  final _iterationsController = TextEditingController();
  final _coefficientController = TextEditingController();
  final _powerController = TextEditingController();
  final _constantController = TextEditingController();
  final _angleMultiplierController = TextEditingController();
  
  bool _useError = true;
  int _decimalPlaces = 3;
  List<Map<String, dynamic>> _terms = [];
  late final ValueNotifier<List<Map<String, dynamic>>> _historyNotifier;

  late final AnimationController _headerAnimationController;
  String? _selectedTrigType;

  @override
  void initState() {
    super.initState();
    _historyNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _headerAnimationController.forward();
    _loadHistory();
  }

  @override
  void dispose() {
    _historyNotifier.dispose();
    _functionController.dispose();
    _x0Controller.dispose();
    _errorController.dispose();
    _iterationsController.dispose();
    _coefficientController.dispose();
    _powerController.dispose();
    _constantController.dispose();
    _angleMultiplierController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _clearForm() async {
    setState(() {
      _functionController = TextEditingController();
      _x0Controller.clear();
      _errorController.clear();
      _iterationsController.clear();
      _coefficientController.clear();
      _powerController.clear();
      _constantController.clear();
      _terms.clear();
      _useError = true;
      _decimalPlaces = 3;
    });
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('newton_method_history');
      
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
      
      await prefs.setString('newton_method_history', json.encode(historyToSave));
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

  void _solve() {
    if (!_formKey.currentState!.validate()) return;

    final x0 = double.parse(_x0Controller.text);
    final error = _useError ? double.parse(_errorController.text) : 0.001;
    final maxIterations = _useError ? 100 : int.parse(_iterationsController.text);

    final method = NewtonMethod(_terms, decimalPlaces: _decimalPlaces);
    
    try {
      final results = method.solve(
        x0: x0,
        es: error,
        maxi: maxIterations,
      );

      _saveToHistory();

      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: NewtonSolutionScreen(
                results: results,
                function: _functionController.text,
                x0: x0,
                es: error,
                maxIterations: maxIterations,
                useError: _useError,
                decimalPlaces: _decimalPlaces,
              ),
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
                          title: 'Set Initial Guess',
                          description: 'Enter your initial guess (x₀) for where the root might be.',
                          icon: Icons.play_arrow_rounded,
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
                          description: 'Hit the calculate button to find the root using the Newton method.',
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
                                      'NEWTON METHOD',
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
                            icon: Icons.play_arrow_rounded,
                            colorScheme: colorScheme,
                            isExpanded: _functionController.text.isNotEmpty,
                            content: _buildInitialGuessInput(colorScheme),
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
      margin: const EdgeInsets.only(bottom: 16),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
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

  Widget _buildFunctionInput(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFunctionDialog(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
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

  Widget _buildInitialGuessInput(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: _buildInputField(
        controller: _x0Controller,
        hint: 'Enter initial guess',
        prefix: 'x₀ =',
        colorScheme: colorScheme,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-+]?([0-9]*[.])?[0-9]+')),
        ],
      ),
    );
  }

  Widget _buildStoppingCriteria(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
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
              const SizedBox(width: 16),
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
          const SizedBox(height: 16),
          _buildInputField(
            controller: _useError ? _errorController : _iterationsController,
            hint: _useError ? 'Enter error percentage' : 'Enter number of iterations',
            prefix: _useError ? 'ε =' : 'n =',
            colorScheme: colorScheme,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(_useError 
                  ? RegExp(r'[0-9]*\.?[0-9]*') 
                  : RegExp(r'[0-9]+')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required ColorScheme colorScheme,
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        fontSize: 14.sp,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix != null ? '$prefix ' : null,
        prefixStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          fontSize: 14.sp,
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: EdgeInsets.all(16.w),
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
            color: colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(
            color: colorScheme.secondary,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
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
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 12.h,
            horizontal: 16.w,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.secondary
                  : colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.03),
                blurRadius: 20.r,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20.w,
                height: 20.w,
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
                    width: isSelected ? 12.w : 0,
                    height: isSelected ? 12.w : 0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colorScheme.secondary : Colors.transparent,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? colorScheme.primary 
                      : colorScheme.primary.withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
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
            onTap: _clearForm,
            icon: Icons.refresh_rounded,
            label: 'RESET',
            colorScheme: colorScheme,
            isOutlined: true,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildActionButton(
              onTap: _solve,
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
    const number = 3.141592653589793;
    String formatted = number.toStringAsFixed(_decimalPlaces);
    // Remove trailing zeros
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0*$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  Widget _buildBackButton(ColorScheme colorScheme) {
    return Hero(
      tag: 'back_button',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _clearForm();
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
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
              color: colorScheme.primary,
              size: 24,
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
            padding: const EdgeInsets.all(12),
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
              color: colorScheme.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
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
                Expanded(
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
                                        'Calculations you perform will be saved here for easy access. Find roots efficiently with the Newton Method.',
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
                          return Dismissible(
                            key: ValueKey(item['timestamp']),
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
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'x₀ = ${item['x0']}',
                                              style: TextStyle(
                                                color: colorScheme.primary.withOpacity(0.5),
                                                fontSize: 14,
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

  void _showFunctionDialog() {
    List<Map<String, dynamic>> dialogTerms = List.from(_terms);
    
    _coefficientController.clear();
    _powerController.clear();
    _constantController.clear();
    _angleMultiplierController.text = '';
    _selectedTrigType = null;

    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isConstantMode = !(_selectedTrigType == null || (_selectedTrigType?.isNotEmpty ?? false));
// Default value
          try {
            if (_angleMultiplierController.text.isNotEmpty) {
            }
          } catch (e) {
            // If parsing fails, keep the default value of 1
          }
          int xPower = _powerController.text.isEmpty ? 1 : int.parse(_powerController.text);
          
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Text(
                          'Function Builder',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
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
                  Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.surfaceVariant.withOpacity(0.3),
                          colorScheme.surfaceVariant.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            label: 'Polynomial',
                            isSelected: _selectedTrigType == null && !isConstantMode,
                            onTap: () => setState(() {
                              _selectedTrigType = null;
                              isConstantMode = false;
                            }),
                            colorScheme: colorScheme,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            label: 'Trig',
                            isSelected: _selectedTrigType != null && !isConstantMode,
                            onTap: () => setState(() {
                              _selectedTrigType = 'sin';
                              isConstantMode = false;
                            }),
                            colorScheme: colorScheme,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            label: 'Constant',
                            isSelected: isConstantMode,
                            onTap: () => setState(() {
                              _selectedTrigType = '';
                              isConstantMode = true;
                            }),
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedTrigType != null && !isConstantMode) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildTrigButton('sin', setState, colorScheme),
                                      const SizedBox(width: 8),
                                      _buildTrigButton('cos', setState, colorScheme),
                                      const SizedBox(width: 8),
                                      _buildTrigButton('tan', setState, colorScheme),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _angleMultiplierController,
                                    keyboardType: TextInputType.text,
                                    decoration: InputDecoration(
                                      labelText: 'Angle Multiplier',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.speed_rounded,
                                        color: colorScheme.primary.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Power of x inside brackets',
                                    style: TextStyle(
                                      color: colorScheme.primary.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SliderTheme(
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
                                      valueIndicatorColor: colorScheme.secondary,
                                      valueIndicatorTextStyle: TextStyle(
                                        color: colorScheme.onSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      showValueIndicator: ShowValueIndicator.always,
                                    ),
                                    child: Slider(
                                      value: xPower.toDouble(),
                                      min: 1,
                                      max: 10,
                                      divisions: 9,
                                      label: xPower.toString(),
                                      onChanged: (value) {
                                        setState(() {
                                          xPower = value.round();
                                          _powerController.text = xPower.toString();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      _selectedTrigType != null 
                                          ? '$_selectedTrigType(${_angleMultiplierController.text.isEmpty ? "x" : ("${_angleMultiplierController.text}x")}${xPower > 1 ? _convertToSuperscript(xPower.toString()) : ""})'
                                          : '',
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (isConstantMode)
                            TextField(
                              controller: _constantController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: InputDecoration(
                                labelText: 'Constant Value',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                prefixIcon: Icon(
                                  Icons.exposure_zero_rounded,
                                  color: colorScheme.primary.withOpacity(0.5),
                                ),
                              ),
                            )
                          else ...[
                            TextField(
                              controller: _coefficientController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: InputDecoration(
                                labelText: 'Coefficient',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                prefixIcon: Icon(
                                  Icons.calculate_rounded,
                                  color: colorScheme.primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                            if (_selectedTrigType == null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primary.withOpacity(0.08),
                                      colorScheme.secondary.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: colorScheme.secondary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.power_input_rounded,
                                            color: colorScheme.secondary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Power of x',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                colorScheme.secondary.withOpacity(0.2),
                                                colorScheme.tertiary.withOpacity(0.2),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.secondary.withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'x${_powerController.text.isEmpty ? '' : _convertToSuperscript(_powerController.text.isEmpty ? '1' : _powerController.text)}',
                                            style: TextStyle(
                                              color: colorScheme.secondary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: colorScheme.outline.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '1',
                                                style: TextStyle(
                                                  color: colorScheme.primary.withOpacity(0.6),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primaryContainer.withOpacity(0.5),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  'Current: ${_powerController.text.isEmpty ? '1' : _powerController.text}',
                                                  style: TextStyle(
                                                    color: colorScheme.onPrimaryContainer,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '10',
                                                style: TextStyle(
                                                  color: colorScheme.primary.withOpacity(0.6),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: colorScheme.secondary,
                                              inactiveTrackColor: colorScheme.secondary.withOpacity(0.1),
                                              thumbColor: colorScheme.secondary,
                                              overlayColor: colorScheme.secondary.withOpacity(0.1),
                                              trackHeight: 6,
                                              thumbShape: const RoundSliderThumbShape(
                                                enabledThumbRadius: 10,
                                                elevation: 4,
                                                pressedElevation: 8,
                                              ),
                                              overlayShape: const RoundSliderOverlayShape(
                                                overlayRadius: 24,
                                              ),
                                              valueIndicatorColor: colorScheme.secondary,
                                              valueIndicatorTextStyle: TextStyle(
                                                color: colorScheme.onSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              showValueIndicator: ShowValueIndicator.always,
                                            ),
                                            child: Slider(
                                              value: (_powerController.text.isEmpty ? 1 : int.parse(_powerController.text)).toDouble(),
                                              min: 1,
                                              max: 10,
                                              divisions: 9,
                                              label: (_powerController.text.isEmpty ? 1 : int.parse(_powerController.text)).toString(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _powerController.text = value.round().toString();
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    Text(
                                      'Quick Select',
                                      style: TextStyle(
                                        color: colorScheme.primary.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: List.generate(
                                          5,
                                          (index) {
                                            final powerValue = index * 2 + 2;
                                            final isSelected = (_powerController.text.isEmpty ? 1 : int.parse(_powerController.text)) == powerValue;
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _powerController.text = powerValue.toString();
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? colorScheme.secondary.withOpacity(0.2) : colorScheme.surface,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: isSelected ? colorScheme.secondary : colorScheme.outline.withOpacity(0.1),
                                                        width: 1.5,
                                                      ),
                                                      boxShadow: isSelected ? [
                                                        BoxShadow(
                                                          color: colorScheme.secondary.withOpacity(0.2),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ] : null,
                                                    ),
                                                    child: Text(
                                                      'x${_convertToSuperscript(powerValue.toString())}',
                                                      style: TextStyle(
                                                        color: isSelected ? colorScheme.secondary : colorScheme.primary.withOpacity(0.6),
                                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          if (dialogTerms.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Function',
                                    style: TextStyle(
                                      color: colorScheme.primary.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      'f(x) = ${_buildFunctionStringFromTerms(dialogTerms)}',
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            if (isConstantMode) {
                              if (_constantController.text.isNotEmpty) {
                                setState(() {
                                  dialogTerms.add({
                                    'coefficient': double.parse(_constantController.text),
                                    'power': 0,
                                    'isVariable': false,
                                  });
                                  _constantController.clear();
                                });
                              }
                            } else if (_coefficientController.text.isNotEmpty) {
                              setState(() {
                                dialogTerms.add({
                                  'coefficient': double.parse(_coefficientController.text),
                                  'power': _selectedTrigType != null ? xPower : 
                                          (_powerController.text.isEmpty ? 1 : int.parse(_powerController.text)),
                                  'isVariable': _selectedTrigType == null,
                                  'xPower': xPower,
                                  'angleMultiplier': _angleMultiplierController.text.isEmpty 
                                      ? 1 
                                      : (int.tryParse(_angleMultiplierController.text) ?? 1),
                                  if (_selectedTrigType != null && !isConstantMode) 'trigType': _selectedTrigType,
                                });
                                _coefficientController.clear();
                                _powerController.clear();
                              });
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('ADD TERM'),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            this.setState(() {
                              _terms = List.from(dialogTerms);
                              _functionController.text = _buildFunctionStringFromTerms(dialogTerms);
                            });
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('DONE'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    // Select appropriate icon based on tab label
    IconData getIcon() {
      switch(label) {
        case 'Polynomial':
          return Icons.functions_rounded;
        case 'Trig':
          return Icons.waves_rounded;
        case 'Constant':
          return Icons.exposure_zero_rounded;
        default:
          return Icons.functions_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        gradient: isSelected ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.2),
            colorScheme.secondary.withOpacity(0.1),
          ],
        ) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected ? [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: colorScheme.primary.withOpacity(0.1),
          highlightColor: colorScheme.primary.withOpacity(0.05),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  getIcon(),
                  size: 14,
                  color: isSelected 
                      ? colorScheme.primary 
                      : colorScheme.primary.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected 
                          ? colorScheme.primary 
                          : colorScheme.primary.withOpacity(0.6),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
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

  Widget _buildTrigButton(String type, StateSetter setState, ColorScheme colorScheme) {
    final isSelected = _selectedTrigType == type;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTrigType = type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.secondary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? colorScheme.secondary : colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Text(
              type,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? colorScheme.secondary : colorScheme.primary.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
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
      String? trigType = term['trigType'];
      int? xPower = term['xPower'];
      int? angleMultiplier = term['angleMultiplier'];
      
      if (coefficient != 0) {
        if (coefficient == -1 && (isVariable || trigType != null)) {
          termString += '-';
        } else if (coefficient != 1 || (!isVariable && trigType == null)) {
          if (coefficient % 1 == 0) {
            termString += coefficient.toInt().toString();
          } else {
            termString += coefficient.toString();
          }
        }
      }
      
      if (trigType != null) {
        termString += trigType;
        if (angleMultiplier != null && xPower != null) {
          if (xPower != 1) {
            termString += '(${angleMultiplier}x${_convertToSuperscript(xPower.toString())})';
          } else {
            termString += '(${angleMultiplier}x)';
          }
        }
      } else if (isVariable) {
        termString += 'x';
        if (power != 1) {
          termString += _convertToSuperscript(power.toString());
        }
      }
      
      if (termString.isNotEmpty) {
        if (termStrings.isNotEmpty && !termString.startsWith('-')) {
          termStrings.add('+');
        }
        termStrings.add(termString);
      }
    }
    
    return termStrings.join(' ');
  }

  String _convertToSuperscript(String number) {
    final Map<String, String> superscriptMap = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '-': '⁻'
    };
    return number.split('').map((digit) => superscriptMap[digit] ?? digit).join('');
  }
}
