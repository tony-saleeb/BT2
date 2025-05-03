// Library for LU Decomposition method implementation
// ignore_for_file: non_constant_identifier_names

import 'dart:math';

class LUDecompositionResult {
  final List<List<double>> originalMatrix;
  final List<List<double>> lMatrix;
  final List<List<double>> uMatrix;
  final List<double> solution;
  final List<double>? yVector;
  final Map<String, dynamic> debug;
  final bool isSolved;
  final String? errorMessage;
  
  // Fields for verification and steps display
  final List<DecompositionStep> steps;
  final List<double> originalB;
  final List<double> verificationAxb;
  final double? error;
  final double? decompositionError;
  final bool isDecompositionValid;

  LUDecompositionResult({
    required this.originalMatrix,
    required this.lMatrix,
    required this.uMatrix,
    required this.solution,
    this.yVector,
    required this.debug,
    required this.isSolved,
    this.errorMessage,
    this.steps = const [],
    this.originalB = const [],
    this.verificationAxb = const [],
    this.error,
    this.decompositionError,
    this.isDecompositionValid = false,
  });
}

// Class to represent a step in the decomposition process
class DecompositionStep {
  final String description;
  final String explanation;
  final List<List<double>> matrix;
  final int? pivotRow;
  final int? pivotCol;
  final int? operationRow;
  
  DecompositionStep({
    required this.description,
    this.explanation = '',
    required this.matrix,
    this.pivotRow,
    this.pivotCol,
    this.operationRow,
  });
}

