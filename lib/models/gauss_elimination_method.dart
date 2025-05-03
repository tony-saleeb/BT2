// ignore_for_file: non_constant_identifier_names

import 'dart:math';

class GaussEliminationResult {
  final List<List<double>> originalMatrix;
  final List<List<List<double>>> steps;
  final List<double> solution;
  final Map<String, dynamic> debug;
  final bool isSolved;
  final String? errorMessage;

  GaussEliminationResult({
    required this.originalMatrix,
    required this.steps,
    required this.solution,
    required this.debug,
    required this.isSolved,
    this.errorMessage,
  });
}

class GaussEliminationStep {
  final int pivot_row;
  final int pivot_col;
  final List<List<double>> matrix;
  final List<double>? multipliers;
  final String description;

  GaussEliminationStep({
    required this.pivot_row,
    required this.pivot_col,
    required this.matrix,
    this.multipliers,
    required this.description,
  });
}

class GaussEliminationMethod {
  // Solve a system of linear equations using Gauss Elimination with multipliers
  static GaussEliminationResult solve({
    required List<List<double>> coefficients,
    required List<double> constants,
    required bool useMultipliers,
    bool usePartialPivoting = true,
    int decimalPlaces = 4,
  }) {
    try {
      // Check if system is valid
      if (coefficients.isEmpty) {
        return GaussEliminationResult(
          originalMatrix: [],
          steps: [],
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
          return GaussEliminationResult(
            originalMatrix: List<List<double>>.from(coefficients),
            steps: [],
            solution: [],
            debug: {},
            isSolved: false,
            errorMessage: "Inconsistent number of coefficients in rows",
          );
        }
      }

      // Check if constants array matches number of equations
      if (constants.length != numRows) {
        return GaussEliminationResult(
          originalMatrix: List<List<double>>.from(coefficients),
          steps: [],
          solution: [],
          debug: {},
          isSolved: false,
          errorMessage: "Number of constants doesn't match number of equations",
        );
      }

      // For square systems, check if we have enough equations
      if (numRows < numCols) {
        return GaussEliminationResult(
          originalMatrix: List<List<double>>.from(coefficients),
          steps: [],
          solution: [],
          debug: {},
          isSolved: false,
          errorMessage: "Underdetermined system: more variables than equations",
        );
      }

      // Create the augmented matrix [A|b]
      final augmentedMatrix = _createAugmentedMatrix(coefficients, constants);
      final originalMatrix = List<List<double>>.from(
        augmentedMatrix.map((row) => List<double>.from(row))
      );

      // Store computation steps
      final List<Map<String, dynamic>> computationSteps = [];
      
      // Perform Forward Elimination
      final forwardEliminationResult = _forwardElimination(
        augmentedMatrix: augmentedMatrix,
        useMultipliers: useMultipliers,
        usePartialPivoting: usePartialPivoting,
        decimalPlaces: decimalPlaces,
      );
      
      if (!forwardEliminationResult['success']) {
        return GaussEliminationResult(
          originalMatrix: originalMatrix,
          steps: [],
          solution: [],
          debug: {'computation_steps': computationSteps},
          isSolved: false,
          errorMessage: forwardEliminationResult['error'],
        );
      }

      computationSteps.addAll(forwardEliminationResult['steps']);
      final upperTriangularMatrix = forwardEliminationResult['matrix'];

      // Perform Back Substitution
      final backSubstitutionResult = _backSubstitution(
        upperTriangularMatrix: upperTriangularMatrix,
        decimalPlaces: decimalPlaces,
      );
      
      if (!backSubstitutionResult['success']) {
        return GaussEliminationResult(
          originalMatrix: originalMatrix,
          steps: [],
          solution: [],
          debug: {'computation_steps': computationSteps},
          isSolved: false,
          errorMessage: backSubstitutionResult['error'],
        );
      }

      computationSteps.addAll(backSubstitutionResult['steps']);
      final solution = backSubstitutionResult['solution'];

      // Extract just the matrix part for each step (exclude explanations)
      final List<List<List<double>>> stepMatrices = computationSteps
          .map((step) => List<List<double>>.from(
            (step['matrix'] as List).map((row) => List<double>.from(row))
          ))
          .toList();

      return GaussEliminationResult(
        originalMatrix: originalMatrix,
        steps: stepMatrices,
        solution: solution,
        debug: {'computation_steps': computationSteps},
        isSolved: true,
      );
    } catch (e) {
      return GaussEliminationResult(
        originalMatrix: [],
        steps: [],
        solution: [],
        debug: {},
        isSolved: false,
        errorMessage: "Error: ${e.toString()}",
      );
    }
  }

  // Create augmented matrix [A|b]
  static List<List<double>> _createAugmentedMatrix(
    List<List<double>> coefficients,
    List<double> constants,
  ) {
    final numRows = coefficients.length;
    final augmentedMatrix = List<List<double>>.generate(
      numRows,
      (i) => List<double>.from(coefficients[i])..add(constants[i]),
    );
    return augmentedMatrix;
  }

