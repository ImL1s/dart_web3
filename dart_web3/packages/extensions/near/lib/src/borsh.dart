import 'dart:convert';
import 'dart:typed_data';

/// Borsh (Binary Object Representation Serializer for Hashing) implementation.
///
/// Borsh is a serialization format used by NEAR Protocol and other blockchains.
/// It is designed for security-critical applications and provides deterministic
/// serialization with consistent ordering.
///
/// Key differences from BCS:
/// - Borsh uses fixed u32 for all length prefixes
/// - BCS uses variable-length ULEB128 for length prefixes
///
/// Reference: https://borsh.io
class BorshEncoder {
  final BytesBuilder _buffer = BytesBuilder();

  /// Gets the encoded bytes.
  Uint8List toBytes() => _buffer.toBytes();

  /// Clears the buffer.
  void clear() => _buffer.clear();

  /// Gets the current length of encoded data.
  int get length => _buffer.length;

  // === Primitive Types ===

  /// Encodes a boolean value.
  /// Borsh: bool is 1 byte, 0x00 = false, 0x01 = true.
  void writeBool(bool value) {
    _buffer.addByte(value ? 1 : 0);
  }

  /// Encodes an unsigned 8-bit integer.
  void writeU8(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError('u8 must be in range [0, 255]');
    }
    _buffer.addByte(value);
  }

  /// Encodes a signed 8-bit integer.
  void writeI8(int value) {
    if (value < -128 || value > 127) {
      throw ArgumentError('i8 must be in range [-128, 127]');
    }
    _buffer.addByte(value < 0 ? value + 256 : value);
  }

  /// Encodes an unsigned 16-bit integer (little-endian).
  void writeU16(int value) {
    if (value < 0 || value > 65535) {
      throw ArgumentError('u16 must be in range [0, 65535]');
    }
    _buffer.addByte(value & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
  }

  /// Encodes a signed 16-bit integer (little-endian).
  void writeI16(int value) {
    if (value < -32768 || value > 32767) {
      throw ArgumentError('i16 must be in range [-32768, 32767]');
    }
    final unsigned = value < 0 ? value + 65536 : value;
    writeU16(unsigned);
  }

  /// Encodes an unsigned 32-bit integer (little-endian).
  void writeU32(int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw ArgumentError('u32 must be in range [0, 4294967295]');
    }
    _buffer.addByte(value & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
    _buffer.addByte((value >> 16) & 0xFF);
    _buffer.addByte((value >> 24) & 0xFF);
  }

  /// Encodes a signed 32-bit integer (little-endian).
  void writeI32(int value) {
    if (value < -2147483648 || value > 2147483647) {
      throw ArgumentError('i32 must be in range [-2147483648, 2147483647]');
    }
    final unsigned = value < 0 ? value + 0x100000000 : value;
    writeU32(unsigned);
  }

  /// Encodes an unsigned 64-bit integer (little-endian).
  void writeU64(BigInt value) {
    if (value < BigInt.zero || value >= BigInt.from(1) << 64) {
      throw ArgumentError('u64 must be in range [0, 2^64-1]');
    }
    for (int i = 0; i < 8; i++) {
      _buffer.addByte((value & BigInt.from(0xFF)).toInt());
      value = value >> 8;
    }
  }

  /// Encodes a signed 64-bit integer (little-endian).
  void writeI64(BigInt value) {
    final min = -(BigInt.one << 63);
    final max = (BigInt.one << 63) - BigInt.one;
    if (value < min || value > max) {
      throw ArgumentError('i64 must be in range [-2^63, 2^63-1]');
    }
    final unsigned = value < BigInt.zero ? value + (BigInt.one << 64) : value;
    writeU64(unsigned);
  }

  /// Encodes an unsigned 128-bit integer (little-endian).
  void writeU128(BigInt value) {
    if (value < BigInt.zero || value >= BigInt.from(1) << 128) {
      throw ArgumentError('u128 must be in range [0, 2^128-1]');
    }
    for (int i = 0; i < 16; i++) {
      _buffer.addByte((value & BigInt.from(0xFF)).toInt());
      value = value >> 8;
    }
  }

  /// Encodes a 32-bit floating point number.
  void writeF32(double value) {
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  /// Encodes a 64-bit floating point number.
  void writeF64(double value) {
    final data = ByteData(8);
    data.setFloat64(0, value, Endian.little);
    _buffer.add(data.buffer.asUint8List());
  }

  // === Variable Length Types ===

  /// Encodes a byte array with u32 length prefix.
  void writeBytes(Uint8List bytes) {
    writeU32(bytes.length);
    _buffer.add(bytes);
  }

  /// Encodes a fixed-size byte array (no length prefix).
  void writeFixedBytes(Uint8List bytes) {
    _buffer.add(bytes);
  }

  /// Encodes a UTF-8 string with u32 length prefix.
  void writeString(String value) {
    final bytes = utf8.encode(value);
    writeU32(bytes.length);
    _buffer.add(bytes);
  }

  /// Encodes an optional value.
  /// None = 0x00, Some = 0x01 + value.
  void writeOption<T>(T? value, void Function(T) writer) {
    if (value == null) {
      _buffer.addByte(0);
    } else {
      _buffer.addByte(1);
      writer(value);
    }
  }

  /// Encodes a vector with u32 length prefix.
  void writeVector<T>(List<T> items, void Function(T) writer) {
    writeU32(items.length);
    for (final item in items) {
      writer(item);
    }
  }

  /// Encodes a fixed-size array (no length prefix).
  void writeArray<T>(List<T> items, void Function(T) writer) {
    for (final item in items) {
      writer(item);
    }
  }

  /// Encodes an enum variant.
  /// Format: u8 variant index + variant data.
  void writeEnum(int variantIndex, void Function()? writer) {
    writeU8(variantIndex);
    writer?.call();
  }

  /// Encodes a HashMap/BTreeMap.
  void writeMap<K, V>(
    Map<K, V> map,
    void Function(K) keyWriter,
    void Function(V) valueWriter,
  ) {
    writeU32(map.length);
    for (final entry in map.entries) {
      keyWriter(entry.key);
      valueWriter(entry.value);
    }
  }

  /// Encodes a HashSet/BTreeSet.
  void writeSet<T>(Set<T> set, void Function(T) writer) {
    writeU32(set.length);
    for (final item in set) {
      writer(item);
    }
  }
}

/// Borsh decoder for reading Borsh-encoded data.
class BorshDecoder {
  /// Creates a BorshDecoder from bytes.
  BorshDecoder(this._bytes) : _offset = 0;

  final Uint8List _bytes;
  int _offset;

  /// Gets the current offset.
  int get offset => _offset;

  /// Gets the remaining bytes.
  int get remaining => _bytes.length - _offset;

  /// Checks if there are more bytes to read.
  bool get hasMore => _offset < _bytes.length;

  // === Primitive Types ===

  /// Decodes a boolean value.
  bool readBool() {
    final byte = _readByte();
    if (byte == 0) return false;
    if (byte == 1) return true;
    throw FormatException('Invalid boolean value: $byte');
  }

  /// Decodes an unsigned 8-bit integer.
  int readU8() => _readByte();

  /// Decodes a signed 8-bit integer.
  int readI8() {
    final value = _readByte();
    return value > 127 ? value - 256 : value;
  }

  /// Decodes an unsigned 16-bit integer (little-endian).
  int readU16() {
    final b0 = _readByte();
    final b1 = _readByte();
    return b0 | (b1 << 8);
  }

  /// Decodes a signed 16-bit integer (little-endian).
  int readI16() {
    final value = readU16();
    return value > 32767 ? value - 65536 : value;
  }

  /// Decodes an unsigned 32-bit integer (little-endian).
  int readU32() {
    final b0 = _readByte();
    final b1 = _readByte();
    final b2 = _readByte();
    final b3 = _readByte();
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
  }

  /// Decodes a signed 32-bit integer (little-endian).
  int readI32() {
    final value = readU32();
    return value > 2147483647 ? value - 0x100000000 : value;
  }

  /// Decodes an unsigned 64-bit integer (little-endian).
  BigInt readU64() {
    BigInt result = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      result |= BigInt.from(_readByte()) << (i * 8);
    }
    return result;
  }

  /// Decodes a signed 64-bit integer (little-endian).
  BigInt readI64() {
    final value = readU64();
    final threshold = BigInt.one << 63;
    return value >= threshold ? value - (BigInt.one << 64) : value;
  }

  /// Decodes an unsigned 128-bit integer (little-endian).
  BigInt readU128() {
    BigInt result = BigInt.zero;
    for (int i = 0; i < 16; i++) {
      result |= BigInt.from(_readByte()) << (i * 8);
    }
    return result;
  }

  /// Decodes a 32-bit floating point number.
  double readF32() {
    final bytes = _readBytes(4);
    final data = ByteData.sublistView(bytes);
    return data.getFloat32(0, Endian.little);
  }

  /// Decodes a 64-bit floating point number.
  double readF64() {
    final bytes = _readBytes(8);
    final data = ByteData.sublistView(bytes);
    return data.getFloat64(0, Endian.little);
  }

  // === Variable Length Types ===

  /// Decodes a byte array with u32 length prefix.
  Uint8List readBytes() {
    final length = readU32();
    return _readBytes(length);
  }

  /// Decodes a fixed-size byte array.
  Uint8List readFixedBytes(int length) => _readBytes(length);

  /// Decodes a UTF-8 string with u32 length prefix.
  String readString() {
    final bytes = readBytes();
    return utf8.decode(bytes);
  }

  /// Decodes an optional value.
  T? readOption<T>(T Function() reader) {
    final hasValue = readBool();
    if (!hasValue) return null;
    return reader();
  }

  /// Decodes a vector.
  List<T> readVector<T>(T Function() reader) {
    final length = readU32();
    return List<T>.generate(length, (_) => reader());
  }

  /// Decodes a fixed-size array.
  List<T> readArray<T>(int length, T Function() reader) {
    return List<T>.generate(length, (_) => reader());
  }

  /// Reads an enum variant index.
  int readEnumVariant() => readU8();

  /// Decodes a map.
  Map<K, V> readMap<K, V>(K Function() keyReader, V Function() valueReader) {
    final length = readU32();
    final map = <K, V>{};
    for (int i = 0; i < length; i++) {
      final key = keyReader();
      final value = valueReader();
      map[key] = value;
    }
    return map;
  }

  /// Decodes a set.
  Set<T> readSet<T>(T Function() reader) {
    final length = readU32();
    final set = <T>{};
    for (int i = 0; i < length; i++) {
      set.add(reader());
    }
    return set;
  }

  // === Private Helpers ===

  int _readByte() {
    if (_offset >= _bytes.length) {
      throw RangeError('Unexpected end of Borsh data');
    }
    return _bytes[_offset++];
  }

  Uint8List _readBytes(int length) {
    if (_offset + length > _bytes.length) {
      throw RangeError('Unexpected end of Borsh data');
    }
    final result = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }
}

