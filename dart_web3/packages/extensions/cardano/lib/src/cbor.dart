import 'dart:convert';
import 'dart:typed_data';

/// CBOR (Concise Binary Object Representation) implementation.
///
/// CBOR is a binary data format defined in RFC 8949, used by Cardano
/// for transaction serialization and data encoding.
///
/// Key features:
/// - Initial byte encodes major type (3 bits) + additional info (5 bits)
/// - Multi-byte values are BIG ENDIAN
/// - Supports integers, byte strings, text strings, arrays, maps, tags, and floats
///
/// Reference: https://www.rfc-editor.org/rfc/rfc8949.html

/// CBOR Major Types
enum CborMajorType {
  /// Unsigned integer (0 to 2^64-1)
  unsignedInt, // 0

  /// Negative integer (-2^64 to -1)
  negativeInt, // 1

  /// Byte string
  byteString, // 2

  /// Text string (UTF-8)
  textString, // 3

  /// Array of data items
  array, // 4

  /// Map of key-value pairs
  map, // 5

  /// Tagged data item
  tag, // 6

  /// Simple values and floats
  simpleOrFloat, // 7
}

/// CBOR Encoder for building CBOR-encoded data.
class CborEncoder {
  final BytesBuilder _buffer = BytesBuilder();

  /// Gets the encoded bytes.
  Uint8List toBytes() => _buffer.toBytes();

  /// Clears the buffer.
  void clear() => _buffer.clear();

  /// Gets the current length of encoded data.
  int get length => _buffer.length;

  // === Primitive Types ===

  /// Writes the initial byte with major type and additional info.
  void _writeInitialByte(int majorType, int additionalInfo) {
    _buffer.addByte((majorType << 5) | (additionalInfo & 0x1F));
  }

  /// Writes an unsigned integer argument with the appropriate encoding.
  void _writeUnsignedArgument(int majorType, int value) {
    if (value < 0) {
      throw ArgumentError('Value must be non-negative');
    }
    if (value <= 23) {
      // Value fits directly in additional info
      _writeInitialByte(majorType, value);
    } else if (value <= 0xFF) {
      // 1 additional byte
      _writeInitialByte(majorType, 24);
      _buffer.addByte(value);
    } else if (value <= 0xFFFF) {
      // 2 additional bytes (big-endian)
      _writeInitialByte(majorType, 25);
      _buffer.addByte((value >> 8) & 0xFF);
      _buffer.addByte(value & 0xFF);
    } else if (value <= 0xFFFFFFFF) {
      // 4 additional bytes (big-endian)
      _writeInitialByte(majorType, 26);
      _buffer.addByte((value >> 24) & 0xFF);
      _buffer.addByte((value >> 16) & 0xFF);
      _buffer.addByte((value >> 8) & 0xFF);
      _buffer.addByte(value & 0xFF);
    } else {
      // 8 additional bytes (big-endian)
      _writeInitialByte(majorType, 27);
      for (int i = 7; i >= 0; i--) {
        _buffer.addByte((value >> (i * 8)) & 0xFF);
      }
    }
  }

  /// Writes a BigInt unsigned integer argument.
  void _writeUnsignedBigIntArgument(int majorType, BigInt value) {
    if (value < BigInt.zero) {
      throw ArgumentError('Value must be non-negative');
    }
    if (value <= BigInt.from(0x17)) {
      _writeInitialByte(majorType, value.toInt());
    } else if (value <= BigInt.from(0xFF)) {
      _writeInitialByte(majorType, 24);
      _buffer.addByte(value.toInt());
    } else if (value <= BigInt.from(0xFFFF)) {
      _writeInitialByte(majorType, 25);
      final v = value.toInt();
      _buffer.addByte((v >> 8) & 0xFF);
      _buffer.addByte(v & 0xFF);
    } else if (value <= BigInt.from(0xFFFFFFFF)) {
      _writeInitialByte(majorType, 26);
      final v = value.toInt();
      _buffer.addByte((v >> 24) & 0xFF);
      _buffer.addByte((v >> 16) & 0xFF);
      _buffer.addByte((v >> 8) & 0xFF);
      _buffer.addByte(v & 0xFF);
    } else if (value < (BigInt.one << 64)) {
      _writeInitialByte(majorType, 27);
      for (int i = 7; i >= 0; i--) {
        _buffer.addByte(((value >> (i * 8)) & BigInt.from(0xFF)).toInt());
      }
    } else {
      throw ArgumentError('Value exceeds maximum u64');
    }
  }

