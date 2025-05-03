// ignore_for_file: non_constant_identifier_names

import 'dart:math';
import 'package:flutter/foundation.dart';

class GaussJordanStep {
  final List<List<double>> matrix;
  final String description;
  final int? pivotRow;
  final int? pivotCol;
  final bool isSwap;
  final int? swapRow1;
  final int? swapRow2;

  GaussJordanStep({
    required this.matrix,
    required this.description,
    this.pivotRow,
    this.pivotCol,
    this.isSwap = false,
    this.swapRow1,
    this.swapRow2,
  });

  // Deep copy constructor
  GaussJordanStep.copy(GaussJordanStep other)
      : matrix = List.generate(
          other.matrix.length,
          (i) => List.generate(
            other.matrix[i].length,
            (j) => other.matrix[i][j],
          ),
        ),
        description = other.description,
        pivotRow = other.pivotRow,
        pivotCol = other.pivotCol,
        isSwap = other.isSwap,
        swapRow1 = other.swapRow1,
        swapRow2 = other.swapRow2;
}

class GaussJordanResult {
  final List<double> solution;
  final List<GaussJordanStep> steps;
  final bool isSolved;
  final String? errorMessage;
  final List<List<double>> originalMatrix;
  final List<List<double>> finalMatrix;

  GaussJordanResult({
    required this.solution,
    required this.steps,
    required this.isSolved,
    this.errorMessage,
    required this.originalMatrix,
    required this.finalMatrix,
  });
}

class GaussJordanMethod {
  /// Solves a system of linear equations using the Gauss-Jordan elimination method.
  ///
  /// The [coefficientMatrix] is an n×n matrix of coefficients.
  /// The [constantVector] is a vector of length n containing the constant terms.
  ///
  /// If [usePartialPivoting] is true, the method will use partial pivoting to improve numerical stability.
  static GaussJordanResult solve({
    required List<List<double>> coefficientMatrix,
    required List<double> constantVector,
    bool usePartialPivoting = true,
  }) {
    try {
      // Validate input
      final n = coefficientMatrix.length;
      if (n == 0) {
        return GaussJordanResult(
          solution: [],
          steps: [],
          isSolved: false,
          errorMessage: 'Coefficient matrix is empty',
          originalMatrix: [],
          finalMatrix: [],
        );
      }

      // Check if matrix is square
      for (final row in coefficientMatrix) {
        if (row.length != n) {
          return GaussJordanResult(
            solution: [],
            steps: [],
            isSolved: false,
            errorMessage: 'Coefficient matrix must be square',
            originalMatrix: coefficientMatrix,
            finalMatrix: [],
          );
        }
      }

      // Check constant vector length
      if (constantVector.length != n) {
        return GaussJordanResult(
          solution: [],
          steps: [],
          isSolved: false,
          errorMessage:
              'Constant vector length must match coefficient matrix size',
          originalMatrix: coefficientMatrix,
          finalMatrix: [],
        );
      }

      // Debug prints for input validation
      print('Input validation passed');
      print('Coefficient matrix: $coefficientMatrix');
      print('Constant vector: $constantVector');

      // Check for all-zero rows in coefficient matrix
      for (int i = 0; i < n; i++) {
        bool allZeros = true;
        for (int j = 0; j < n; j++) {
          if (coefficientMatrix[i][j].abs() > 1e-10) {
            allZeros = false;
            break;
          }
        }
        if (allZeros) {
          print('All-zero row detected at row $i');
          return GaussJordanResult(
            solution: [],
            steps: [],
            isSolved: false,
            errorMessage: 'Matrix has an all-zero row (row ${i+1}), making it singular',
            originalMatrix: coefficientMatrix,
            finalMatrix: [],
          );
        }
      }

      // Create augmented matrix with deep copy to avoid modifying original data
      final augmentedMatrix = List.generate(n, (i) {
        final row = List<double>.from(coefficientMatrix[i]);
        row.add(constantVector[i]);
        return row;
      });

      // Create deep copies for original matrix 
      final originalAugmentedMatrix =
          List.generate(n, (i) => List<double>.from(augmentedMatrix[i]));
      
      // Process solution
      final result = _solveGaussJordan(
        augmentedMatrix: augmentedMatrix,
        usePartialPivoting: usePartialPivoting,
      );

      print('Result from solver: isSolved=${result.isSolved}, steps=${result.steps.length}');
      if (!result.isSolved) {
        print('Error message: ${result.errorMessage}');
      }

      // Extract solution vector
      if (result.isSolved && result.steps.isNotEmpty) {
        // Final matrix for verification
        final finalMatrix = result.steps.last.matrix;
        
        // Extract solution
        final solution = List<double>.filled(n, 0.0);
        for (int i = 0; i < n; i++) {
          solution[i] = finalMatrix[i][n];
        }

        print('Extracted solution: $solution');

        // Verify the solution by substituting back
        bool solutionValid = true;
        for (int i = 0; i < n; i++) {
          double sum = 0.0;
          for (int j = 0; j < n; j++) {
            sum += coefficientMatrix[i][j] * solution[j];
          }
          double diff = (sum - constantVector[i]).abs();
          if (diff > 1e-8) {
            print('Solution validation issue at row $i: computed=$sum, expected=${constantVector[i]}, diff=$diff');
            if (diff > 1e-5) {
              solutionValid = false;
            }
          }
        }

        if (!solutionValid) {
          print('Solution validation failed - solution may be incorrect');
        } else {
          print('Solution validated successfully');
        }

        return GaussJordanResult(
          solution: solution,
          steps: result.steps,
          isSolved: true,
          originalMatrix: originalAugmentedMatrix,
          finalMatrix: finalMatrix,
        );
      } else {
        return GaussJordanResult(
          solution: [],
          steps: result.steps,
          isSolved: false,
          errorMessage: result.errorMessage ?? 'Failed to find a valid solution',
          originalMatrix: originalAugmentedMatrix,
          finalMatrix: result.steps.isNotEmpty ? result.steps.last.matrix : [],
        );
      }
    } catch (e) {
      // Handle exceptions
      print('Exception in Gauss-Jordan solve: ${e.toString()}');
      return GaussJordanResult(
        solution: [],
        steps: [],
        isSolved: false,
        errorMessage: 'Error solving system: ${e.toString()}',
        originalMatrix: coefficientMatrix,
        finalMatrix: [],
      );
    }
  }

