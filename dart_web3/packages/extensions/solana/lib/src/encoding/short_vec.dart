import 'dart:typed_data';

class ShortVec {
  static Uint8List encodeLength(int len) {
    final out = BytesBuilder();
    var remLen = len;
    for (;;) {
      var elem = remLen & 0x7f;
      remLen >>= 7;
      if (remLen == 0) {
        out.addByte(elem);
        break;
      } else {
        elem |= 0x80;
        out.addByte(elem);
      }
    }
    return out.toBytes();
  }

  static int decodeLength(Uint8List bytes, {int offset = 0}) {
    var len = 0;
    var size = 0;
    for (;;) {
      final elem = bytes[offset + size];
      len |= (elem & 0x7f) << (size * 7);
      size += 1;
      if ((elem & 0x80) == 0) {
        break;
      }
    }
    return len;
  }

  static int encodeLengthSize(int len) {
    var size = 1;
    var remLen = len;
    while (remLen >= 0x80) {
      remLen >>= 7;
      size += 1;
    }
    return size;
  }
}