  /// Encodes an unsigned integer.
  void writeUnsignedInt(int value) {
    if (value < 0) {
      throw ArgumentError('Value must be non-negative');
    }
    _writeUnsignedArgument(0, value);
  }

  /// Encodes a BigInt unsigned integer.
  void writeUnsignedBigInt(BigInt value) {
    if (value < BigInt.zero) {
      throw ArgumentError('Value must be non-negative');
    }
    _writeUnsignedBigIntArgument(0, value);
  }

  /// Encodes a negative integer.
  /// CBOR encodes as (-1 - value), so -1 is encoded as 0, -2 as 1, etc.
  void writeNegativeInt(int value) {
    if (value >= 0) {
      throw ArgumentError('Value must be negative');
    }
    _writeUnsignedArgument(1, (-1 - value));
  }

  /// Encodes any integer (positive or negative).
  void writeInt(int value) {
    if (value >= 0) {
      writeUnsignedInt(value);
    } else {
      writeNegativeInt(value);
    }
  }

  /// Encodes a BigInt (positive or negative).
  void writeBigInt(BigInt value) {
    if (value >= BigInt.zero) {
      writeUnsignedBigInt(value);
    } else {
      _writeUnsignedBigIntArgument(1, -BigInt.one - value);
    }
  }

  /// Encodes a byte string.
  void writeBytes(Uint8List bytes) {
    _writeUnsignedArgument(2, bytes.length);
    _buffer.add(bytes);
  }

  /// Encodes a text string (UTF-8).
  void writeString(String value) {
    final bytes = utf8.encode(value);
    _writeUnsignedArgument(3, bytes.length);
    _buffer.add(bytes);
  }

  /// Starts an array with known length.
  void writeArrayStart(int length) {
    _writeUnsignedArgument(4, length);
  }

  /// Writes an indefinite-length array start.
  void writeIndefiniteArrayStart() {
    _writeInitialByte(4, 31);
  }

  /// Starts a map with known length.
  void writeMapStart(int length) {
    _writeUnsignedArgument(5, length);
  }

  /// Writes an indefinite-length map start.
  void writeIndefiniteMapStart() {
    _writeInitialByte(5, 31);
  }

  /// Writes a break code to end indefinite-length items.
  void writeBreak() {
    _buffer.addByte(0xFF);
  }

  /// Writes a tag value.
  void writeTag(int tag) {
    _writeUnsignedArgument(6, tag);
  }

  /// Writes a BigInt tag value.
  void writeTagBigInt(BigInt tag) {
    _writeUnsignedBigIntArgument(6, tag);
  }

