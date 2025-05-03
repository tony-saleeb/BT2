enum MethodCategory {
  rootFinding,
  linearAlgebra,
}

class NumericalMethod {
  final String name;
  final MethodCategory category;
  final int chapter;
  final String tag;
  final String description;

  const NumericalMethod({
    required this.name,
    required this.category,
    required this.chapter,
    required this.tag,
    required this.description,
  });

  static List<NumericalMethod> get methods => [
    // Chapter 1 - Root Finding Methods
    const NumericalMethod(
      name: 'Bisection Method',
      category: MethodCategory.rootFinding,
      chapter: 1,
      tag: 'ROOT FINDING',
      description: 'Find roots of equations by repeatedly dividing intervals in half and determining which half contains the root.',
    ),
    const NumericalMethod(
      name: 'False Position Method',
      category: MethodCategory.rootFinding,
      chapter: 1,
      tag: 'ROOT FINDING',
      description: 'An improved version of bisection method that uses linear interpolation to find better approximations.',
    ),
    const NumericalMethod(
      name: 'Simple Fixed Point Method',
      category: MethodCategory.rootFinding,
      chapter: 1,
      tag: 'ROOT FINDING',
      description: 'Find roots by iteratively applying a function until convergence is achieved.',
    ),
    const NumericalMethod(
      name: 'Newton Method',
      category: MethodCategory.rootFinding,
      chapter: 1,
      tag: 'ROOT FINDING',
      description: 'Uses function derivatives to find increasingly accurate approximations to roots.',
    ),
    const NumericalMethod(
      name: 'Secant Method',
      category: MethodCategory.rootFinding,
      chapter: 1,
      tag: 'ROOT FINDING',
      description: 'A variation of Newton\'s method that approximates derivatives using two points.',
    ),

    // Chapter 2 - Linear Algebra Methods
    const NumericalMethod(
      name: 'Gauss Elimination Method',
      category: MethodCategory.linearAlgebra,
      chapter: 2,
      tag: 'LINEAR ALGEBRA',
      description: 'Solve systems of linear equations by converting to row echelon form.',
    ),
    const NumericalMethod(
      name: 'LU Decomposition Method',
      category: MethodCategory.linearAlgebra,
      chapter: 2,
      tag: 'LINEAR ALGEBRA',
      description: 'Factorize a matrix into lower and upper triangular matrices for efficient solving.',
    ),
    const NumericalMethod(
      name: 'Gauss Jordan Method',
      category: MethodCategory.linearAlgebra,
      chapter: 2,
      tag: 'LINEAR ALGEBRA',
      description: 'An extension of Gauss Elimination that continues to reduced row echelon form.',
    ),
    const NumericalMethod(
      name: 'Cramer Method',
      category: MethodCategory.linearAlgebra,
      chapter: 2,
      tag: 'LINEAR ALGEBRA',
      description: 'Uses determinants to solve systems of linear equations.',
    ),
  ];

  static List<NumericalMethod> getMethodsForChapter(int chapter) {
    return methods.where((method) => method.chapter == chapter).toList();
  }
} 