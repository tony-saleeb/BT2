
class CramerStep {
  final List<List<double>> determinantMatrix;
  final int variableIndex;
  final double determinantValue;
  final String description;

  CramerStep({
    required this.determinantMatrix,
    required this.variableIndex,
    required this.determinantValue,
    required this.description,
  });
}

class CramerResult {
  final bool isSolved;
  final List<double>? solution;
  final String? errorMessage;
  final List<List<double>> originalMatrix;
  final List<double> constants;
  final double systemDeterminant;
  final List<CramerStep> steps;

  CramerResult({
    required this.isSolved,
    this.solution,
    this.errorMessage,
    required this.originalMatrix,
    required this.constants,
    required this.systemDeterminant,
    required this.steps,
  });
}

class CramerMethod {
  /// Calculates the determinant of a square matrix using the Laplace expansion
  static double calculateDeterminant(List<List<double>> matrix) {
    int n = matrix.length;
    
    // Base case for 1x1 matrix
    if (n == 1) return matrix[0][0];
    
    // Base case for 2x2 matrix
    if (n == 2) {
      return matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
    }
    
    double determinant = 0;
    int sign = 1;
    
    // Expand along first row
    for (int j = 0; j < n; j++) {
      determinant += sign * matrix[0][j] * _cofactor(matrix, 0, j);
      sign = -sign;
    }
    
    return determinant;
  }
  
  /// Calculates the cofactor of matrix[i][j]
  static double _cofactor(List<List<double>> matrix, int row, int col) {
    return calculateDeterminant(_minor(matrix, row, col));
  }
  
  /// Returns the minor matrix by removing the specified row and column
  static List<List<double>> _minor(List<List<double>> matrix, int row, int col) {
    int n = matrix.length;
    List<List<double>> minor = List.generate(
      n - 1,
      (i) => List<double>.filled(n - 1, 0),
    );
    
    int r = 0;
    for (int i = 0; i < n; i++) {
      if (i == row) continue;
      int c = 0;
      for (int j = 0; j < n; j++) {
        if (j == col) continue;
        minor[r][c] = matrix[i][j];
        c++;
      }
      r++;
    }
    
    return minor;
  }
  
  /// Creates a copy of the matrix with a column replaced by the constants vector
  static List<List<double>> _replaceColumn(
    List<List<double>> matrix,
    List<double> column,
    int colIndex,
  ) {
    List<List<double>> result = List.generate(
      matrix.length,
      (i) => List<double>.from(matrix[i]),
    );
    
    for (int i = 0; i < matrix.length; i++) {
      result[i][colIndex] = column[i];
    }
    
    return result;
  }
  
  /// Solves a system of linear equations using Cramer's rule
  /// Returns a map containing:
  // ignore: unintended_html_in_doc_comment
  /// - 'solution': List<double> containing the solution vector [x1, x2, x3, ...]
  // ignore: unintended_html_in_doc_comment
  /// - 'determinants': Map<String, double> containing the determinants used in calculation
  // ignore: unintended_html_in_doc_comment
  /// - 'steps': List<String> containing the solution steps for display
  static Map<String, dynamic> solve({
    required List<List<double>> coefficients,
    required List<double> constants,
  }) {
    int n = coefficients.length;
    List<double> solution = List<double>.filled(n, 0);
    Map<String, double> determinants = {};
    List<String> steps = [];
    
    // Calculate system determinant (D)
    double D = calculateDeterminant(coefficients);
    determinants['D'] = D;
    steps.add('System determinant (D) = $D');
    
    if (D == 0) {
      steps.add('The system has no unique solution (determinant is zero)');
      return {
        'solution': solution,
        'determinants': determinants,
        'steps': steps,
      };
    }
    
    // Calculate determinants for each variable
    for (int i = 0; i < n; i++) {
      List<List<double>> modifiedMatrix = _replaceColumn(
        coefficients,
        constants,
        i,
      );
      // ignore: non_constant_identifier_names
      double Di = calculateDeterminant(modifiedMatrix);
      determinants['D${i + 1}'] = Di;
      solution[i] = Di / D;
      steps.add('D${i + 1} = $Di');
      steps.add('x${i + 1} = D${i + 1}/D = ${solution[i]}');
    }
    
    return {
      'solution': solution,
      'determinants': determinants,
      'steps': steps,
    };
  }
} 