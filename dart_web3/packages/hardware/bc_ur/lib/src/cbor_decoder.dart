import 'dart:convert';
import 'dart:typed_data';

/// Simple CBOR decoder for BC-UR
/// Implements subset of CBOR needed for BC-UR communication
class CBORDecoder {
  late Uint8List _data;
  int _offset = 0;

  /// Decode CBOR bytes to a value
  static dynamic decode(Uint8List data) {
    final decoder = CBORDecoder();
    decoder._data = data;
    decoder._offset = 0;
    return decoder._decodeValue();
  }

  dynamic _decodeValue() {
    if (_offset >= _data.length) {
      throw FormatException('Unexpected end of CBOR data');
    }

    final byte = _data[_offset++];
    final majorType = (byte >> 5) & 0x07;
    final additionalInfo = byte & 0x1F;

    switch (majorType) {
      case 0: // Unsigned integer
        return _decodeUnsigned(additionalInfo);
      case 1: // Negative integer
        return -1 - _decodeUnsigned(additionalInfo);
      case 2: // Byte string
        return _decodeBytes(additionalInfo);
      case 3: // Text string
        return _decodeString(additionalInfo);
      case 4: // Array
        return _decodeArray(additionalInfo);
      case 5: // Map
        return _decodeMap(additionalInfo);
      case 7: // Primitives
        return _decodePrimitive(additionalInfo);
      default:
        throw FormatException('Unsupported CBOR major type: $majorType');
    }
  }

  int _decodeUnsigned(int additionalInfo) {
    if (additionalInfo < 24) {
      return additionalInfo;
    } else if (additionalInfo == 24) {
      return _readUint8();
    } else if (additionalInfo == 25) {
      return _readUint16();
    } else if (additionalInfo == 26) {
      return _readUint32();
    } else if (additionalInfo == 27) {
      return _readUint64();
    } else {
      throw FormatException(
          'Invalid additional info for unsigned integer: $additionalInfo');
    }
  }

  Uint8List _decodeBytes(int additionalInfo) {
    final length = _decodeUnsigned(additionalInfo);
    if (_offset + length > _data.length) {
      throw FormatException('Not enough data for byte string');
    }

    final result = _data.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }

  String _decodeString(int additionalInfo) {
    final bytes = _decodeBytes(additionalInfo);
    return utf8.decode(bytes);
  }

  List<dynamic> _decodeArray(int additionalInfo) {
    final length = _decodeUnsigned(additionalInfo);
    final result = <dynamic>[];

    for (var i = 0; i < length; i++) {
      result.add(_decodeValue());
    }

    return result;
  }

  Map<dynamic, dynamic> _decodeMap(int additionalInfo) {
    final length = _decodeUnsigned(additionalInfo);
    final result = <dynamic, dynamic>{};

    for (var i = 0; i < length; i++) {
      final key = _decodeValue();
      final value = _decodeValue();
      result[key] = value;
    }

    return result;
  }

  dynamic _decodePrimitive(int additionalInfo) {
    switch (additionalInfo) {
      case 20: // false
        return false;
      case 21: // true
        return true;
      case 22: // null
        return null;
      default:
        throw FormatException('Unsupported primitive: $additionalInfo');
    }
  }

  int _readUint8() {
    if (_offset >= _data.length) {
      throw FormatException('Not enough data for uint8');
    }
    return _data[_offset++];
  }

  int _readUint16() {
    if (_offset + 2 > _data.length) {
      throw FormatException('Not enough data for uint16');
    }
    final result = (_data[_offset] << 8) | _data[_offset + 1];
    _offset += 2;
    return result;
  }

  int _readUint32() {
    if (_offset + 4 > _data.length) {
      throw FormatException('Not enough data for uint32');
    }
    final result = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return result;
  }

  int _readUint64() {
    if (_offset + 8 > _data.length) {
      throw FormatException('Not enough data for uint64');
    }

    var result = 0;
    for (var i = 0; i < 8; i++) {
      result = (result << 8) | _data[_offset + i];
    }
    _offset += 8;
    return result;
  }
}
