# Numerical Algorithms

This section provides detailed documentation for the numerical algorithms implemented in the application.

## Table of Contents

1. [Root Finding Methods](#root-finding-methods)
   - [Bisection Method](#bisection-method)
   - [False Position Method](#false-position-method)
   - [Simple Fixed Point Method](#simple-fixed-point-method)
   - [Newton Method](#newton-method)
   - [Secant Method](#secant-method)
2. [Linear Algebra Methods](#linear-algebra-methods)
   - [Gauss Elimination Method](#gauss-elimination-method)
   - [LU Decomposition Method](#lu-decomposition-method)
   - [Gauss Jordan Method](#gauss-jordan-method)
   - [Cramer Method](#cramer-method)

## Root Finding Methods

### Bisection Method

**Mathematical Background:**

The bisection method is a root-finding method that repeatedly bisects an interval and then selects a subinterval in which a root must lie for further processing.

**Algorithm:**

1. Start with an interval [a, b] where f(a) and f(b) have opposite signs (indicating a root exists between them)
2. Compute the midpoint c = (a + b) / 2
3. Evaluate f(c)
4. If f(c) is close enough to zero, return c as the root
5. If f(c) has the same sign as f(a), update a = c; otherwise, update b = c
6. Repeat steps 2-5 until convergence

**Implementation:**

See `bisection_method.dart` for the full implementation.

### False Position Method

**Mathematical Background:**

The false position method (or regula falsi) is a root-finding algorithm that uses linear interpolation to find improved approximations to the roots of a function.

**Algorithm:**

1. Start with an interval [a, b] where f(a) and f(b) have opposite signs
2. Find the x-intercept of the secant line through (a, f(a)) and (b, f(b))
3. Evaluate the function at this point
4. Determine the new interval based on the sign of the function
5. Repeat until convergence

**Implementation:**

See `false_position_method.dart` for the full implementation.

### Simple Fixed Point Method

**Mathematical Background:**

The fixed point method finds solutions to the equation x = g(x), which is equivalent to finding roots of f(x) = x - g(x) = 0.

**Algorithm:**

1. Rewrite the equation f(x) = 0 as x = g(x)
2. Choose an initial approximation x₀
3. Compute x₁ = g(x₀), x₂ = g(x₁), ...
4. Continue until |xₙ₊₁ - xₙ| is less than the specified tolerance

**Implementation:**

See `simple_fixed_point_method.dart` for the full implementation.

### Newton Method

**Mathematical Background:**

Newton's method (also known as the Newton-Raphson method) uses derivative information to find better approximations to the roots of a function.

**Algorithm:**

1. Start with an initial guess x₀
2. Calculate x₁ = x₀ - f(x₀)/f'(x₀)
3. Continue calculating xₙ₊₁ = xₙ - f(xₙ)/f'(xₙ) until convergence

**Implementation:**

See `newton_method.dart` for the full implementation.

### Secant Method

**Mathematical Background:**

The secant method is similar to Newton's method but doesn't require calculating derivatives. It uses a finite difference approximation of the derivative.

**Algorithm:**

1. Start with two initial points x₀ and x₁
2. Calculate x₂ = x₁ - f(x₁)(x₁ - x₀)/(f(x₁) - f(x₀))
3. Continue calculating new points until convergence

**Implementation:**

See `secant_method.dart` for the full implementation.

## Linear Algebra Methods

### Gauss Elimination Method

**Mathematical Background:**

Gauss elimination is a method for solving systems of linear equations by converting the augmented matrix to row echelon form.

**Algorithm:**

1. Form the augmented matrix [A|b]
2. Perform row operations to transform the matrix to row echelon form
3. Use back substitution to find the solution

**Implementation:**

See `gauss_elimination_method.dart` for the full implementation.

### LU Decomposition Method

**Mathematical Background:**

LU decomposition factors a matrix as the product of a lower triangular matrix (L) and an upper triangular matrix (U).

**Algorithm:**

1. Factor matrix A into L and U matrices where A = LU
2. Solve Ly = b using forward substitution
3. Solve Ux = y using back substitution

**Implementation:**

See `lu_decomposition_method.dart` for the full implementation.

### Gauss Jordan Method

**Mathematical Background:**

Gauss-Jordan elimination extends Gauss elimination by continuing the row operations to convert the matrix to reduced row echelon form.

**Algorithm:**

1. Form the augmented matrix [A|b]
2. Perform row operations to transform the matrix to reduced row echelon form
3. Read off the solution directly

**Implementation:**

See `gauss_jordan_method.dart` for the full implementation.

### Cramer Method

**Mathematical Background:**

Cramer's rule uses determinants to solve a system of linear equations.

**Algorithm:**

1. Calculate the determinant of the coefficient matrix A
2. For each variable, replace the corresponding column in A with the constant vector b
3. Calculate the determinant of each modified matrix
4. The value of each variable is the ratio of the corresponding modified determinant to the original determinant

**Implementation:**

See `cramer_method.dart` for the full implementation. 