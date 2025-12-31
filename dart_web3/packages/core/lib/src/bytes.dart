import 'dart:typed_data';

/// Utilities for byte array manipulation.
class BytesUtils {
  BytesUtils._();

  /// Concatenates multiple byte arrays into one.
  ///
  /// Example:
  /// ```dart
  /// BytesUtils.concat([
  ///   Uint8List.fromList([1, 2]),
  ///   Uint8List.fromList([3, 4]),
  /// ]);
  /// // Returns: Uint8List [1, 2, 3, 4]
  /// ```
  static Uint8List concat(List<Uint8List> arrays) {
    final totalLength = arrays.fold<int>(0, (sum, arr) => sum + arr.length);
    final result = Uint8List(totalLength);

    var offset = 0;
    for (final array in arrays) {
      result.setRange(offset, offset + array.length, array);
      offset += array.length;
    }

    return result;
  }

  /// Returns a slice of the byte array.
  ///
  /// If [end] is not provided, slices to the end of the array.
  ///
  /// Example:
  /// ```dart
  /// BytesUtils.slice(Uint8List.fromList([1, 2, 3, 4]), 1, 3);
  /// // Returns: Uint8List [2, 3]
  /// ```
  static Uint8List slice(Uint8List data, int start, [int? end]) {
    final actualEnd = end ?? data.length;

    if (start < 0 || start > data.length) {
      throw RangeError.range(start, 0, data.length, 'start');
    }
    if (actualEnd < start || actualEnd > data.length) {
      throw RangeError.range(actualEnd, start, data.length, 'end');
    }

    return Uint8List.fromList(data.sublist(start, actualEnd));
  }

  /// Checks if two byte arrays are equal.
  static bool equals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  /// Pads a byte array to a specific length.
  ///
  /// If [left] is true (default), pads on the left side with zeros.
  /// If [left] is false, pads on the right side.
  ///
  /// Example:
  /// ```dart
  /// BytesUtils.pad(Uint8List.fromList([1, 2]), 4);
  /// // Returns: Uint8List [0, 0, 1, 2]
  ///
  /// BytesUtils.pad(Uint8List.fromList([1, 2]), 4, left: false);
  /// // Returns: Uint8List [1, 2, 0, 0]
  /// ```
  static Uint8List pad(Uint8List data, int length, {bool left = true}) {
    if (data.length >= length) {
      return Uint8List.fromList(data);
    }

    final result = Uint8List(length);
    final offset = left ? length - data.length : 0;
    result.setRange(offset, offset + data.length, data);

    return result;
  }

  /// Trims leading zeros from a byte array.
  static Uint8List trimLeadingZeros(Uint8List data) {
    var start = 0;
    while (start < data.length && data[start] == 0) {
      start++;
    }

    if (start == data.length) {
      return Uint8List(0);
    }

    return Uint8List.fromList(data.sublist(start));
  }

  /// Trims trailing zeros from a byte array.
  static Uint8List trimTrailingZeros(Uint8List data) {
    var end = data.length;
    while (end > 0 && data[end - 1] == 0) {
      end--;
    }

    if (end == 0) {
      return Uint8List(0);
    }

    return Uint8List.fromList(data.sublist(0, end));
  }

  /// Converts a BigInt to bytes.
  ///
  /// If [length] is provided, the result will be padded to that length.
  static Uint8List bigIntToBytes(BigInt value, {int? length}) {
    if (value == BigInt.zero) {
      return length != null ? Uint8List(length) : Uint8List(0);
    }

    final isNegative = value.isNegative;
    var v = isNegative ? -value : value;

    final bytes = <int>[];
    while (v > BigInt.zero) {
      bytes.insert(0, (v & BigInt.from(0xff)).toInt());
      v = v >> 8;
    }

    var result = Uint8List.fromList(bytes);

    if (length != null && result.length < length) {
      result = pad(result, length);
    }

    return result;
  }

  /// Converts bytes to a BigInt.
  static BigInt bytesToBigInt(Uint8List bytes) {
    if (bytes.isEmpty) return BigInt.zero;

    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }

    return result;
  }

  /// Converts an integer to bytes.
  static Uint8List intToBytes(int value, {int? length}) {
    return bigIntToBytes(BigInt.from(value), length: length);
  }

  /// Converts bytes to an integer.
  static int bytesToInt(Uint8List bytes) {
    return bytesToBigInt(bytes).toInt();
  }

  /// Creates a Uint8List from a list of integers.
  static Uint8List fromList(List<int> list) {
    return Uint8List.fromList(list);
  }

  /// Creates an empty Uint8List of the specified length.
  static Uint8List empty(int length) {
    return Uint8List(length);
  }

  /// XORs two byte arrays of equal length.
  static Uint8List xor(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      throw ArgumentError('Byte arrays must have equal length');
    }

    final result = Uint8List(a.length);
    for (var i = 0; i < a.length; i++) {
      result[i] = a[i] ^ b[i];
    }

    return result;
  }
}