class LUDecompositionMethod {
  // Solve a system of linear equations using LU Decomposition
  static LUDecompositionResult solve({
    required List<List<double>> coefficients,
    required List<double> constants,
    required bool usePartialPivoting,
    int decimalPlaces = 4,
  }) {
    try {
      // Check if system is valid
      if (coefficients.isEmpty) {
        return LUDecompositionResult(
          originalMatrix: [],
          lMatrix: [],
          uMatrix: [],
          solution: [],
          debug: {},
          isSolved: false,
          errorMessage: "Empty coefficient matrix",
        );
      }

      final numRows = coefficients.length;
      final numCols = coefficients[0].length;

      // Check if all rows have the same number of coefficients
      for (int i = 0; i < numRows; i++) {
        if (coefficients[i].length != numCols) {
          return LUDecompositionResult(
            originalMatrix: List<List<double>>.from(coefficients),
            lMatrix: [],
            uMatrix: [],
            solution: [],
            debug: {},
            isSolved: false,
            errorMessage: "Inconsistent number of coefficients in rows",
          );
        }
      }

      // Check if constants array matches number of equations
      if (constants.length != numRows) {
        return LUDecompositionResult(
          originalMatrix: List<List<double>>.from(coefficients),
          lMatrix: [],
          uMatrix: [],
          solution: [],
          debug: {},
          isSolved: false,
          errorMessage: "Number of constants doesn't match number of equations",
        );
      }

      // For square systems, check if we have enough equations
      if (numRows < numCols) {
        return LUDecompositionResult(
          originalMatrix: List<List<double>>.from(coefficients),
          lMatrix: [],
          uMatrix: [],
          solution: [],
          debug: {},
          isSolved: false,
          errorMessage: "Underdetermined system: more variables than equations",
        );
      }

      // Check if the matrix is square (required for LU decomposition)
      if (numRows != numCols) {
        return LUDecompositionResult(
          originalMatrix: List<List<double>>.from(coefficients),
          lMatrix: [],
          uMatrix: [],
          solution: [],
          debug: {},
          isSolved: false,
          errorMessage: "Matrix must be square for LU decomposition",
        );
      }

      // Make a copy of the original matrix
      final originalMatrix = List<List<double>>.from(
        coefficients.map((row) => List<double>.from(row))
      );
      
      // Make a copy of original constants
      final originalB = List<double>.from(constants);

      // Store computation steps
      final List<Map<String, dynamic>> decompositionSteps = [];
      
      // Perform LU Decomposition
      final decompositionResult = _doLUDecomposition(
        coefficients: coefficients,
        usePartialPivoting: usePartialPivoting,
        decimalPlaces: decimalPlaces,
      );
      
      if (!decompositionResult['success']) {
        return LUDecompositionResult(
          originalMatrix: originalMatrix,
          lMatrix: [],
          uMatrix: [],
          solution: [],
          debug: {'decomposition_steps': decompositionSteps},
          isSolved: false,
          errorMessage: decompositionResult['error'],
          originalB: originalB,
        );
      }

      decompositionSteps.addAll(decompositionResult['steps']);
      final lMatrix = decompositionResult['L'];
      final uMatrix = decompositionResult['U'];
      final List<int>? permutation = decompositionResult['permutation'];

      // Apply permutation to constants vector if partial pivoting was used
      List<double> permutedConstants = List<double>.from(constants);
      if (usePartialPivoting && permutation != null) {
        permutedConstants = List<double>.filled(numRows, 0.0);
        for (int i = 0; i < numRows; i++) {
          permutedConstants[i] = constants[permutation[i]];
        }
      }

      // Solve Ly = b for y
      final forwardResult = _forwardSubstitution(
        lMatrix: lMatrix,
        constants: permutedConstants,
        decimalPlaces: decimalPlaces,
      );
      
      if (!forwardResult['success']) {
        return LUDecompositionResult(
          originalMatrix: originalMatrix,
          lMatrix: lMatrix,
          uMatrix: uMatrix,
          solution: [],
          debug: {'decomposition_steps': decompositionSteps},
          isSolved: false,
          errorMessage: forwardResult['error'],
          originalB: originalB,
        );
      }

      decompositionSteps.addAll(forwardResult['steps']);
      final List<double> yVector = forwardResult['solution'];

      // Solve Ux = y for x
      final backwardResult = _backSubstitution(
        uMatrix: uMatrix,
        constants: yVector,
        decimalPlaces: decimalPlaces,
      );
      
      if (!backwardResult['success']) {
        return LUDecompositionResult(
          originalMatrix: originalMatrix,
          lMatrix: lMatrix,
          uMatrix: uMatrix,
          solution: [],
          yVector: yVector,
          debug: {'decomposition_steps': decompositionSteps},
          isSolved: false,
          errorMessage: backwardResult['error'],
          originalB: originalB,
        );
      }

      decompositionSteps.addAll(backwardResult['steps']);
      final List<double> solution = backwardResult['solution'];
      
      // Compute verification values
      final verificationAxb = _computeAxb(originalMatrix, solution);
      final error = _computeError(originalB, verificationAxb);
      
      // Verify L×U ≈ A
      final lTimesU = _multiplyMatrices(lMatrix, uMatrix);
      final decompositionError = _matrixDifference(originalMatrix, lTimesU);
      final isDecompositionValid = decompositionError < 1e-6;
      
      // Convert decomposition steps to DecompositionStep objects
      final List<DecompositionStep> processedSteps = _processDecompositionSteps(decompositionSteps);

      return LUDecompositionResult(
        originalMatrix: originalMatrix,
        lMatrix: lMatrix,
        uMatrix: uMatrix,
        solution: solution,
        yVector: yVector,
        debug: {'decomposition_steps': decompositionSteps},
        isSolved: true,
        originalB: originalB,
        verificationAxb: verificationAxb,
        error: error,
        decompositionError: decompositionError,
        isDecompositionValid: isDecompositionValid,
        steps: processedSteps,
      );
    } catch (e) {
      return LUDecompositionResult(
        originalMatrix: [],
        lMatrix: [],
        uMatrix: [],
        solution: [],
        debug: {},
        isSolved: false,
        errorMessage: "Error: ${e.toString()}",
        originalB: [],
        verificationAxb: [],
      );
    }
  }