  /// Encodes a simple value (0-255).
  void writeSimple(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError('Simple value must be in range [0, 255]');
    }
    if (value <= 23) {
      _writeInitialByte(7, value);
    } else {
      _writeInitialByte(7, 24);
      _buffer.addByte(value);
    }
  }

  /// Encodes false.
  void writeFalse() {
    _writeInitialByte(7, 20);
  }

  /// Encodes true.
  void writeTrue() {
    _writeInitialByte(7, 21);
  }

  /// Encodes a boolean.
  void writeBool(bool value) {
    if (value) {
      writeTrue();
    } else {
      writeFalse();
    }
  }

  /// Encodes null.
  void writeNull() {
    _writeInitialByte(7, 22);
  }

  /// Encodes undefined.
  void writeUndefined() {
    _writeInitialByte(7, 23);
  }

  /// Encodes a half-precision float (16-bit).
  void writeFloat16(double value) {
    _writeInitialByte(7, 25);
    final bytes = _encodeFloat16(value);
    _buffer.add(bytes);
  }

  /// Encodes a single-precision float (32-bit).
  void writeFloat32(double value) {
    _writeInitialByte(7, 26);
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.big);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Encodes a double-precision float (64-bit).
  void writeFloat64(double value) {
    _writeInitialByte(7, 27);
    final data = ByteData(8);
    data.setFloat64(0, value, Endian.big);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Encodes a double using the most compact representation.
  void writeDouble(double value) {
    // Check if it can be represented as float16
    if (_canRepresentAsFloat16(value)) {
      writeFloat16(value);
    } else if (_canRepresentAsFloat32(value)) {
      writeFloat32(value);
    } else {
      writeFloat64(value);
    }
  }

  // === Convenience Methods ===

  /// Writes an array of items.
  void writeArray<T>(List<T> items, void Function(T) writer) {
    writeArrayStart(items.length);
    for (final item in items) {
      writer(item);
    }
  }

  /// Writes a map.
  void writeMap<K, V>(
    Map<K, V> map,
    void Function(K) keyWriter,
    void Function(V) valueWriter,
  ) {
    writeMapStart(map.length);
    for (final entry in map.entries) {
      keyWriter(entry.key);
      valueWriter(entry.value);
    }
  }

  /// Writes an optional value.
  void writeOptional<T>(T? value, void Function(T) writer) {
    if (value == null) {
      writeNull();
    } else {
      writer(value);
    }
  }

  // === Float16 Helpers ===

  Uint8List _encodeFloat16(double value) {
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.big);
    final bits = data.getUint32(0, Endian.big);

    // Extract float32 components
    final sign = (bits >> 31) & 0x1;
    final exp = (bits >> 23) & 0xFF;
    final frac = bits & 0x7FFFFF;

    int halfSign = sign;
    int halfExp;
    int halfFrac;

    if (exp == 0) {
      // Zero or subnormal
      halfExp = 0;
      halfFrac = 0;
    } else if (exp == 255) {
      // Infinity or NaN
      halfExp = 31;
      halfFrac = frac == 0 ? 0 : 0x200; // Preserve NaN
    } else {
      // Normalized
      final newExp = exp - 127 + 15;
      if (newExp >= 31) {
        // Overflow to infinity
        halfExp = 31;
        halfFrac = 0;
      } else if (newExp <= 0) {
        // Underflow to subnormal or zero
        if (newExp < -10) {
          halfExp = 0;
          halfFrac = 0;
        } else {
          halfExp = 0;
          halfFrac = (0x400 | (frac >> 13)) >> (1 - newExp);
        }
      } else {
        halfExp = newExp;
        halfFrac = frac >> 13;
      }
    }

    final halfBits = (halfSign << 15) | (halfExp << 10) | halfFrac;
    return Uint8List.fromList([
      (halfBits >> 8) & 0xFF,
      halfBits & 0xFF,
    ]);
  }

  bool _canRepresentAsFloat16(double value) {
    if (value == 0.0 || value.isNaN || value.isInfinite) {
      return true;
    }
    // Check if value can be exactly represented in float16
    final encoded = _encodeFloat16(value);
    final decoded = _decodeFloat16(encoded);
    return decoded == value;
  }

  double _decodeFloat16(Uint8List bytes) {
    final bits = (bytes[0] << 8) | bytes[1];
    final sign = (bits >> 15) & 0x1;
    final exp = (bits >> 10) & 0x1F;
    final frac = bits & 0x3FF;

    double value;
    if (exp == 0) {
      // Subnormal or zero
      value = frac / 1024.0 * (1 / 16384.0);
    } else if (exp == 31) {
      // Infinity or NaN
      value = frac == 0 ? double.infinity : double.nan;
    } else {
      // Normalized
      value = (1 + frac / 1024.0) * (1 << (exp - 15)).toDouble();
    }

    return sign == 1 ? -value : value;
  }

  bool _canRepresentAsFloat32(double value) {
    if (value.isNaN || value.isInfinite) {
      return true;
    }
    // Check if value can be exactly represented in float32
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.big);
    return data.getFloat32(0, Endian.big) == value;
  }
}

