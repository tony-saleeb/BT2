import 'dart:math';

class FalsePositionResult {
  final int iteration;
  final double xl;
  final double fxl;
  final double xr;
  final double fxr;
  final double xu;
  final double fxu;
  final double? ea;
  final bool isRoot;
  final Map<String, String> debugSteps;

  FalsePositionResult({
    required this.iteration,
    required this.xl,
    required this.fxl,
    required this.xr,
    required this.fxr,
    required this.xu,
    required this.fxu,
    this.ea,
    required this.isRoot,
    required this.debugSteps,
  });
}

class FalsePositionMethod {
  final List<Map<String, dynamic>> terms;
  static const double tolerance = 0.001;
  final int decimalPlaces;

  FalsePositionMethod(this.terms, {this.decimalPlaces = 3});

  String _formatNumber(double number) {
    String fullStr = number.toString();
    
    int decimalPos = fullStr.indexOf('.');
    if (decimalPos == -1) {
      return fullStr;
    }
    
    int endPos = decimalPos + decimalPlaces + 1;
    if (endPos > fullStr.length) {
      endPos = fullStr.length;
    }
    
    return fullStr.substring(0, endPos);
  }

  double f(double x) {
    if (terms.isEmpty) {
      return pow(x, 2) - 4;
    }

    double result = 0.0;
    
    for (var term in terms) {
      double coefficient = term['coefficient'] ?? 0.0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;

      if (isVariable) {
        double powerResult = precisePow(x, power);
        result += coefficient * powerResult;
      } else {
        result += coefficient;
      }
    }
    
    return result;
  }

  double precisePow(double base, int power) {
    if (power == 0) return 1.0;
    if (power == 1) return base;
    if (power == 2) return base * base;
    if (power == 3) return base * base * base;
    
    double result = 1.0;
    for (int i = 0; i < power; i++) {
      result *= base;
    }
    return result;
  }

