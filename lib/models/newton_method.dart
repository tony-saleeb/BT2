import 'dart:math';

class NewtonResult {
  final int iteration;
  final double xi;  // Current x value
  final double fxi;  // f(xi)
  final double fpxi;  // f'(xi)
  final double? ea;  // Approximate error
  final bool isRoot;
  final Map<String, String> debugSteps;

  NewtonResult({
    required this.iteration,
    required this.xi,
    required this.fxi,
    required this.fpxi,
    this.ea,
    required this.isRoot,
    required this.debugSteps,
  });
}

class NewtonMethod {
  final List<Map<String, dynamic>> terms;
  static const double tolerance = 0.001;
  final int decimalPlaces;

  NewtonMethod(this.terms, {this.decimalPlaces = 3});

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

  // Evaluates f(x)
  double f(double x) {
    if (terms.isEmpty) {
      return pow(x, 2) - 4;  // Default function if none provided
    }

    double result = 0.0;
    
    for (var term in terms) {
      double coefficient = term['coefficient'] ?? 0.0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;
      String? trigType = term['trigType'] as String?;

      if (trigType != null) {
        // Handle trigonometric functions
        double angle = x;
        if (power != 1) {
          angle *= power.toDouble();
        }
        
        double trigValue;
        switch (trigType) {
          case 'sin':
            trigValue = sin(angle);
            break;
          case 'cos':
            trigValue = cos(angle);
            break;
          case 'tan':
            trigValue = tan(angle);
            break;
          default:
            trigValue = 0;
        }
        result += coefficient * trigValue;
      } else if (isVariable) {
        double powerResult = precisePow(x, power);
        result += coefficient * powerResult;
      } else {
        result += coefficient;
      }
    }
    
    return result;
  }

  // Evaluates f'(x) - the derivative
  double fp(double x) {
    if (terms.isEmpty) {
      return 2 * x;  // Derivative of default function
    }

    double result = 0.0;
    
    for (var term in terms) {
      double coefficient = term['coefficient'] ?? 0.0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;
      String? trigType = term['trigType'] as String?;

      if (trigType != null) {
        // Handle derivatives of trigonometric functions
        double angle = x;
        if (power != 1) {
          angle *= power.toDouble();
          coefficient *= power; // Chain rule
        }
        
        double derivValue;
        switch (trigType) {
          case 'sin':
            derivValue = cos(angle); // d/dx(sin(x)) = cos(x)
            break;
          case 'cos':
            derivValue = -sin(angle); // d/dx(cos(x)) = -sin(x)
            break;
          case 'tan':
            double secValue = 1 / cos(angle);
            derivValue = secValue * secValue; // d/dx(tan(x)) = sec²(x)
            break;
          default:
            derivValue = 0;
        }
        result += coefficient * derivValue;
      } else if (isVariable && power > 0) {
        // Apply power rule: d/dx(ax^n) = a*n*x^(n-1)
        double newCoefficient = coefficient * power;
        int newPower = power - 1;
        result += newCoefficient * precisePow(x, newPower);
      }
    }
    
    return result;
  }

  double precisePow(double base, int power) {
    if (power == 0) return 1.0;
    if (power == 1) return base;
    if (power < 0) {
      return 1.0 / pow(base, -power).toDouble();
    }
    return pow(base, power).toDouble();
  }