/// CBOR Decoder for reading CBOR-encoded data.
class CborDecoder {
  /// Creates a CborDecoder from bytes.
  CborDecoder(this._bytes) : _offset = 0;

  final Uint8List _bytes;
  int _offset;

  /// Gets the current offset.
  int get offset => _offset;

  /// Gets the remaining bytes.
  int get remaining => _bytes.length - _offset;

  /// Checks if there are more bytes to read.
  bool get hasMore => _offset < _bytes.length;

  /// Peeks at the next byte without consuming it.
  int peek() {
    if (_offset >= _bytes.length) {
      throw RangeError('Unexpected end of CBOR data');
    }
    return _bytes[_offset];
  }

  /// Peeks at the major type of the next item.
  CborMajorType peekMajorType() {
    final byte = peek();
    return CborMajorType.values[byte >> 5];
  }

  // === Reading the Initial Byte ===

  /// Reads the initial byte and returns (majorType, additionalInfo).
  (int, int) _readInitialByte() {
    final byte = _readByte();
    return (byte >> 5, byte & 0x1F);
  }

  /// Reads an unsigned argument based on additional info.
  int _readUnsignedArgument(int additionalInfo) {
    if (additionalInfo <= 23) {
      return additionalInfo;
    } else if (additionalInfo == 24) {
      return _readByte();
    } else if (additionalInfo == 25) {
      final b0 = _readByte();
      final b1 = _readByte();
      return (b0 << 8) | b1;
    } else if (additionalInfo == 26) {
      final b0 = _readByte();
      final b1 = _readByte();
      final b2 = _readByte();
      final b3 = _readByte();
      return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
    } else if (additionalInfo == 27) {
      int result = 0;
      for (int i = 0; i < 8; i++) {
        result = (result << 8) | _readByte();
      }
      return result;
    } else if (additionalInfo == 31) {
      return -1; // Indefinite length
    } else {
      throw FormatException('Reserved additional info: $additionalInfo');
    }
  }

  /// Reads a BigInt unsigned argument.
  BigInt _readUnsignedBigIntArgument(int additionalInfo) {
    if (additionalInfo <= 23) {
      return BigInt.from(additionalInfo);
    } else if (additionalInfo == 24) {
      return BigInt.from(_readByte());
    } else if (additionalInfo == 25) {
      final b0 = _readByte();
      final b1 = _readByte();
      return BigInt.from((b0 << 8) | b1);
    } else if (additionalInfo == 26) {
      final b0 = _readByte();
      final b1 = _readByte();
      final b2 = _readByte();
      final b3 = _readByte();
      return BigInt.from((b0 << 24) | (b1 << 16) | (b2 << 8) | b3);
    } else if (additionalInfo == 27) {
      BigInt result = BigInt.zero;
      for (int i = 0; i < 8; i++) {
        result = (result << 8) | BigInt.from(_readByte());
      }
      return result;
    } else {
      throw FormatException('Invalid additional info for BigInt: $additionalInfo');
    }
  }

  // === Primitive Types ===

