import 'dart:convert';
import 'dart:typed_data';

/// Binary Canonical Serialization (BCS) implementation.
///
/// BCS is a serialization format used by Sui, Aptos, and other Move-based
/// blockchains. It provides deterministic serialization for on-chain data.
///
/// Reference: https://github.com/diem/bcs
class BcsEncoder {
  final BytesBuilder _buffer = BytesBuilder();

  /// Gets the encoded bytes.
  Uint8List toBytes() => _buffer.toBytes();

  /// Clears the buffer.
  void clear() => _buffer.clear();

  /// Gets the current length of encoded data.
  int get length => _buffer.length;

  // === Primitive Types ===

  /// Encodes a boolean value.
  /// BCS: bool is 1 byte, 0x00 = false, 0x01 = true.
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

  /// Encodes an unsigned 16-bit integer (little-endian).
  void writeU16(int value) {
    if (value < 0 || value > 65535) {
      throw ArgumentError('u16 must be in range [0, 65535]');
    }
    _buffer.addByte(value & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
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

  /// Encodes an unsigned 256-bit integer (little-endian).
  void writeU256(BigInt value) {
    if (value < BigInt.zero || value >= BigInt.from(1) << 256) {
      throw ArgumentError('u256 must be in range [0, 2^256-1]');
    }
    for (int i = 0; i < 32; i++) {
      _buffer.addByte((value & BigInt.from(0xFF)).toInt());
      value = value >> 8;
    }
  }

  // === Variable Length Types ===

  /// Encodes an unsigned LEB128 integer.
  /// ULEB128 is used for length prefixes in BCS.
  void writeUleb128(int value) {
    if (value < 0) {
      throw ArgumentError('ULEB128 must be non-negative');
    }
    while (true) {
      int byte = value & 0x7F;
      value >>= 7;
      if (value != 0) {
        byte |= 0x80;
      }
      _buffer.addByte(byte);
      if (value == 0) break;
    }
  }

  /// Encodes a byte array with length prefix.
  void writeBytes(Uint8List bytes) {
    writeUleb128(bytes.length);
    _buffer.add(bytes);
  }

  /// Encodes a fixed-size byte array (no length prefix).
  void writeFixedBytes(Uint8List bytes) {
    _buffer.add(bytes);
  }

  /// Encodes a UTF-8 string with length prefix.
  void writeString(String value) {
    final bytes = utf8.encode(value);
    writeUleb128(bytes.length);
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

  /// Encodes a vector with length prefix.
  void writeVector<T>(List<T> items, void Function(T) writer) {
    writeUleb128(items.length);
    for (final item in items) {
      writer(item);
    }
  }

  /// Encodes an enum variant.
  /// Format: ULEB128 variant index + variant data.
  void writeEnum(int variantIndex, void Function()? writer) {
    writeUleb128(variantIndex);
    writer?.call();
  }
}

/// BCS decoder for reading BCS-encoded data.
class BcsDecoder {
  /// Creates a BcsDecoder from bytes.
  BcsDecoder(this._bytes) : _offset = 0;

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

  /// Decodes an unsigned 16-bit integer (little-endian).
  int readU16() {
    final b0 = _readByte();
    final b1 = _readByte();
    return b0 | (b1 << 8);
  }

  /// Decodes an unsigned 32-bit integer (little-endian).
  int readU32() {
    final b0 = _readByte();
    final b1 = _readByte();
    final b2 = _readByte();
    final b3 = _readByte();
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
  }

  /// Decodes an unsigned 64-bit integer (little-endian).
  BigInt readU64() {
    BigInt result = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      result |= BigInt.from(_readByte()) << (i * 8);
    }
    return result;
  }

  /// Decodes an unsigned 128-bit integer (little-endian).
  BigInt readU128() {
    BigInt result = BigInt.zero;
    for (int i = 0; i < 16; i++) {
      result |= BigInt.from(_readByte()) << (i * 8);
    }
    return result;
  }

  /// Decodes an unsigned 256-bit integer (little-endian).
  BigInt readU256() {
    BigInt result = BigInt.zero;
    for (int i = 0; i < 32; i++) {
      result |= BigInt.from(_readByte()) << (i * 8);
    }
    return result;
  }

  // === Variable Length Types ===

  /// Decodes an unsigned LEB128 integer.
  int readUleb128() {
    int result = 0;
    int shift = 0;
    while (true) {
      final byte = _readByte();
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift >= 32) {
        throw FormatException('ULEB128 overflow');
      }
    }
    return result;
  }

  /// Decodes a byte array with length prefix.
  Uint8List readBytes() {
    final length = readUleb128();
    return _readBytes(length);
  }

  /// Decodes a fixed-size byte array.
  Uint8List readFixedBytes(int length) => _readBytes(length);

  /// Decodes a UTF-8 string with length prefix.
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
    final length = readUleb128();
    return List<T>.generate(length, (_) => reader());
  }

