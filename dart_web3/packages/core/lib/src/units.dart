import 'exceptions.dart';

/// Ethereum unit conversion utilities.
///
/// Provides conversion between wei, gwei, and ether units.
class EthUnit {
  EthUnit._();

  /// 1 ether = 10^18 wei
  static final BigInt weiPerEther = BigInt.parse('1000000000000000000');

  /// 1 gwei = 10^9 wei
  static final BigInt weiPerGwei = BigInt.parse('1000000000');

  /// Converts a string value to wei.
  ///
  /// Example:
  /// ```dart
  /// EthUnit.wei('1000000000000000000'); // 1 ether in wei
  /// ```
  static BigInt wei(String value) {
    return BigInt.parse(value);
  }

  /// Converts a gwei string value to wei.
  ///
  /// Example:
  /// ```dart
  /// EthUnit.gwei('1'); // 1 gwei = 10^9 wei
  /// ```
  static BigInt gwei(String value) {
    return _parseDecimal(value, 9);
  }

  /// Converts an ether string value to wei.
  ///
  /// Example:
  /// ```dart
  /// EthUnit.ether('1.5'); // 1.5 ether in wei
  /// ```
  static BigInt ether(String value) {
    return _parseDecimal(value, 18);
  }

  /// Formats wei to a human-readable wei string.
  static String formatWei(BigInt wei) {
    return wei.toString();
  }

  /// Formats wei to a human-readable gwei string.
  ///
  /// Example:
  /// ```dart
  /// EthUnit.formatGwei(BigInt.from(1000000000)); // '1'
  /// EthUnit.formatGwei(BigInt.from(1500000000)); // '1.5'
  /// ```
  static String formatGwei(BigInt wei) {
    return _formatDecimal(wei, 9);
  }

  /// Formats wei to a human-readable ether string.
  ///
  /// Example:
  /// ```dart
  /// EthUnit.formatEther(BigInt.parse('1000000000000000000')); // '1'
  /// EthUnit.formatEther(BigInt.parse('1500000000000000000')); // '1.5'
  /// ```
  static String formatEther(BigInt wei) {
    return _formatDecimal(wei, 18);
  }

  /// Parses a decimal string with the given number of decimal places.
  static BigInt _parseDecimal(String value, int decimals) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw UnitConversionException('Empty value');
    }

    // Handle negative values
    final isNegative = trimmed.startsWith('-');
    final absValue = isNegative ? trimmed.substring(1) : trimmed;

    // Split into integer and decimal parts
    final parts = absValue.split('.');
    if (parts.length > 2) {
      throw UnitConversionException('Invalid decimal format: $value');
    }

    final integerPart = parts[0].isEmpty ? '0' : parts[0];
    var decimalPart = parts.length > 1 ? parts[1] : '';

    // Validate parts contain only digits
    if (!_isDigits(integerPart) || !_isDigits(decimalPart)) {
      throw UnitConversionException('Invalid number format: $value');
    }

    // Truncate or pad decimal part to match decimals
    if (decimalPart.length > decimals) {
      decimalPart = decimalPart.substring(0, decimals);
    } else {
      decimalPart = decimalPart.padRight(decimals, '0');
    }

    // Combine and parse
    final combined = integerPart + decimalPart;
    final result = BigInt.parse(combined);

    return isNegative ? -result : result;
  }

  /// Formats a BigInt with the given number of decimal places.
  static String _formatDecimal(BigInt value, int decimals) {
    final isNegative = value.isNegative;
    final absValue = isNegative ? -value : value;

    final divisor = BigInt.from(10).pow(decimals);
    final integerPart = absValue ~/ divisor;
    final remainder = absValue % divisor;

    if (remainder == BigInt.zero) {
      return isNegative ? '-$integerPart' : integerPart.toString();
    }

    // Format decimal part with leading zeros
    var decimalPart = remainder.toString().padLeft(decimals, '0');

    // Remove trailing zeros
    decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');

    final result = '$integerPart.$decimalPart';
    return isNegative ? '-$result' : result;
  }

  static bool _isDigits(String s) {
    if (s.isEmpty) return true;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 48 || c > 57) return false; // '0' = 48, '9' = 57
    }
    return true;
  }

  /// Converts between units.
  ///
  /// Example:
  /// ```dart
  /// EthUnit.convert(BigInt.from(1), from: Unit.ether, to: Unit.gwei);
  /// // Returns: 1000000000
  /// ```
  static BigInt convert(BigInt value, {required Unit from, required Unit to}) {
    // Convert to wei first
    final inWei = value * from.weiMultiplier;
    // Then convert to target unit
    return inWei ~/ to.weiMultiplier;
  }
}

/// Ethereum units with their wei multipliers.
///
/// Use [weiMultiplier] to get the conversion factor to wei.
enum Unit {
  wei,
  kwei,
  mwei,
  gwei,
  szabo,
  finney,
  ether;

  /// Returns the wei multiplier for this unit.
  BigInt get weiMultiplier {
    switch (this) {
      case Unit.wei:
        return BigInt.one;
      case Unit.kwei:
        return BigInt.parse('1000'); // 10^3
      case Unit.mwei:
        return BigInt.parse('1000000'); // 10^6
      case Unit.gwei:
        return BigInt.parse('1000000000'); // 10^9
      case Unit.szabo:
        return BigInt.parse('1000000000000'); // 10^12
      case Unit.finney:
        return BigInt.parse('1000000000000000'); // 10^15
      case Unit.ether:
        return BigInt.parse('1000000000000000000'); // 10^18
    }
  }
}