  /// Decodes an unsigned integer.
  int readUnsignedInt() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 0) {
      throw FormatException('Expected unsigned int (type 0), got type $majorType');
    }
    return _readUnsignedArgument(additionalInfo);
  }

  /// Decodes an unsigned BigInt.
  BigInt readUnsignedBigInt() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 0) {
      throw FormatException('Expected unsigned int (type 0), got type $majorType');
    }
    return _readUnsignedBigIntArgument(additionalInfo);
  }

  /// Decodes a negative integer.
  int readNegativeInt() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 1) {
      throw FormatException('Expected negative int (type 1), got type $majorType');
    }
    return -1 - _readUnsignedArgument(additionalInfo);
  }

  /// Decodes any integer (positive or negative).
  int readInt() {
    final byte = peek();
    final majorType = byte >> 5;
    if (majorType == 0) {
      return readUnsignedInt();
    } else if (majorType == 1) {
      return readNegativeInt();
    } else {
      throw FormatException('Expected int (type 0 or 1), got type $majorType');
    }
  }

  /// Decodes any BigInt (positive or negative).
  BigInt readBigInt() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType == 0) {
      return _readUnsignedBigIntArgument(additionalInfo);
    } else if (majorType == 1) {
      return -BigInt.one - _readUnsignedBigIntArgument(additionalInfo);
    } else {
      throw FormatException('Expected int (type 0 or 1), got type $majorType');
    }
  }

  /// Decodes a byte string.
  Uint8List readBytes() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 2) {
      throw FormatException('Expected byte string (type 2), got type $majorType');
    }
    final length = _readUnsignedArgument(additionalInfo);
    if (length < 0) {
      // Indefinite length byte string
      final builder = BytesBuilder();
      while (true) {
        final nextByte = peek();
        if (nextByte == 0xFF) {
          _readByte(); // Consume break
          break;
        }
        builder.add(readBytes());
      }
      return builder.toBytes();
    }
    return _readBytes(length);
  }

  /// Decodes a text string.
  String readString() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 3) {
      throw FormatException('Expected text string (type 3), got type $majorType');
    }
    final length = _readUnsignedArgument(additionalInfo);
    if (length < 0) {
      // Indefinite length text string
      final builder = StringBuffer();
      while (true) {
        final nextByte = peek();
        if (nextByte == 0xFF) {
          _readByte(); // Consume break
          break;
        }
        builder.write(readString());
      }
      return builder.toString();
    }
    final bytes = _readBytes(length);
    return utf8.decode(bytes);
  }

  /// Reads array start and returns length (-1 for indefinite).
  int readArrayStart() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 4) {
      throw FormatException('Expected array (type 4), got type $majorType');
    }
    return _readUnsignedArgument(additionalInfo);
  }

  /// Reads map start and returns number of pairs (-1 for indefinite).
  int readMapStart() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 5) {
      throw FormatException('Expected map (type 5), got type $majorType');
    }
    return _readUnsignedArgument(additionalInfo);
  }

  /// Reads a tag value.
  int readTag() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 6) {
      throw FormatException('Expected tag (type 6), got type $majorType');
    }
    return _readUnsignedArgument(additionalInfo);
  }

  /// Reads a BigInt tag value.
  BigInt readTagBigInt() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 6) {
      throw FormatException('Expected tag (type 6), got type $majorType');
    }
    return _readUnsignedBigIntArgument(additionalInfo);
  }

  /// Checks if the next item is a break code.
  bool isBreak() {
    return peek() == 0xFF;
  }

  /// Reads and consumes a break code.
  void readBreak() {
    final byte = _readByte();
    if (byte != 0xFF) {
      throw FormatException('Expected break code (0xFF), got 0x${byte.toRadixString(16)}');
    }
  }

  /// Decodes a boolean.
  bool readBool() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7) {
      throw FormatException('Expected simple/float (type 7), got type $majorType');
    }
    if (additionalInfo == 20) return false;
    if (additionalInfo == 21) return true;
    throw FormatException('Expected boolean (20 or 21), got $additionalInfo');
  }

  /// Reads null.
  void readNull() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7 || additionalInfo != 22) {
      throw FormatException('Expected null (type 7, info 22)');
    }
  }

  /// Reads undefined.
  void readUndefined() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7 || additionalInfo != 23) {
      throw FormatException('Expected undefined (type 7, info 23)');
    }
  }

  /// Reads a simple value.
  int readSimple() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7) {
      throw FormatException('Expected simple/float (type 7), got type $majorType');
    }
    if (additionalInfo <= 23) {
      return additionalInfo;
    } else if (additionalInfo == 24) {
      return _readByte();
    } else {
      throw FormatException('Expected simple value, got additional info $additionalInfo');
    }
  }

  /// Decodes a half-precision float (16-bit).
  double readFloat16() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7 || additionalInfo != 25) {
      throw FormatException('Expected float16 (type 7, info 25)');
    }
    final bytes = _readBytes(2);
    return _decodeFloat16(bytes);
  }

  /// Decodes a single-precision float (32-bit).
  double readFloat32() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7 || additionalInfo != 26) {
      throw FormatException('Expected float32 (type 7, info 26)');
    }
    final bytes = _readBytes(4);
    final data = ByteData.sublistView(bytes);
    return data.getFloat32(0, Endian.big);
  }

  /// Decodes a double-precision float (64-bit).
  double readFloat64() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7 || additionalInfo != 27) {
      throw FormatException('Expected float64 (type 7, info 27)');
    }
    final bytes = _readBytes(8);
    final data = ByteData.sublistView(bytes);
    return data.getFloat64(0, Endian.big);
  }

  /// Decodes any float type.
  double readDouble() {
    final (majorType, additionalInfo) = _readInitialByte();
    if (majorType != 7) {
      throw FormatException('Expected simple/float (type 7), got type $majorType');
    }
    if (additionalInfo == 25) {
      final bytes = _readBytes(2);
      return _decodeFloat16(bytes);
    } else if (additionalInfo == 26) {
      final bytes = _readBytes(4);
      final data = ByteData.sublistView(bytes);
      return data.getFloat32(0, Endian.big);
    } else if (additionalInfo == 27) {
      final bytes = _readBytes(8);
      final data = ByteData.sublistView(bytes);
      return data.getFloat64(0, Endian.big);
    } else {
      throw FormatException('Expected float (info 25-27), got $additionalInfo');
    }
  }

  double _decodeFloat16(Uint8List bytes) {
    final bits = (bytes[0] << 8) | bytes[1];
    final sign = (bits >> 15) & 0x1;
    final exp = (bits >> 10) & 0x1F;
    final frac = bits & 0x3FF;

    double value;
    if (exp == 0) {
      // Subnormal or zero
      value = frac / 1024.0 * (1 / 16384.0);
    } else if (exp == 31) {
      // Infinity or NaN
      value = frac == 0 ? double.infinity : double.nan;
    } else {
      // Normalized
      value = (1 + frac / 1024.0) * (1 << (exp - 15)).toDouble();
    }

    return sign == 1 ? -value : value;
  }

  // === Convenience Methods ===

  /// Reads an array of items.
  List<T> readArray<T>(T Function() reader) {
    final length = readArrayStart();
    if (length < 0) {
      // Indefinite length
      final items = <T>[];
      while (!isBreak()) {
        items.add(reader());
      }
      readBreak();
      return items;
    }
    return List<T>.generate(length, (_) => reader());
  }

  /// Reads a map.
  Map<K, V> readMap<K, V>(K Function() keyReader, V Function() valueReader) {
    final length = readMapStart();
    final map = <K, V>{};
    if (length < 0) {
      // Indefinite length
      while (!isBreak()) {
        final key = keyReader();
        final value = valueReader();
        map[key] = value;
      }
      readBreak();
    } else {
      for (int i = 0; i < length; i++) {
        final key = keyReader();
        final value = valueReader();
        map[key] = value;
      }
    }
    return map;
  }

  /// Reads an optional value (returns null if CBOR null).
  T? readOptional<T>(T Function() reader) {
    if (peek() == 0xF6) {
      // null
      _readByte();
      return null;
    }
    return reader();
  }

  // === Private Helpers ===

  int _readByte() {
    if (_offset >= _bytes.length) {
      throw RangeError('Unexpected end of CBOR data');
    }
    return _bytes[_offset++];
  }

  Uint8List _readBytes(int length) {
    if (_offset + length > _bytes.length) {
      throw RangeError('Unexpected end of CBOR data');
    }
    final result = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }
}

