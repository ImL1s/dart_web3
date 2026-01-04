import 'dart:typed_data';

import 'bytes.dart';
import 'exceptions.dart';

/// Recursive Length Prefix (RLP) encoding and decoding.
///
/// RLP is the main encoding method used to serialize objects in Ethereum.
/// See: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
class RLP {
  RLP._();

  /// Encodes data using RLP encoding.
  ///
  /// Supported types:
  /// - [Uint8List] - encoded as bytes
  /// - [String] - encoded as UTF-8 bytes
  /// - [int] - encoded as big-endian bytes
  /// - [BigInt] - encoded as big-endian bytes
  /// - [List] - encoded as RLP list
  /// - [null] - encoded as empty bytes
  ///
  /// Example:
  /// ```dart
  /// RLP.encode('dog'); // [0x83, 0x64, 0x6f, 0x67]
  /// RLP.encode(['cat', 'dog']); // [0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67]
  /// ```
  static Uint8List encode(dynamic data) {
    if (data == null) {
      return _encodeBytes(Uint8List(0));
    }

    if (data is Uint8List) {
      return _encodeBytes(data);
    }

    if (data is List) {
      return _encodeList(data);
    }

    if (data is String) {
      return _encodeBytes(Uint8List.fromList(data.codeUnits));
    }

    if (data is int) {
      if (data == 0) {
        return _encodeBytes(Uint8List(0));
      }
      return _encodeBytes(BytesUtils.intToBytes(data));
    }

    if (data is BigInt) {
      if (data == BigInt.zero) {
        return _encodeBytes(Uint8List(0));
      }
      return _encodeBytes(BytesUtils.bigIntToBytes(data));
    }

    throw RlpException(
        'Unsupported type for RLP encoding: ${data.runtimeType}');
  }

  /// Decodes RLP-encoded data.
  ///
  /// Returns either a [Uint8List] for single items or a [List] for sequences.
  ///
  /// Example:
  /// ```dart
  /// RLP.decode(Uint8List.fromList([0x83, 0x64, 0x6f, 0x67])); // 'dog' as bytes
  /// ```
  static dynamic decode(Uint8List data) {
    if (data.isEmpty) {
      throw RlpException('Cannot decode empty data');
    }

    final (result, consumed) = _decode(data, 0);

    if (consumed != data.length) {
      throw RlpException('Invalid RLP: extra bytes after decoding');
    }

    return result;
  }

  static Uint8List _encodeBytes(Uint8List bytes) {
    // Single byte in range [0x00, 0x7f]
    if (bytes.length == 1 && bytes[0] < 0x80) {
      return bytes;
    }

    // Short string (0-55 bytes)
    if (bytes.length <= 55) {
      final result = Uint8List(1 + bytes.length);
      result[0] = 0x80 + bytes.length;
      result.setRange(1, result.length, bytes);
      return result;
    }

    // Long string (> 55 bytes)
    final lengthBytes = _encodeLength(bytes.length);
    final result = Uint8List(1 + lengthBytes.length + bytes.length);
    result[0] = 0xb7 + lengthBytes.length;
    result.setRange(1, 1 + lengthBytes.length, lengthBytes);
    result.setRange(1 + lengthBytes.length, result.length, bytes);
    return result;
  }

  static Uint8List _encodeList(List<dynamic> list) {
    // Encode all items
    final encodedItems = <Uint8List>[];
    var totalLength = 0;

    for (final item in list) {
      final encoded = encode(item);
      encodedItems.add(encoded);
      totalLength += encoded.length;
    }

    // Short list (0-55 bytes total)
    if (totalLength <= 55) {
      final result = Uint8List(1 + totalLength);
      result[0] = 0xc0 + totalLength;

      var offset = 1;
      for (final encoded in encodedItems) {
        result.setRange(offset, offset + encoded.length, encoded);
        offset += encoded.length;
      }

      return result;
    }

    // Long list (> 55 bytes total)
    final lengthBytes = _encodeLength(totalLength);
    final result = Uint8List(1 + lengthBytes.length + totalLength);
    result[0] = 0xf7 + lengthBytes.length;
    result.setRange(1, 1 + lengthBytes.length, lengthBytes);

    var offset = 1 + lengthBytes.length;
    for (final encoded in encodedItems) {
      result.setRange(offset, offset + encoded.length, encoded);
      offset += encoded.length;
    }

    return result;
  }

  static Uint8List _encodeLength(int length) {
    if (length < 256) {
      return Uint8List.fromList([length]);
    }

    final bytes = <int>[];
    var remaining = length;
    while (remaining > 0) {
      bytes.insert(0, remaining & 0xff);
      remaining >>= 8;
    }

    return Uint8List.fromList(bytes);
  }

  static (dynamic, int) _decode(Uint8List data, int offset) {
    if (offset >= data.length) {
      throw RlpException('Invalid RLP: unexpected end of data');
    }

    final prefix = data[offset];

    // Single byte [0x00, 0x7f]
    if (prefix < 0x80) {
      return (Uint8List.fromList([prefix]), 1);
    }

    // Short string [0x80, 0xb7]
    if (prefix <= 0xb7) {
      final length = prefix - 0x80;
      if (offset + 1 + length > data.length) {
        throw RlpException('Invalid RLP: string length exceeds data');
      }
      return (
        Uint8List.fromList(data.sublist(offset + 1, offset + 1 + length)),
        1 + length,
      );
    }

    // Long string [0xb8, 0xbf]
    if (prefix <= 0xbf) {
      final lengthOfLength = prefix - 0xb7;
      if (offset + 1 + lengthOfLength > data.length) {
        throw RlpException('Invalid RLP: length bytes exceed data');
      }

      final length = _decodeLength(data, offset + 1, lengthOfLength);
      if (offset + 1 + lengthOfLength + length > data.length) {
        throw RlpException('Invalid RLP: string length exceeds data');
      }

      return (
        Uint8List.fromList(
          data.sublist(offset + 1 + lengthOfLength,
              offset + 1 + lengthOfLength + length),
        ),
        1 + lengthOfLength + length,
      );
    }

    // Short list [0xc0, 0xf7]
    if (prefix <= 0xf7) {
      final length = prefix - 0xc0;
      final items = _decodeListItems(data, offset + 1, length);
      return (items, 1 + length);
    }

    // Long list [0xf8, 0xff]
    final lengthOfLength = prefix - 0xf7;
    if (offset + 1 + lengthOfLength > data.length) {
      throw RlpException('Invalid RLP: length bytes exceed data');
    }

    final length = _decodeLength(data, offset + 1, lengthOfLength);
    final items = _decodeListItems(data, offset + 1 + lengthOfLength, length);
    return (items, 1 + lengthOfLength + length);
  }

  static int _decodeLength(Uint8List data, int offset, int lengthOfLength) {
    if (lengthOfLength == 0) return 0;

    // Check for leading zeros (invalid)
    if (data[offset] == 0) {
      throw RlpException('Invalid RLP: length has leading zeros');
    }

    var length = 0;
    for (var i = 0; i < lengthOfLength; i++) {
      length = (length << 8) | data[offset + i];
    }

    return length;
  }

  static List<dynamic> _decodeListItems(
      Uint8List data, int offset, int length) {
    final items = <dynamic>[];
    var consumed = 0;

    while (consumed < length) {
      final (item, itemLength) = _decode(data, offset + consumed);
      items.add(item);
      consumed += itemLength;
    }

    if (consumed != length) {
      throw RlpException('Invalid RLP: list length mismatch');
    }

    return items;
  }
}
