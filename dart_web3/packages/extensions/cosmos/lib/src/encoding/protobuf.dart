import 'dart:convert';
import 'dart:typed_data';

class ProtobufBuilder {
  final BytesBuilder _buffer = BytesBuilder();

  // Wire types
  static const int wireVarint = 0;
  static const int wireFixed64 = 1;
  static const int wireLengthDelimited = 2;
  static const int wireFixed32 = 5;

  void addBytes(int fieldNumber, Uint8List value) {
    if (value.isEmpty) return;
    _writeTag(fieldNumber, wireLengthDelimited);
    _writeVarint(value.length);
    _buffer.add(value);
  }

  void addString(int fieldNumber, String value) {
    if (value.isEmpty) return;
    addBytes(fieldNumber, Uint8List.fromList(utf8.encode(value)));
  }

  void addInt64(int fieldNumber, int value) {
    if (value == 0) return;
    _writeTag(fieldNumber, wireVarint);
    _writeVarint(value);
  }

  void addUint64(int fieldNumber, BigInt value) {
    if (value == BigInt.zero) return;
    _writeTag(fieldNumber, wireVarint);
    _writeVarintBigInt(value);
  }
  
  // Note: Protobuf varints are unsigned by default encoding logic here (base 128)
  void _writeVarint(int value) {
    var v = value;
    while (v >= 0x80) {
      _buffer.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _buffer.addByte(v);
  }

  void _writeVarintBigInt(BigInt value) {
    var v = value;
    final wrap = BigInt.from(0x80);
    final mask = BigInt.from(0x7f);
    
    while (v >= wrap) {
      _buffer.addByte((v & mask).toInt() | 0x80);
      v >>= 7;
    }
    _buffer.addByte(v.toInt());
  }

  void _writeTag(int fieldNumber, int wireType) {
    _writeVarint((fieldNumber << 3) | wireType);
  }

  void addMessage(int fieldNumber, ProtobufBuilder message) {
    final bytes = message.toBytes();
    addBytes(fieldNumber, bytes);
  }
  
  // Add direct bytes (for embedded messages already serialized)
  void addRawMessage(int fieldNumber, Uint8List rawBytes) {
      addBytes(fieldNumber, rawBytes);
  }

  Uint8List toBytes() => _buffer.toBytes();
}