/// Helper functions for CBOR encoding of common types.
class Cbor {
  Cbor._();

  /// Encodes an unsigned integer.
  static Uint8List encodeUnsignedInt(int value) {
    final encoder = CborEncoder();
    encoder.writeUnsignedInt(value);
    return encoder.toBytes();
  }

  /// Encodes a signed integer.
  static Uint8List encodeInt(int value) {
    final encoder = CborEncoder();
    encoder.writeInt(value);
    return encoder.toBytes();
  }

  /// Encodes a BigInt.
  static Uint8List encodeBigInt(BigInt value) {
    final encoder = CborEncoder();
    encoder.writeBigInt(value);
    return encoder.toBytes();
  }

  /// Encodes a byte string.
  static Uint8List encodeBytes(Uint8List value) {
    final encoder = CborEncoder();
    encoder.writeBytes(value);
    return encoder.toBytes();
  }

  /// Encodes a text string.
  static Uint8List encodeString(String value) {
    final encoder = CborEncoder();
    encoder.writeString(value);
    return encoder.toBytes();
  }

  /// Encodes a boolean.
  static Uint8List encodeBool(bool value) {
    final encoder = CborEncoder();
    encoder.writeBool(value);
    return encoder.toBytes();
  }

  /// Encodes null.
  static Uint8List encodeNull() {
    final encoder = CborEncoder();
    encoder.writeNull();
    return encoder.toBytes();
  }