  /// Internal method to perform Gauss-Jordan elimination
  static GaussJordanResult _solveGaussJordan({
    required List<List<double>> augmentedMatrix,
    required bool usePartialPivoting,
  }) {
    try {
      final n = augmentedMatrix.length;
      final steps = <GaussJordanStep>[];

      // Deep copy of original matrix for initial step
      final initialMatrix = List.generate(
        n,
        (i) => List<double>.from(augmentedMatrix[i]),
      );

      print('Starting Gauss-Jordan elimination with matrix size: $n x ${n+1}');

      // Add initial step
      steps.add(
        GaussJordanStep(
          matrix: initialMatrix,
          description: 'Initial augmented matrix',
        ),
      );

      // Main elimination loop - Gauss-Jordan method processes one column at a time
      for (int pivot = 0; pivot < n; pivot++) {
        print('Processing pivot $pivot');
        
        // Find pivot with partial pivoting if enabled
        int maxRow = pivot;
        
        if (usePartialPivoting) {
          double maxValue = augmentedMatrix[maxRow][pivot].abs();
          for (int i = pivot + 1; i < n; i++) {
            double value = augmentedMatrix[i][pivot].abs();
            if (value > maxValue) {
              maxValue = value;
              maxRow = i;
            }
          }
          print('Selected pivot row: $maxRow with value: ${augmentedMatrix[maxRow][pivot]}');
        }

        // Check for singularity with better precision check
        if (augmentedMatrix[maxRow][pivot].abs() < 1e-10) {
          print('Near-zero pivot detected: ${augmentedMatrix[maxRow][pivot]}');
          
          // Try to check if the system is underdetermined or inconsistent
          bool isConsistent = true;
          // Check if the row has all zeros except for the constant
          bool allZerosExceptConstant = true;
          for (int j = 0; j < n; j++) {
            if (augmentedMatrix[maxRow][j].abs() >= 1e-10) {
              allZerosExceptConstant = false;
              break;
            }
          }
          
          // If the constant is not zero but all coefficients are, it's inconsistent
          if (allZerosExceptConstant && augmentedMatrix[maxRow][n].abs() >= 1e-10) {
            isConsistent = false;
            print('Inconsistent system detected');
          }
          
          if (!isConsistent) {
            return GaussJordanResult(
              solution: [],
              steps: steps,
              isSolved: false,
              errorMessage: 'System is inconsistent - no solution exists',
              originalMatrix: steps.first.matrix,
              finalMatrix: steps.last.matrix,
            );
          } else {
            return GaussJordanResult(
              solution: [],
              steps: steps,
              isSolved: false,
              errorMessage: 'Matrix is singular - cannot find a unique solution',
              originalMatrix: steps.first.matrix,
              finalMatrix: steps.last.matrix,
            );
          }
        }

        // Swap rows if needed
        if (maxRow != pivot) {
          print('Swapping rows $pivot and $maxRow');
          final temp = augmentedMatrix[pivot];
          augmentedMatrix[pivot] = augmentedMatrix[maxRow];
          augmentedMatrix[maxRow] = temp;

          // Add step for row swap
          steps.add(
            GaussJordanStep(
              matrix: List.generate(
                n,
                (i) => List<double>.from(augmentedMatrix[i]),
              ),
              description: 'Swap row ${pivot + 1} with row ${maxRow + 1} for better pivot',
              isSwap: true,
              swapRow1: pivot,
              swapRow2: maxRow,
            ),
          );
        }

        // Scale pivot row to make pivot element 1
        final pivotValue = augmentedMatrix[pivot][pivot];
        print('Scaling row $pivot by dividing with $pivotValue');
        
        // Additional check for small pivots
        if (pivotValue.abs() < 1e-10) {
          return GaussJordanResult(
            solution: [],
            steps: steps,
            isSolved: false,
            errorMessage: 'Division by near-zero value encountered - matrix is singular',
            originalMatrix: steps.first.matrix,
            finalMatrix: steps.last.matrix,
          );
        }
        
        for (int j = 0; j <= n; j++) {
          augmentedMatrix[pivot][j] /= pivotValue;
          
          // Handle -0.0 to 0.0 conversion for cleaner display
          if (augmentedMatrix[pivot][j].abs() < 1e-12) {
            augmentedMatrix[pivot][j] = 0.0;
          }
        }

        // Add step for normalizing pivot row
        steps.add(
          GaussJordanStep(
            matrix: List.generate(
              n,
              (i) => List<double>.from(augmentedMatrix[i]),
            ),
            description: 'Scale row ${pivot + 1} to make pivot element 1',
            pivotRow: pivot,
            pivotCol: pivot,
          ),
        );

        // Main Gauss-Jordan elimination - Make zeros in ALL rows for this column, not just below
        print('Eliminating elements in column $pivot for all rows');
        for (int i = 0; i < n; i++) {
          if (i != pivot) {
            final factor = augmentedMatrix[i][pivot];
            for (int j = 0; j <= n; j++) { // Process all columns including constants
              augmentedMatrix[i][j] -= factor * augmentedMatrix[pivot][j];
              
              // Handle -0.0 to 0.0 conversion
              if (augmentedMatrix[i][j].abs() < 1e-12) {
                augmentedMatrix[i][j] = 0.0;
              }
            }
          }
        }

        // Add step for elimination
        steps.add(
          GaussJordanStep(
            matrix: List.generate(
              n,
              (i) => List<double>.from(augmentedMatrix[i]),
            ),
            description: 'Eliminate all other elements in column ${pivot + 1}',
            pivotRow: pivot,
            pivotCol: pivot,
          ),
        );
      }

      // Verify diagonal is all ones
      for (int i = 0; i < n; i++) {
        if ((augmentedMatrix[i][i] - 1.0).abs() > 1e-10) {
          print('Error: Diagonal element at position $i is not 1: ${augmentedMatrix[i][i]}');
          return GaussJordanResult(
            solution: [],
            steps: steps,
            isSolved: false,
            errorMessage: 'Failed to reduce matrix to proper form',
            originalMatrix: steps.first.matrix,
            finalMatrix: steps.last.matrix,
          );
        }
      }

      // Extract solution vector and perform checks
      final solution = List<double>.filled(n, 0.0);
      print('Extracting solution from final matrix');
      
      for (int i = 0; i < n; i++) {
        // Final sanity check on the solution row
        if ((augmentedMatrix[i][i] - 1.0).abs() > 1e-10) {
          print('Warning: Diagonal element at position $i is not exactly 1: ${augmentedMatrix[i][i]}');
        }
        
        solution[i] = augmentedMatrix[i][n];
        print('Solution[$i] = ${solution[i]}');
      }

      // Add final step with description
      steps.add(
        GaussJordanStep(
          matrix: List.generate(
            n,
            (i) => List<double>.from(augmentedMatrix[i]),
          ),
          description: 'Final reduced row echelon form (solution ready)',
        ),
      );

      print('Gauss-Jordan elimination completed successfully');
      return GaussJordanResult(
        solution: solution,
        steps: steps,
        isSolved: true,
        originalMatrix: steps.first.matrix,
        finalMatrix: steps.last.matrix,
      );
    } catch (e) {
      print('Error in Gauss-Jordan solution: ${e.toString()}');
      print('Stack trace: ${StackTrace.current}');
      return GaussJordanResult(
        solution: [],
        steps: [],
        isSolved: false,
        errorMessage: 'Error during calculation: ${e.toString()}',
        originalMatrix: [],
        finalMatrix: [],
      );
    }
  }
} 