  List<FalsePositionResult> solve({
    required double xl,
    required double xu,
    required double es,
    required int maxi,
  }) {
    if (xl >= xu) {
      throw ArgumentError('Lower bound (xl) must be less than upper bound (xu)');
    }
    if (es <= 0) {
      throw ArgumentError('Stopping criterion (es) must be positive');
    }
    if (maxi <= 0) {
      throw ArgumentError('Maximum iterations (maxi) must be positive');
    }

    List<FalsePositionResult> results = [];
    
    double xr;
    double xrOld = 0.0;
    int i = 1;
    double error;

    double fxl = f(xl);
    double fxu = f(xu);
    
    Map<String, String> debugSteps = {};
    debugSteps['f(xl)_calc'] = _getFunctionCalculationSteps(xl);
    debugSteps['f(xu)_calc'] = _getFunctionCalculationSteps(xu);
    
    if (fxl * fxu > 0) {
      throw ArgumentError('Initial bounds do not bracket a root');
    }

    xr = (xl * fxu - xu * fxl) / (fxu - fxl);
    debugSteps['xr_calc'] = '''
Numerator = (xl × f(xu)) - (xu × f(xl))
         = (${_formatNumber(xl)} × ${_formatNumber(fxu)}) - (${_formatNumber(xu)} × ${_formatNumber(fxl)})
         = ${_formatNumber(xl * fxu)} - ${_formatNumber(xu * fxl)}
         = ${_formatNumber(xl * fxu - xu * fxl)}

Denominator = f(xu) - f(xl)
           = ${_formatNumber(fxu)} - ${_formatNumber(fxl)}
           = ${_formatNumber(fxu - fxl)}

xr = Numerator ÷ Denominator
   = ${_formatNumber(xl * fxu - xu * fxl)} ÷ ${_formatNumber(fxu - fxl)}
   = ${_formatNumber(xr)}
''';
    
    double fxr = f(xr);
    debugSteps['f(xr)_calc'] = _getFunctionCalculationSteps(xr);

    results.add(FalsePositionResult(
      iteration: i,
      xl: xl,
      fxl: fxl,
      xr: xr,
      fxr: fxr,
      xu: xu,
      fxu: fxu,
      ea: null,
      isRoot: fxr.abs() < tolerance,
      debugSteps: Map.from(debugSteps),
    ));

    while (i < maxi) {
      i++;
      xrOld = xr;
      debugSteps.clear();

      if (fxr * fxl > 0) {
        xl = xr;
        fxl = fxr;
        debugSteps['interval_update'] = '''
Since f(xr) × f(xl) > 0:
  xl_new = xr = ${_formatNumber(xr)}
  f(xl_new) = f(xr) = ${_formatNumber(fxr)}''';
      } else {
        xu = xr;
        fxu = fxr;
        debugSteps['interval_update'] = '''
Since f(xr) × f(xl) ≤ 0:
  xu_new = xr = ${_formatNumber(xr)}
  f(xu_new) = f(xr) = ${_formatNumber(fxr)}''';
      }

      xr = (xl * fxu - xu * fxl) / (fxu - fxl);
      debugSteps['xr_calc'] = '''
Numerator = (xl × f(xu)) - (xu × f(xl))
         = (${_formatNumber(xl)} × ${_formatNumber(fxu)}) - (${_formatNumber(xu)} × ${_formatNumber(fxl)})
         = ${_formatNumber(xl * fxu)} - ${_formatNumber(xu * fxl)}
         = ${_formatNumber(xl * fxu - xu * fxl)}

Denominator = f(xu) - f(xl)
           = ${_formatNumber(fxu)} - ${_formatNumber(fxl)}
           = ${_formatNumber(fxu - fxl)}

xr = Numerator ÷ Denominator
   = ${_formatNumber(xl * fxu - xu * fxl)} ÷ ${_formatNumber(fxu - fxl)}
   = ${_formatNumber(xr)}
''';
      
      fxr = f(xr);
      debugSteps['f(xr)_calc'] = _getFunctionCalculationSteps(xr);

      error = xr != 0 ? (((xr - xrOld) / xr).abs()) * 100.0 : double.infinity;
      debugSteps['error_calc'] = '''
Error = |((xr_new - xr_old) ÷ xr_new)| × 100%
      = |(${_formatNumber(xr)} - ${_formatNumber(xrOld)}) ÷ ${_formatNumber(xr)}| × 100%
      = |${_formatNumber(xr - xrOld)} ÷ ${_formatNumber(xr)}| × 100%
      = |${_formatNumber((xr - xrOld) / xr)}| × 100%
      = ${_formatNumber(error)}%
''';

      results.add(FalsePositionResult(
        iteration: i,
        xl: xl,
        fxl: fxl,
        xr: xr,
        fxr: fxr,
        xu: xu,
        fxu: fxu,
        ea: error,
        isRoot: fxr.abs() < tolerance,
        debugSteps: Map.from(debugSteps),
      ));

      if (error < es) {
        break;
      }
    }

    return results;
  }

  String _getFunctionCalculationSteps(double x) {
    if (terms.isEmpty) {
      return '''
f(${_formatNumber(x)}) = x² - 4
      = ${_formatNumber(x * x)} - 4
      = ${_formatNumber(x * x - 4)}
''';
    }

    List<String> steps = [];
    steps.add('f(${_formatNumber(x)}) = ');
    
    double result = 0.0;
    List<String> termsStr = [];
    
    for (var term in terms) {
      double coefficient = term['coefficient'] ?? 0.0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;

      if (isVariable) {
        double powerResult = precisePow(x, power);
        result += coefficient * powerResult;
        
        String termStr = '';
        if (coefficient != 1 || power == 0) {
          termStr += _formatNumber(coefficient);
        }
        if (power > 0) {
          termStr += 'x';
          if (power > 1) {
            termStr += power.toString();
          }
        }
        
        String calcStep = '(${_formatNumber(coefficient)} × ${_formatNumber(x)}';
        if (power > 1) {
          calcStep += '^$power';
        }
        calcStep += ' = ${_formatNumber(coefficient)} × ${_formatNumber(powerResult)} = ${_formatNumber(coefficient * powerResult)})';
        
        termsStr.add('$termStr $calcStep');
      } else {
        result += coefficient;
        termsStr.add(_formatNumber(coefficient));
      }
    }
    
    steps.add(termsStr.join(' + '));
    steps.add('= ${_formatNumber(result)}');
    
    return steps.join('\n      ');
  }
} 