  /// Reads an enum variant index.
  int readEnumVariant() => readUleb128();

  // === Private Helpers ===

  int _readByte() {
    if (_offset >= _bytes.length) {
      throw RangeError('Unexpected end of BCS data');
    }
    return _bytes[_offset++];
  }

  Uint8List _readBytes(int length) {
    if (_offset + length > _bytes.length) {
      throw RangeError('Unexpected end of BCS data');
    }
    final result = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }
}

/// Helper functions for BCS encoding of common types.
class Bcs {
  Bcs._();

  /// Encodes a boolean.
  static Uint8List encodeBool(bool value) {
    final encoder = BcsEncoder();
    encoder.writeBool(value);
    return encoder.toBytes();
  }

  /// Encodes a u8.
  static Uint8List encodeU8(int value) {
    final encoder = BcsEncoder();
    encoder.writeU8(value);
    return encoder.toBytes();
  }

  /// Encodes a u16.
  static Uint8List encodeU16(int value) {
    final encoder = BcsEncoder();
    encoder.writeU16(value);
    return encoder.toBytes();
  }

  /// Encodes a u32.
  static Uint8List encodeU32(int value) {
    final encoder = BcsEncoder();
    encoder.writeU32(value);
    return encoder.toBytes();
  }

  /// Encodes a u64.
  static Uint8List encodeU64(BigInt value) {
    final encoder = BcsEncoder();
    encoder.writeU64(value);
    return encoder.toBytes();
  }

  /// Encodes a u128.
  static Uint8List encodeU128(BigInt value) {
    final encoder = BcsEncoder();
    encoder.writeU128(value);
    return encoder.toBytes();
  }

  /// Encodes a u256.
  static Uint8List encodeU256(BigInt value) {
    final encoder = BcsEncoder();
    encoder.writeU256(value);
    return encoder.toBytes();
  }

  /// Encodes a string.
  static Uint8List encodeString(String value) {
    final encoder = BcsEncoder();
    encoder.writeString(value);
    return encoder.toBytes();
  }

  /// Encodes bytes with length prefix.
  static Uint8List encodeBytes(Uint8List value) {
    final encoder = BcsEncoder();
    encoder.writeBytes(value);
    return encoder.toBytes();
  }

  /// Encodes a fixed 32-byte address.
  static Uint8List encodeAddress(Uint8List address) {
    if (address.length != 32) {
      throw ArgumentError('Address must be 32 bytes');
    }
    return Uint8List.fromList(address);
  }

  /// Encodes a ULEB128 value.
  static Uint8List encodeUleb128(int value) {
    final encoder = BcsEncoder();
    encoder.writeUleb128(value);
    return encoder.toBytes();
  }

  /// Decodes a boolean.
  static bool decodeBool(Uint8List bytes) {
    return BcsDecoder(bytes).readBool();
  }

  /// Decodes a u8.
  static int decodeU8(Uint8List bytes) {
    return BcsDecoder(bytes).readU8();
  }

  /// Decodes a u16.
  static int decodeU16(Uint8List bytes) {
    return BcsDecoder(bytes).readU16();
  }

  /// Decodes a u32.
  static int decodeU32(Uint8List bytes) {
    return BcsDecoder(bytes).readU32();
  }

  /// Decodes a u64.
  static BigInt decodeU64(Uint8List bytes) {
    return BcsDecoder(bytes).readU64();
  }

  /// Decodes a u128.
  static BigInt decodeU128(Uint8List bytes) {
    return BcsDecoder(bytes).readU128();
  }

  /// Decodes a u256.
  static BigInt decodeU256(Uint8List bytes) {
    return BcsDecoder(bytes).readU256();
  }

  /// Decodes a string.
  static String decodeString(Uint8List bytes) {
    return BcsDecoder(bytes).readString();
  }

  /// Decodes bytes.
  static Uint8List decodeBytes(Uint8List bytes) {
    return BcsDecoder(bytes).readBytes();
  }
}