/// Helper functions for Borsh encoding of common types.
class Borsh {
  Borsh._();

  /// Encodes a boolean.
  static Uint8List encodeBool(bool value) {
    final encoder = BorshEncoder();
    encoder.writeBool(value);
    return encoder.toBytes();
  }

  /// Encodes a u8.
  static Uint8List encodeU8(int value) {
    final encoder = BorshEncoder();
    encoder.writeU8(value);
    return encoder.toBytes();
  }

  /// Encodes a u32.
  static Uint8List encodeU32(int value) {
    final encoder = BorshEncoder();
    encoder.writeU32(value);
    return encoder.toBytes();
  }

  /// Encodes a u64.
  static Uint8List encodeU64(BigInt value) {
    final encoder = BorshEncoder();
    encoder.writeU64(value);
    return encoder.toBytes();
  }

  /// Encodes a u128.
  static Uint8List encodeU128(BigInt value) {
    final encoder = BorshEncoder();
    encoder.writeU128(value);
    return encoder.toBytes();
  }

  /// Encodes a string.
  static Uint8List encodeString(String value) {
    final encoder = BorshEncoder();
    encoder.writeString(value);
    return encoder.toBytes();
  }

  /// Encodes bytes with length prefix.
  static Uint8List encodeBytes(Uint8List value) {
    final encoder = BorshEncoder();
    encoder.writeBytes(value);
    return encoder.toBytes();
  }

  /// Decodes a boolean.
  static bool decodeBool(Uint8List bytes) {
    return BorshDecoder(bytes).readBool();
  }

  /// Decodes a u8.
  static int decodeU8(Uint8List bytes) {
    return BorshDecoder(bytes).readU8();
  }

  /// Decodes a u32.
  static int decodeU32(Uint8List bytes) {
    return BorshDecoder(bytes).readU32();
  }

  /// Decodes a u64.
  static BigInt decodeU64(Uint8List bytes) {
    return BorshDecoder(bytes).readU64();
  }

  /// Decodes a u128.
  static BigInt decodeU128(Uint8List bytes) {
    return BorshDecoder(bytes).readU128();
  }

  /// Decodes a string.
  static String decodeString(Uint8List bytes) {
    return BorshDecoder(bytes).readString();
  }

  /// Decodes bytes.
  static Uint8List decodeBytes(Uint8List bytes) {
    return BorshDecoder(bytes).readBytes();
  }
}