  // Perform LU Decomposition
  static Map<String, dynamic> _doLUDecomposition({
    required List<List<double>> coefficients,
    required bool usePartialPivoting,
    required int decimalPlaces,
  }) {
    final n = coefficients.length;
    final List<Map<String, dynamic>> steps = [];
    
    // Create copies to avoid modifying original
    final A = List<List<double>>.from(
      coefficients.map((row) => List<double>.from(row))
    );
    
    // Initialize L to identity matrix
    final L = List<List<double>>.generate(
      n, (i) => List<double>.generate(n, (j) => i == j ? 1.0 : 0.0)
    );
    
    // U will be the result of the elimination
    final U = List<List<double>>.from(
      coefficients.map((row) => List<double>.from(row))
    );
    
    // For partial pivoting, we need to track row permutations
    final List<int> permutation = List<int>.generate(n, (i) => i);
    
    try {
      // Add initial state as the first step
      steps.add({
        'A': List<List<double>>.from(A.map((row) => List<double>.from(row))),
        'L': List<List<double>>.from(L.map((row) => List<double>.from(row))),
        'U': List<List<double>>.from(U.map((row) => List<double>.from(row))),
        'description': 'Initial matrices: A will be factored into L and U',
      });

      // Main loop for LU decomposition
      for (int k = 0; k < n - 1; k++) {
        // Find pivot row for partial pivoting
        int pivotRow = k;
        
        if (usePartialPivoting) {
          double maxVal = U[k][k].abs();
          for (int i = k + 1; i < n; i++) {
            if (U[i][k].abs() > maxVal) {
              maxVal = U[i][k].abs();
              pivotRow = i;
            }
          }
          
          // Check if the pivot is too small (matrix might be singular)
          if (maxVal < 1e-10) {
            return {
              'success': false,
              'error': 'Matrix is singular or nearly singular.',
              'steps': steps,
            };
          }
          
          // Swap rows in U and permutation array if needed
          if (pivotRow != k) {
            // Swap rows k and pivotRow in U
            final tempU = U[k];
            U[k] = U[pivotRow];
            U[pivotRow] = tempU;
            
            // Swap elements in permutation
            final tempP = permutation[k];
            permutation[k] = permutation[pivotRow];
            permutation[pivotRow] = tempP;
            
            // Also need to swap rows 0...k-1 in L
            for (int j = 0; j < k; j++) {
              final tempL = L[k][j];
              L[k][j] = L[pivotRow][j];
              L[pivotRow][j] = tempL;
            }
            
            steps.add({
              'A': List<List<double>>.from(A.map((row) => List<double>.from(row))),
              'L': List<List<double>>.from(L.map((row) => List<double>.from(row))),
              'U': List<List<double>>.from(U.map((row) => List<double>.from(row))),
              'description': 'Swapped rows $k and $pivotRow for partial pivoting',
              'permutation': List<int>.from(permutation),
            });
          }
        }
        
        // Compute multipliers and eliminate
        for (int i = k + 1; i < n; i++) {
          if (U[k][k].abs() < 1e-10) {
            return {
              'success': false,
              'error': 'Division by zero encountered. Matrix may be singular.',
              'steps': steps,
            };
          }
          
          // Calculate multiplier
          final multiplier = _round(U[i][k] / U[k][k], decimalPlaces);
          L[i][k] = multiplier;
          
          // Update U matrix (zeroing elements below diagonal)
          for (int j = k; j < n; j++) {
            U[i][j] = _round(U[i][j] - multiplier * U[k][j], decimalPlaces);
          }
        }
        
        steps.add({
          'A': List<List<double>>.from(A.map((row) => List<double>.from(row))),
          'L': List<List<double>>.from(L.map((row) => List<double>.from(row))),
          'U': List<List<double>>.from(U.map((row) => List<double>.from(row))),
          'description': 'Computed multipliers for column $k and updated U matrix',
          'pivot_col': k,
        });
      }
      
      // Final step
      steps.add({
        'A': List<List<double>>.from(A.map((row) => List<double>.from(row))),
        'L': List<List<double>>.from(L.map((row) => List<double>.from(row))),
        'U': List<List<double>>.from(U.map((row) => List<double>.from(row))),
        'description': 'Final L and U matrices after decomposition',
        'permutation': usePartialPivoting ? List<int>.from(permutation) : null,
      });
      
      return {
        'success': true,
        'L': L,
        'U': U,
        'permutation': usePartialPivoting ? permutation : null,
        'steps': steps,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error during LU decomposition: ${e.toString()}',
        'steps': steps,
      };
    }
  }

  // Forward substitution to solve Ly = b
  static Map<String, dynamic> _forwardSubstitution({
    required List<List<double>> lMatrix,
    required List<double> constants,
    required int decimalPlaces,
  }) {
    final n = lMatrix.length;
    final List<double> y = List<double>.filled(n, 0.0);
    final List<Map<String, dynamic>> steps = [];
    
    try {
      // Add initial state
      steps.add({
        'description': 'Starting forward substitution to solve Ly = b',
        'L': List<List<double>>.from(lMatrix.map((row) => List<double>.from(row))),
        'b': List<double>.from(constants),
      });
      
      for (int i = 0; i < n; i++) {
        double sum = 0.0;
        for (int j = 0; j < i; j++) {
          sum = _round(sum + lMatrix[i][j] * y[j], decimalPlaces);
        }
        
        if (lMatrix[i][i].abs() < 1e-10) {
          return {
            'success': false,
            'error': 'Division by zero in forward substitution. L matrix is singular.',
            'steps': steps,
          };
        }
        
        y[i] = _round((constants[i] - sum) / lMatrix[i][i], decimalPlaces);
        
        steps.add({
          'description': 'Computed y[$i] = ${y[i]}',
          'current_y': List<double>.from(y),
          'row_index': i,
        });
      }
      
      // Final y vector
      steps.add({
        'description': 'Final y vector from forward substitution',
        'y': List<double>.from(y),
      });
      
      return {
        'success': true,
        'solution': y,
        'steps': steps,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error during forward substitution: ${e.toString()}',
        'steps': steps,
      };
    }
  }

