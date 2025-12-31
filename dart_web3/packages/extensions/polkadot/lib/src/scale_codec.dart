import 'dart:typed_data';

/// Basic SCALE codec implementation
class ScaleCodec {
  /// Encode a compact integer
  static Uint8List encodeCompact(int value) {
    if (value < 64) {
      return Uint8List.fromList([value << 2]);
    } else if (value < 16384) {
      return Uint8List.fromList([(value << 2) | 1, value >> 6]);
    }
    // Simplified for this task
    return Uint8List(0);
  }

  /// Encode a fixed-length byte array
  static Uint8List encodeFixedBytes(Uint8List bytes) {
    return bytes;
  }
}