  // Forward elimination phase
  static Map<String, dynamic> _forwardElimination({
    required List<List<double>> augmentedMatrix,
    required bool useMultipliers,
    required bool usePartialPivoting,
    required int decimalPlaces,
  }) {
    final numRows = augmentedMatrix.length;
    final numCols = augmentedMatrix[0].length;
    final List<Map<String, dynamic>> steps = [];
    final List<List<double>> matrix = List<List<double>>.from(
      augmentedMatrix.map((row) => List<double>.from(row))
    );

    try {
      // Add initial state as the first step
      steps.add({
        'matrix': List<List<double>>.from(
          matrix.map((row) => List<double>.from(row))
        ),
        'description': 'Initial augmented matrix',
        'pivot_row': -1,
        'pivot_col': -1,
      });

      // Main loop for Gaussian elimination
      for (int k = 0; k < min(numRows, numCols - 1); k++) {
        // Find pivot
        int pivotRow = k;
        
        // Partial pivoting (find maximum element in column k)
        if (usePartialPivoting) {
          for (int i = k + 1; i < numRows; i++) {
            if (matrix[i][k].abs() > matrix[pivotRow][k].abs()) {
              pivotRow = i;
            }
          }
        }

        // Check if the pivot is too small (matrix might be singular)
        if (matrix[pivotRow][k].abs() < 1e-10) {
          return {
            'success': false,
            'error': 'Matrix is singular or nearly singular.',
            'steps': steps,
          };
        }

        // Swap rows if needed
        if (pivotRow != k) {
          // Swap rows k and pivotRow
          final temp = matrix[k];
          matrix[k] = matrix[pivotRow];
          matrix[pivotRow] = temp;

          steps.add({
            'matrix': List<List<double>>.from(
              matrix.map((row) => List<double>.from(row))
            ),
            'description': 'Swap rows $k and $pivotRow',
            'pivot_row': k,
            'pivot_col': k,
          });
        }

        // Eliminate entries below the pivot
        for (int i = k + 1; i < numRows; i++) {
          final List<double> multipliers = [];
          
          double multiplier = matrix[i][k] / matrix[k][k];
          // Round the multiplier to avoid floating-point issues
          multiplier = double.parse(multiplier.toStringAsFixed(decimalPlaces));
          multipliers.add(multiplier);

          // Subtract: row[i] = row[i] - multiplier * row[k]
          for (int j = k; j < numCols; j++) {
            matrix[i][j] -= multiplier * matrix[k][j];
            // Round the result to avoid floating-point issues
            matrix[i][j] = double.parse(matrix[i][j].toStringAsFixed(decimalPlaces));
          }

          // Add a specific step for this row operation
          steps.add({
            'matrix': List<List<double>>.from(
              matrix.map((row) => List<double>.from(row))
            ),
            'description': 'R${i+1} = R${i+1} - (${multiplier.toStringAsFixed(decimalPlaces)} * R${k+1})',
            'pivot_row': k,
            'pivot_col': k,
            'operation_row': i,
            'multiplier': multiplier,
            'operation_type': 'row_elimination',
          });
        }

        // Only add a summary step if we didn't add individual row steps
        if (k + 1 >= numRows) {
          steps.add({
            'matrix': List<List<double>>.from(
              matrix.map((row) => List<double>.from(row))
            ),
            'description': 'Eliminate entries below pivot in column $k',
            'pivot_row': k,
            'pivot_col': k,
            'operation_type': 'pivot_complete',
          });
        }
      }

      return {
        'success': true,
        'matrix': matrix,
        'steps': steps,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error during forward elimination: ${e.toString()}',
        'steps': steps,
      };
    }
  }

  // Back substitution phase
  static Map<String, dynamic> _backSubstitution({
    required List<List<double>> upperTriangularMatrix,
    required int decimalPlaces,
  }) {
    final numRows = upperTriangularMatrix.length;
    final numCols = upperTriangularMatrix[0].length;
    final numVars = numCols - 1; // Last column is constants
    final List<double> solution = List.filled(numVars, 0.0);
    final List<Map<String, dynamic>> steps = [];

    try {
      // Solve from bottom to top
      for (int i = numRows - 1; i >= 0; i--) {
        double sum = 0.0;
        for (int j = i + 1; j < numVars; j++) {
          sum += upperTriangularMatrix[i][j] * solution[j];
        }
        
        // Check for zero coefficient of the current variable
        if (upperTriangularMatrix[i][i].abs() < 1e-10) {
          return {
            'success': false,
            'error': 'Division by zero during back substitution.',
            'steps': steps,
          };
        }
        
        solution[i] = (upperTriangularMatrix[i][numCols - 1] - sum) / upperTriangularMatrix[i][i];
        // Round the solution to avoid floating-point issues
        solution[i] = double.parse(solution[i].toStringAsFixed(decimalPlaces));
        
        steps.add({
          'matrix': List<List<double>>.from(upperTriangularMatrix),
          'description': 'Calculate x_$i = ${solution[i].toStringAsFixed(decimalPlaces)}',
          'variable': i,
          'value': solution[i],
        });
      }

      return {
        'success': true,
        'solution': solution,
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
} 