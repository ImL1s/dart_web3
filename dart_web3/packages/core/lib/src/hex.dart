import 'dart:typed_data';

import 'exceptions.dart';

/// Utilities for hexadecimal encoding and decoding.
class HexUtils {
  HexUtils._();

  static const String _hexChars = '0123456789abcdef';

  /// Encodes bytes to a hexadecimal string.
  ///
  /// If [prefix] is true (default), the result will be prefixed with '0x'.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.encode(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]));
  /// // Returns: '0xdeadbeef'
  /// ```
  static String encode(Uint8List bytes, {bool prefix = true}) {
    final buffer = StringBuffer();
    if (prefix) buffer.write('0x');

    for (final byte in bytes) {
      buffer.write(_hexChars[(byte >> 4) & 0x0f]);
      buffer.write(_hexChars[byte & 0x0f]);
    }

    return buffer.toString();
  }

  /// Decodes a hexadecimal string to bytes.
  ///
  /// The input can optionally have a '0x' prefix.
  ///
  /// Throws [HexException] if the input is not valid hex.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.decode('0xdeadbeef');
  /// // Returns: Uint8List [0xde, 0xad, 0xbe, 0xef]
  /// ```
  static Uint8List decode(String hex) {
    var data = hex;

    // Remove 0x prefix if present
    if (data.startsWith('0x') || data.startsWith('0X')) {
      data = data.substring(2);
    }

    // Handle empty string
    if (data.isEmpty) {
      return Uint8List(0);
    }

    // Validate hex string
    if (!_isValidHex(data)) {
      throw HexException('Invalid hex string: $hex');
    }

    // Pad with leading zero if odd length
    if (data.length.isOdd) {
      data = '0$data';
    }

    final result = Uint8List(data.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      final byteStr = data.substring(i * 2, i * 2 + 2);
      result[i] = int.parse(byteStr, radix: 16);
    }

    return result;
  }

  /// Checks if a string is a valid hexadecimal string.
  ///
  /// The input can optionally have a '0x' prefix.
  static bool isValid(String hex) {
    var data = hex;

    if (data.startsWith('0x') || data.startsWith('0X')) {
      data = data.substring(2);
    }

    if (data.isEmpty) return true;

    return _isValidHex(data);
  }

  static bool _isValidHex(String hex) {
    for (var i = 0; i < hex.length; i++) {
      final char = hex[i].toLowerCase();
      if (!((char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || // 0-9
          (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 102))) {
        // a-f
        return false;
      }
    }
    return true;
  }

  /// Strips the '0x' prefix from a hex string if present.
  static String strip0x(String hex) {
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      return hex.substring(2);
    }
    return hex;
  }

  /// Adds the '0x' prefix to a hex string if not present.
  static String add0x(String hex) {
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      return hex;
    }
    return '0x$hex';
  }

  /// Pads a hex string to a specific byte length.
  ///
  /// If [left] is true (default), pads on the left side.
  static String pad(String hex, int byteLength, {bool left = true}) {
    final stripped = strip0x(hex);
    final targetLength = byteLength * 2;

    if (stripped.length >= targetLength) {
      return add0x(stripped);
    }

    final padding = '0' * (targetLength - stripped.length);
    return left ? add0x(padding + stripped) : add0x(stripped + padding);
  }
}