  // Back substitution to solve Ux = y
  static Map<String, dynamic> _backSubstitution({
    required List<List<double>> uMatrix,
    required List<double> constants,
    required int decimalPlaces,
  }) {
    final n = uMatrix.length;
    final List<double> x = List<double>.filled(n, 0.0);
    final List<Map<String, dynamic>> steps = [];
    
    try {
      // Add initial state
      steps.add({
        'description': 'Starting back substitution to solve Ux = y',
        'U': List<List<double>>.from(uMatrix.map((row) => List<double>.from(row))),
        'y': List<double>.from(constants),
      });
      
      for (int i = n - 1; i >= 0; i--) {
        double sum = 0.0;
        for (int j = i + 1; j < n; j++) {
          sum = _round(sum + uMatrix[i][j] * x[j], decimalPlaces);
        }
        
        if (uMatrix[i][i].abs() < 1e-10) {
          return {
            'success': false,
            'error': 'Division by zero in back substitution. U matrix is singular.',
            'steps': steps,
          };
        }
        
        x[i] = _round((constants[i] - sum) / uMatrix[i][i], decimalPlaces);
        
        steps.add({
          'description': 'Computed x[$i] = ${x[i]}',
          'current_x': List<double>.from(x),
          'row_index': i,
        });
      }
      
      // Final x vector
      steps.add({
        'description': 'Final solution vector x',
        'x': List<double>.from(x),
      });
      
      return {
        'success': true,
        'solution': x,
        'steps': steps,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error during back substitution: ${e.toString()}',
        'steps': steps,
      };
    }
  }

  // Helper function to round to specific decimal places
  static double _round(double value, int places) {
    if (value.isNaN || value.isInfinite) return value;
    final mod = pow(10.0, places);
    return (value * mod).round() / mod;
  }

  // Convert raw decomposition steps to DecompositionStep objects
  static List<DecompositionStep> _processDecompositionSteps(List<Map<String, dynamic>> rawSteps) {
    final List<DecompositionStep> result = [];
    
    for (final step in rawSteps) {
      // Extract the matrix state for this step
      final List<List<double>> matrix;
      if (step.containsKey('A')) {
        matrix = step['A'];
      } else if (step.containsKey('L')) {
        matrix = step['L'];
      } else if (step.containsKey('U')) {
        matrix = step['U'];
      } else if (step.containsKey('current_x') || step.containsKey('current_y')) {
        // Skip intermediate vectors for now
        continue;
      } else {
        // No matrix in this step, skip
        continue;
      }
      
      // Create a step object
      String explanation = '';
      if (step.containsKey('permutation')) {
        explanation = 'Permutation: ${step['permutation']}';
      }
      
      result.add(DecompositionStep(
        description: step['description'] ?? 'Matrix operation',
        explanation: explanation,
        matrix: matrix,
        pivotRow: step['pivot_row'],
        pivotCol: step['pivot_col'],
        operationRow: step['operation_row'],
      ));
    }
    
    return result;
  }
  
  // Compute A×x to verify the solution
  static List<double> _computeAxb(List<List<double>> a, List<double> x) {
    final n = a.length;
    final List<double> result = List<double>.filled(n, 0.0);
    
    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int j = 0; j < n; j++) {
        sum += a[i][j] * x[j];
      }
      result[i] = sum;
    }
    
    return result;
  }
  
  // Compute error between two vectors (norm of their difference)
  static double _computeError(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;
    
    double sumSquared = 0.0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sumSquared += diff * diff;
    }
    
    return sqrt(sumSquared);
  }
  
  // Multiply two matrices
  static List<List<double>> _multiplyMatrices(List<List<double>> a, List<List<double>> b) {
    final n = a.length;
    final result = List<List<double>>.generate(
      n, (i) => List<double>.filled(n, 0.0)
    );
    
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        double sum = 0.0;
        for (int k = 0; k < n; k++) {
          sum += a[i][k] * b[k][j];
        }
        result[i][j] = sum;
      }
    }
    
    return result;
  }
  
  // Compute the Frobenius norm of the difference between two matrices
  static double _matrixDifference(List<List<double>> a, List<List<double>> b) {
    final n = a.length;
    double sumSquared = 0.0;
    
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        final diff = a[i][j] - b[i][j];
        sumSquared += diff * diff;
      }
    }
    
    return sqrt(sumSquared);
  }
} 