  /// Encodes a double.
  static Uint8List encodeDouble(double value) {
    final encoder = CborEncoder();
    encoder.writeDouble(value);
    return encoder.toBytes();
  }

  /// Decodes an unsigned integer.
  static int decodeUnsignedInt(Uint8List bytes) {
    return CborDecoder(bytes).readUnsignedInt();
  }

  /// Decodes a signed integer.
  static int decodeInt(Uint8List bytes) {
    return CborDecoder(bytes).readInt();
  }

  /// Decodes a BigInt.
  static BigInt decodeBigInt(Uint8List bytes) {
    return CborDecoder(bytes).readBigInt();
  }

  /// Decodes a byte string.
  static Uint8List decodeBytes(Uint8List bytes) {
    return CborDecoder(bytes).readBytes();
  }

  /// Decodes a text string.
  static String decodeString(Uint8List bytes) {
    return CborDecoder(bytes).readString();
  }

  /// Decodes a boolean.
  static bool decodeBool(Uint8List bytes) {
    return CborDecoder(bytes).readBool();
  }

  /// Decodes a double.
  static double decodeDouble(Uint8List bytes) {
    return CborDecoder(bytes).readDouble();
  }
}

/// Well-known CBOR tags used in Cardano and other applications.
class CborTags {
  CborTags._();

  /// Standard date/time string (RFC 3339)
  static const int dateTimeString = 0;

  /// Epoch-based date/time
  static const int epochDateTime = 1;

  /// Unsigned bignum
  static const int positiveBignum = 2;

  /// Negative bignum
  static const int negativeBignum = 3;

  /// Decimal fraction
  static const int decimalFraction = 4;

  /// Bigfloat
  static const int bigfloat = 5;

  /// Base64url encoding
  static const int base64url = 21;

  /// Base64 encoding
  static const int base64 = 22;

  /// Base16 encoding
  static const int base16 = 23;

  /// CBOR data item
  static const int encodedCbor = 24;

  /// URI
  static const int uri = 32;

  /// Base64url (no padding)
  static const int base64urlNoPadding = 33;

  /// Regular expression
  static const int regex = 35;

  /// MIME message
  static const int mime = 36;

  /// Self-described CBOR (magic number 0xD9D9F7)
  static const int selfDescribedCbor = 55799;
}
