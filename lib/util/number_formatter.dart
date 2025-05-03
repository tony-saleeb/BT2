import 'dart:math' show pow;

class NumberFormatter {
  /// Formats a number with proper handling of negative signs.
  /// The "-1" will be displayed properly without showing as "?1".
  static String format(double? number, int decimalPlaces, {bool shouldRound = true}) {
    if (number == null) return 'N/A';
    
    // Special case for zero (to avoid -0)
    if (number == 0) return '0';
    
    // Handle negative number by using simple ASCII
    if (number < 0) {
      return "-${_formatPositiveNumber(number.abs(), decimalPlaces, shouldRound)}";
    }
    
    // Otherwise format positive number
    return _formatPositiveNumber(number, decimalPlaces, shouldRound);
  }
  
  static String _formatPositiveNumber(double number, int decimalPlaces, bool shouldRound) {
    // Convert to string with one extra decimal place to check for rounding
    String fullStr = number.toStringAsFixed(decimalPlaces + 1);
    
    // If not rounding, just truncate to desired decimal places
    String result;
    if (!shouldRound) {
      result = fullStr.substring(0, fullStr.length - 1);
    } else {
      // Get the last digit (the one after our desired decimal places)
      int lastDigit = int.parse(fullStr[fullStr.length - 1]);
      
      // Remove the last digit
      String truncated = fullStr.substring(0, fullStr.length - 1);
      
      // If last digit is 5 or greater, round up
      if (lastDigit >= 5) {
        // Convert to double to handle carrying over (e.g., 1.999 -> 2.000)
        double rounded = double.parse(truncated) + (1 / pow(10, decimalPlaces));
        result = rounded.toStringAsFixed(decimalPlaces);
      } else {
        // If last digit is less than 5, just return truncated
        result = truncated;
      }
    }

    // Remove trailing zeros after decimal point
    if (result.contains('.')) {
      while (result.endsWith('0')) {
        result = result.substring(0, result.length - 1);
      }
      // Remove decimal point if it's the last character
      if (result.endsWith('.')) {
        result = result.substring(0, result.length - 1);
      }
    }
    
    return result;
  }
} 