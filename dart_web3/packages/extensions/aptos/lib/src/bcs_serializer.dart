import 'dart:typed_data';

/// Minimal BCS Serializer for Aptos transactions
class BcsSerializer {
  final BytesBuilder _buffer = BytesBuilder();

  Uint8List toBytes() => _buffer.toBytes();

  void serializeU8(int value) {
    _buffer.addByte(value & 0xFF);
  }

  void serializeU32(int value) {
    final bytes = Uint8List(4);
    ByteData.view(bytes.buffer).setUint32(0, value, Endian.little);
    _buffer.add(bytes);
  }

  void serializeU64(BigInt value) {
    var v = value;
    for (var i = 0; i < 8; i++) {
      _buffer.addByte((v & BigInt.from(0xFF)).toInt());
      v >>= 8;
    }
  }

  void serializeBytes(Uint8List value) {
    serializeU32(value.length); // LE Uleb128? Aptos uses ULEB128 for length in some places, but for vector<u8> it uses ULEB128 usually?
    // Wait, BCS uses ULEB128 for sequence lengths.
    // I need ULEB128 implementation.
    _serializeUleb128(value.length);
    _buffer.add(value);
  }

  void serializeString(String value) {
    final bytes = Uint8List.fromList(value.codeUnits); // UTF-8 usually
    serializeBytes(bytes); // length + bytes
  }

  void serializeFixedBytes(Uint8List value) {
    _buffer.add(value);
  }
  
  void serializeBool(bool value) {
    _buffer.addByte(value ? 1 : 0);
  }

  void _serializeUleb128(int value) {
    var v = value;
    while (v >= 0x80) {
      _buffer.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    _buffer.addByte(v);
  }
}
