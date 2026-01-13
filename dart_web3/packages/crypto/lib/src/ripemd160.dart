import 'dart:typed_data';
import 'sha2.dart';

/// RIPEMD-160 hash function.
///
/// Produces a 160-bit (20-byte) hash value.
/// Used in Bitcoin/BIP-32 for HASH160 = RIPEMD160(SHA256(data)).
///
/// Based on the original specification by Hans Dobbertin, Antoon Bosselaers,
/// and Bart Preneel: "RIPEMD-160: A Strengthened Version of RIPEMD" (1996).
class Ripemd160 {
  Ripemd160._();

  /// Computes RIPEMD-160 hash of the input data.
  ///
  /// Returns a 20-byte hash.
  static Uint8List hash(Uint8List data) {
    final impl = _Ripemd160Impl();
    impl.update(data);
    return impl.digest();
  }

  /// Computes HASH160: RIPEMD160(SHA256(data)).
  ///
  /// Used in Bitcoin/BIP-32 for address derivation and fingerprints.
  /// Returns a 20-byte hash.
  static Uint8List hash160(Uint8List data) {
    return hash(Sha256.hash(data));
  }
}

/// Internal RIPEMD-160 implementation.
class _Ripemd160Impl {
  static const _blockSize = 64; // 512 bits
  static const _digestSize = 20; // 160 bits

  // Initial hash values (little-endian)
  final _state = Uint32List.fromList([
    0x67452301,
    0xefcdab89,
    0x98badcfe,
    0x10325476,
    0xc3d2e1f0,
  ]);

  final _buffer = Uint8List(_blockSize);
  var _bufferLength = 0;
  var _messageLength = 0;

  void update(Uint8List data) {
    for (final byte in data) {
      _buffer[_bufferLength++] = byte;
      _messageLength++;
      if (_bufferLength == _blockSize) {
        _processBlock();
        _bufferLength = 0;
      }
    }
  }

  Uint8List digest() {
    // Padding: append bit '1' followed by zeros
    final bitLength = _messageLength * 8;
    _buffer[_bufferLength++] = 0x80;

    // If not enough room for length, process current block and start new one
    if (_bufferLength > 56) {
      while (_bufferLength < _blockSize) {
        _buffer[_bufferLength++] = 0;
      }
      _processBlock();
      _bufferLength = 0;
    }

    // Pad with zeros up to position 56
    while (_bufferLength < 56) {
      _buffer[_bufferLength++] = 0;
    }

    // Append original message length in bits as 64-bit little-endian
    for (var i = 0; i < 8; i++) {
      _buffer[56 + i] = (bitLength >> (i * 8)) & 0xff;
    }
    _processBlock();

    // Output state as little-endian bytes
    final result = Uint8List(_digestSize);
    for (var i = 0; i < 5; i++) {
      result[i * 4] = _state[i] & 0xff;
      result[i * 4 + 1] = (_state[i] >> 8) & 0xff;
      result[i * 4 + 2] = (_state[i] >> 16) & 0xff;
      result[i * 4 + 3] = (_state[i] >> 24) & 0xff;
    }
    return result;
  }

  void _processBlock() {
    // Parse block into 16 32-bit words (little-endian)
    final x = Uint32List(16);
    for (var i = 0; i < 16; i++) {
      x[i] = _buffer[i * 4] |
          (_buffer[i * 4 + 1] << 8) |
          (_buffer[i * 4 + 2] << 16) |
          (_buffer[i * 4 + 3] << 24);
    }

    // Initialize working variables
    var al = _state[0];
    var bl = _state[1];
    var cl = _state[2];
    var dl = _state[3];
    var el = _state[4];
    var ar = _state[0];
    var br = _state[1];
    var cr = _state[2];
    var dr = _state[3];
    var er = _state[4];

    // 80 rounds - left line
    for (var j = 0; j < 80; j++) {
      final f = _fLeft(j, bl, cl, dl);
      final k = _kLeft[j ~/ 16];
      final r = _rLeft[j];
      final s = _sLeft[j];

      var t = _add32(al, f);
      t = _add32(t, x[r]);
      t = _add32(t, k);
      t = _rotl32(t, s);
      t = _add32(t, el);

      al = el;
      el = dl;
      dl = _rotl32(cl, 10);
      cl = bl;
      bl = t;
    }

    // 80 rounds - right line
    for (var j = 0; j < 80; j++) {
      final f = _fRight(j, br, cr, dr);
      final k = _kRight[j ~/ 16];
      final r = _rRight[j];
      final s = _sRight[j];

      var t = _add32(ar, f);
      t = _add32(t, x[r]);
      t = _add32(t, k);
      t = _rotl32(t, s);
      t = _add32(t, er);

      ar = er;
      er = dr;
      dr = _rotl32(cr, 10);
      cr = br;
      br = t;
    }

    // Final addition
    final t = _add32(_add32(_state[1], cl), dr);
    _state[1] = _add32(_add32(_state[2], dl), er);
    _state[2] = _add32(_add32(_state[3], el), ar);
    _state[3] = _add32(_add32(_state[4], al), br);
    _state[4] = _add32(_add32(_state[0], bl), cr);
    _state[0] = t;
  }

  // Nonlinear functions for left line
  static int _fLeft(int j, int x, int y, int z) {
    if (j < 16) return x ^ y ^ z;
    if (j < 32) return (x & y) | (~x & z);
    if (j < 48) return (x | ~y) ^ z;
    if (j < 64) return (x & z) | (y & ~z);
    return x ^ (y | ~z);
  }

  // Nonlinear functions for right line (reverse order)
  static int _fRight(int j, int x, int y, int z) {
    if (j < 16) return x ^ (y | ~z);
    if (j < 32) return (x & z) | (y & ~z);
    if (j < 48) return (x | ~y) ^ z;
    if (j < 64) return (x & y) | (~x & z);
    return x ^ y ^ z;
  }

  // 32-bit addition with overflow
  static int _add32(int a, int b) => (a + b) & 0xffffffff;

  // Left rotation
  static int _rotl32(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xffffffff;

  // Constants for left line
  static const _kLeft = [
    0x00000000, // rounds 0-15
    0x5a827999, // rounds 16-31
    0x6ed9eba1, // rounds 32-47
    0x8f1bbcdc, // rounds 48-63
    0xa953fd4e, // rounds 64-79
  ];

  // Constants for right line
  static const _kRight = [
    0x50a28be6, // rounds 0-15
    0x5c4dd124, // rounds 16-31
    0x6d703ef3, // rounds 32-47
    0x7a6d76e9, // rounds 48-63
    0x00000000, // rounds 64-79
  ];

  // Message word selection for left line
  static const _rLeft = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, // round 0-15
    7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8, // round 16-31
    3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12, // round 32-47
    1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2, // round 48-63
    4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13, // round 64-79
  ];

  // Message word selection for right line
  static const _rRight = [
    5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12, // round 0-15
    6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2, // round 16-31
    15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13, // round 32-47
    8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14, // round 48-63
    12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11, // round 64-79
  ];

  // Rotation amounts for left line
  static const _sLeft = [
    11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8, // round 0-15
    7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12, // round 16-31
    11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5, // round 32-47
    11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12, // round 48-63
    9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6, // round 64-79
  ];

  // Rotation amounts for right line
  static const _sRight = [
    8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6, // round 0-15
    9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11, // round 16-31
    9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5, // round 32-47
    15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8, // round 48-63
    8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11, // round 64-79
  ];
}
