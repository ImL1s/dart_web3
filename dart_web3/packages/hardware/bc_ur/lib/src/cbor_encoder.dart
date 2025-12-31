import 'dart:typed_data';
import 'dart:convert';

/// Simple CBOR encoder for BC-UR
/// Implements subset of CBOR needed for BC-UR communication
class CBOREncoder {
  final BytesBuilder _buffer = BytesBuilder();
  
  /// Encode a value to CBOR bytes
  static Uint8List encode(dynamic value) {
    final encoder = CBOREncoder();
    encoder._encodeValue(value);
    return encoder._buffer.toBytes();
  }
  
  void _encodeValue(dynamic value) {
    if (value == null) {
      _encodeNull();
    } else if (value is bool) {
      _encodeBool(value);
    } else if (value is int) {
      _encodeInt(value);
    } else if (value is String) {
      _encodeString(value);
    } else if (value is Uint8List) {
      _encodeBytes(value);
    } else if (value is List<int>) {
      _encodeBytes(Uint8List.fromList(value));
    } else if (value is List) {
      _encodeArray(value);
    } else if (value is Map) {
      _encodeMap(value);
    } else {
      throw ArgumentError('Unsupported type: ${value.runtimeType}');
    }
  }
  
  void _encodeNull() {
    _buffer.addByte(0xF6); // null
  }
  
  void _encodeBool(bool value) {
    _buffer.addByte(value ? 0xF5 : 0xF4); // true : false
  }
  
  void _encodeInt(int value) {
    if (value >= 0) {
      _encodeUnsigned(value);
    } else {
      _encodeNegative(value);
    }
  }
  
  void _encodeUnsigned(int value) {
    if (value < 24) {
      _buffer.addByte(value);
    } else if (value < 256) {
      _buffer.addByte(0x18);
      _buffer.addByte(value);
    } else if (value < 65536) {
      _buffer.addByte(0x19);
      _buffer.add(_uint16Bytes(value));
    } else if (value < 4294967296) {
      _buffer.addByte(0x1A);
      _buffer.add(_uint32Bytes(value));
    } else {
      _buffer.addByte(0x1B);
      _buffer.add(_uint64Bytes(value));
    }
  }
  
  void _encodeNegative(int value) {
    final positive = -1 - value;
    if (positive < 24) {
      _buffer.addByte(0x20 | positive);
    } else if (positive < 256) {
      _buffer.addByte(0x38);
      _buffer.addByte(positive);
    } else if (positive < 65536) {
      _buffer.addByte(0x39);
      _buffer.add(_uint16Bytes(positive));
    } else if (positive < 4294967296) {
      _buffer.addByte(0x3A);
      _buffer.add(_uint32Bytes(positive));
    } else {
      _buffer.addByte(0x3B);
      _buffer.add(_uint64Bytes(positive));
    }
  }
  
  void _encodeString(String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;
    
    if (length < 24) {
      _buffer.addByte(0x60 | length);
    } else if (length < 256) {
      _buffer.addByte(0x78);
      _buffer.addByte(length);
    } else if (length < 65536) {
      _buffer.addByte(0x79);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(0x7A);
      _buffer.add(_uint32Bytes(length));
    }
    
    _buffer.add(bytes);
  }
  
  void _encodeBytes(Uint8List value) {
    final length = value.length;
    
    if (length < 24) {
      _buffer.addByte(0x40 | length);
    } else if (length < 256) {
      _buffer.addByte(0x58);
      _buffer.addByte(length);
    } else if (length < 65536) {
      _buffer.addByte(0x59);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(0x5A);
      _buffer.add(_uint32Bytes(length));
    }
    
    _buffer.add(value);
  }
  
  void _encodeArray(List value) {
    final length = value.length;
    
    if (length < 24) {
      _buffer.addByte(0x80 | length);
    } else if (length < 256) {
      _buffer.addByte(0x98);
      _buffer.addByte(length);
    } else if (length < 65536) {
      _buffer.addByte(0x99);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(0x9A);
      _buffer.add(_uint32Bytes(length));
    }
    
    for (final item in value) {
      _encodeValue(item);
    }
  }
  
  void _encodeMap(Map value) {
    final length = value.length;
    
    if (length < 24) {
      _buffer.addByte(0xA0 | length);
    } else if (length < 256) {
      _buffer.addByte(0xB8);
      _buffer.addByte(length);
    } else if (length < 65536) {
      _buffer.addByte(0xB9);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(0xBA);
      _buffer.add(_uint32Bytes(length));
    }
    
    for (final entry in value.entries) {
      _encodeValue(entry.key);
      _encodeValue(entry.value);
    }
  }
  
  Uint8List _uint16Bytes(int value) {
    return Uint8List.fromList([
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
  
  Uint8List _uint32Bytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
  
  Uint8List _uint64Bytes(int value) {
    return Uint8List.fromList([
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
}