import 'dart:typed_data';

class ShortVec {
  static Uint8List encodeLength(int len) {
    final out = BytesBuilder();
    var rem_len = len;
    for (;;) {
      var elem = rem_len & 0x7f;
      rem_len >>= 7;
      if (rem_len == 0) {
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
     var rem_len = len;
     while (rem_len >= 0x80) {
         rem_len >>= 7;
         size += 1;
     }
     return size;
  }
}