  List<NewtonResult> solve({
    required double x0,
    required double es,
    required int maxi,
  }) {
    // Input validation
    if (es <= 0) {
      throw ArgumentError('Stopping criterion (es) must be positive');
    }
    if (maxi <= 0) {
      throw ArgumentError('Maximum iterations (maxi) must be positive');
    }

    List<NewtonResult> results = [];
    double xi = x0;
    int i = 0;
    double error = double.infinity;
    double minDerivative = 1e-10;
    bool shouldStop = false;

    while (i < maxi && !shouldStop) {
      double fxi = f(xi);
      double fpxi = fp(xi);

      Map<String, String> debugSteps = {};
      debugSteps['f(x)_calc'] = _getFunctionCalculationSteps(xi);
      debugSteps['fp(x)_calc'] = _getDerivativeCalculationSteps(xi);

      // Check if we found a root (f(x) ≈ 0)
      bool isRoot = fxi.abs() < tolerance;

      // Add current iteration to results
      results.add(NewtonResult(
        iteration: i,
        xi: xi,
        fxi: fxi,
        fpxi: fpxi,
        ea: i == 0 ? null : error,
        isRoot: isRoot,
        debugSteps: Map.from(debugSteps),
      ));

      // Check stopping conditions after adding current result
      if (isRoot || (i > 0 && error <= es)) {
        shouldStop = true;
        break;
      }

      // Check for near-zero derivative
      if (fpxi.abs() < minDerivative) {
        throw Exception('Derivative too close to zero at x = ${_formatNumber(xi)}');
      }

      // Newton's formula
      double correction = fxi / fpxi;
      double xiNext = xi - correction;
      
      // Calculate relative error using a more robust formula
      if (xiNext.abs() > 1e-10) {
        error = ((xiNext - xi) / xiNext).abs() * 100;
      } else if (xi.abs() > 1e-10) {
        error = ((xiNext - xi) / xi).abs() * 100;
      } else {
        error = (xiNext - xi).abs() * 100;
      }

      // Check for divergence
      if (error > 1e6) {
        throw Exception('Method is diverging');
      }

      // Update xi and increment i
      xi = xiNext;
      i++;
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
      String? trigType = term['trigType'] as String?;

      if (trigType != null) {
        // Handle trigonometric functions
        double angle = x;
        if (power != 1) {
          angle *= power.toDouble();
        }
        
        double trigValue;
        switch (trigType) {
          case 'sin':
            trigValue = sin(angle);
            break;
          case 'cos':
            trigValue = cos(angle);
            break;
          case 'tan':
            trigValue = tan(angle);
            break;
          default:
            trigValue = 0;
        }
        result += coefficient * trigValue;
        
        String termStr = '';
        if (coefficient != 1 || power == 0) {
          termStr += _formatNumber(coefficient);
        }
        if (power > 0) {
          termStr += 'sin(${_formatNumber(angle)})';
        }
        
        String calcStep = '(${_formatNumber(coefficient)} × ${_formatNumber(trigValue)})';
        
        termsStr.add('$termStr $calcStep');
      } else if (isVariable) {
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
        
        String calcStep = '(${_formatNumber(coefficient)} × ${_formatNumber(powerResult)})';
        
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

  String _getDerivativeCalculationSteps(double x) {
    if (terms.isEmpty) {
      return '''
f'(${_formatNumber(x)}) = 2x
       = ${_formatNumber(2 * x)}
''';
    }

    List<String> steps = [];
    steps.add('f\'(${_formatNumber(x)}) = ');
    
    double result = 0.0;
    List<String> termsStr = [];
    
    for (var term in terms) {
      double coefficient = term['coefficient'] ?? 0.0;
      int power = term['power'] ?? 0;
      bool isVariable = term['isVariable'] ?? false;
      String? trigType = term['trigType'] as String?;

      if (trigType != null) {
        // Handle derivatives of trigonometric functions
        double angle = x;
        if (power != 1) {
          angle *= power.toDouble();
          coefficient *= power; // Chain rule
        }
        
        double derivValue;
        switch (trigType) {
          case 'sin':
            derivValue = cos(angle); // d/dx(sin(x)) = cos(x)
            break;
          case 'cos':
            derivValue = -sin(angle); // d/dx(cos(x)) = -sin(x)
            break;
          case 'tan':
            double secValue = 1 / cos(angle);
            derivValue = secValue * secValue; // d/dx(tan(x)) = sec²(x)
            break;
          default:
            derivValue = 0;
        }
        result += coefficient * derivValue;
        
        String termStr = '';
        if (coefficient != 1 || power == 0) {
          termStr += _formatNumber(coefficient);
        }
        if (power > 0) {
          termStr += 'd/dx(sin(${_formatNumber(angle)}))';
        }
        
        String calcStep = '(${_formatNumber(coefficient)} × ${_formatNumber(derivValue)})';
        
        termsStr.add('$termStr $calcStep');
      } else if (isVariable && power > 0) {
        // Apply power rule: d/dx(ax^n) = a*n*x^(n-1)
        double newCoefficient = coefficient * power;
        int newPower = power - 1;
        result += newCoefficient * precisePow(x, newPower);
        
        String termStr = '';
        if (newCoefficient != 1 || newPower == 0) {
          termStr += _formatNumber(newCoefficient);
        }
        if (newPower > 0) {
          termStr += 'x';
          if (newPower > 1) {
            termStr += newPower.toString();
          }
        }
        
        String calcStep = '(${_formatNumber(newCoefficient)} × ${_formatNumber(precisePow(x, newPower))})';
        
        termsStr.add('$termStr $calcStep');
      }
    }
    
    if (termsStr.isEmpty) {
      termsStr.add('0');
      result = 0;
    }
    
    steps.add(termsStr.join(' + '));
    steps.add('= ${_formatNumber(result)}');
    
    return steps.join('\n       ');
  }
} 