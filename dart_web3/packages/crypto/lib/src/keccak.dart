import 'dart:typed_data';
import 'package:web3_universal_core/web3_universal_core.dart';

/// Pure Dart implementation of Keccak-256 hash function.
///
/// This is the hash function used by Ethereum for address derivation,
/// transaction hashing, and other cryptographic operations.
///
/// Note: Ethereum uses Keccak-256, NOT SHA3-256. The difference is in the
/// padding byte: Keccak uses 0x01, SHA3 uses 0x06.
class Keccak256 {
  /// Computes Keccak-256 hash of the input data.
  ///
  /// Returns a 32-byte hash as Uint8List.
  static Uint8List hash(Uint8List data) {
    final result = _Keccak().update(data.toList()).digest();
    return Uint8List.fromList(result);
  }

  /// Computes Keccak-256 hash and returns it as a hex string.
  ///
  /// The input should be a hex string (with or without 0x prefix).
  /// The returned string includes the '0x' prefix.
  static String hashHex(String data) {
    final bytes = HexUtils.decode(data);
    final hashResult = hash(bytes);
    return HexUtils.encode(hashResult);
  }

  /// Computes Keccak-256 hash of UTF-8 encoded string.
  static Uint8List hashUtf8(String data) {
    final bytes = Uint8List.fromList(data.codeUnits);
    return hash(bytes);
  }
}

const int _mask8 = 0xFF;
const int _mask32 = 0xFFFFFFFF;

/// Internal Keccak implementation
class _Keccak {
  _Keccak() : digestLength = 32 {
    final capacity = digestLength * 2;
    if (capacity <= 0 || capacity > 128) {
      throw ArgumentError('Keccak: incorrect capacity');
    }
    blockSize = 200 - capacity;
  }

  /// digest length
  final int digestLength;

  /// temporary space for permutation (high bits)
  final List<int> _sh = List<int>.filled(25, 0);

  /// temporary space for permutation (low bits)
  final List<int> _sl = List<int>.filled(25, 0);

  /// hash state
  final List<int> _state = List<int>.filled(200, 0);

  /// position in state to XOR bytes into
  int _pos = 0;

  /// whether the hash was finalized
  bool _finished = false;

  /// block size
  late final int blockSize;

  /// Resets the hash computation to its initial state.
  _Keccak reset() {
    _zero(_sh);
    _zero(_sl);
    _zero(_state);
    _pos = 0;
    _finished = false;
    return this;
  }

  /// Updates the hash computation with the given data.
  _Keccak update(List<int> data) {
    if (_finished) {
      throw StateError("Keccak: can't update because hash was finished");
    }

    for (var i = 0; i < data.length; i++) {
      _state[_pos++] ^= data[i] & _mask8;

      if (_pos >= blockSize) {
        _keccakf(_sh, _sl, _state);
        _pos = 0;
      }
    }

    return this;
  }

  void _padAndPermute(int paddingByte) {
    _state[_pos] ^= paddingByte;
    _state[blockSize - 1] ^= 0x80;

    // Permute state.
    _keccakf(_sh, _sl, _state);

    // Set finished flag to true.
    _finished = true;
    _pos = 0;
  }

  void _squeeze(List<int> dst) {
    if (!_finished) {
      throw StateError('Keccak: squeezing before padAndPermute');
    }

    for (var i = 0; i < dst.length; i++) {
      if (_pos == blockSize) {
        // Permute.
        _keccakf(_sh, _sl, _state);
        _pos = 0;
      }
      dst[i] = _state[_pos++];
    }
  }

  /// Finalizes the hash computation and returns the digest.
  List<int> digest() {
    if (!_finished) {
      // Keccak uses 0x01 padding (not 0x06 like SHA3)
      _padAndPermute(0x01);
    } else {
      _pos = 0;
    }
    final out = List<int>.filled(digestLength, 0);
    _squeeze(out);
    return out;
  }
}

void _zero(List<int> list) {
  for (var i = 0; i < list.length; i++) {
    list[i] = 0;
  }
}

int _readUint32LE(List<int> buf, int offset) {
  return (buf[offset] & _mask8) |
      ((buf[offset + 1] & _mask8) << 8) |
      ((buf[offset + 2] & _mask8) << 16) |
      ((buf[offset + 3] & _mask8) << 24);
}

void _writeUint32LE(int value, List<int> buf, int offset) {
  buf[offset] = value & _mask8;
  buf[offset + 1] = (value >> 8) & _mask8;
  buf[offset + 2] = (value >> 16) & _mask8;
  buf[offset + 3] = (value >> 24) & _mask8;
}

final _hi = List<int>.unmodifiable(const [
  0x00000000,
  0x00000000,
  0x80000000,
  0x80000000,
  0x00000000,
  0x00000000,
  0x80000000,
  0x80000000,
  0x00000000,
  0x00000000,
  0x00000000,
  0x00000000,
  0x00000000,
  0x80000000,
  0x80000000,
  0x80000000,
  0x80000000,
  0x80000000,
  0x00000000,
  0x80000000,
  0x80000000,
  0x80000000,
  0x00000000,
  0x80000000,
]);

final _lo = List<int>.unmodifiable(const [
  0x00000001,
  0x00008082,
  0x0000808a,
  0x80008000,
  0x0000808b,
  0x80000001,
  0x80008081,
  0x00008009,
  0x0000008a,
  0x00000088,
  0x80008009,
  0x8000000a,
  0x8000808b,
  0x0000008b,
  0x00008089,
  0x00008003,
  0x00008002,
  0x00000080,
  0x0000800a,
  0x8000000a,
  0x80008081,
  0x00008080,
  0x80000001,
  0x80008008,
]);

void _keccakf(List<int> sh, List<int> sl, List<int> buf) {
  int bch0;
  int bch1;
  int bch2;
  int bch3;
  int bch4;
  int bcl0;
  int bcl1;
  int bcl2;
  int bcl3;
  int bcl4;
  int th;
  int tl;

  for (var i = 0; i < 25; i++) {
    sl[i] = _readUint32LE(buf, i * 8);
    sh[i] = _readUint32LE(buf, i * 8 + 4);
  }

  for (var r = 0; r < 24; r++) {
    // Theta
    bch0 = sh[0] ^ sh[5] ^ sh[10] ^ sh[15] ^ sh[20];
    bch1 = sh[1] ^ sh[6] ^ sh[11] ^ sh[16] ^ sh[21];
    bch2 = sh[2] ^ sh[7] ^ sh[12] ^ sh[17] ^ sh[22];
    bch3 = sh[3] ^ sh[8] ^ sh[13] ^ sh[18] ^ sh[23];
    bch4 = sh[4] ^ sh[9] ^ sh[14] ^ sh[19] ^ sh[24];
    bcl0 = sl[0] ^ sl[5] ^ sl[10] ^ sl[15] ^ sl[20];
    bcl1 = sl[1] ^ sl[6] ^ sl[11] ^ sl[16] ^ sl[21];
    bcl2 = sl[2] ^ sl[7] ^ sl[12] ^ sl[17] ^ sl[22];
    bcl3 = sl[3] ^ sl[8] ^ sl[13] ^ sl[18] ^ sl[23];
    bcl4 = sl[4] ^ sl[9] ^ sl[14] ^ sl[19] ^ sl[24];

    th = bch4 ^ ((bch1 << 1) | (bcl1 & _mask32) >> (32 - 1));
    tl = bcl4 ^ ((bcl1 << 1) | (bch1 & _mask32) >> (32 - 1));

    sh[0] ^= th;
    sh[5] ^= th;
    sh[10] ^= th;
    sh[15] ^= th;
    sh[20] ^= th;
    sl[0] ^= tl;
    sl[5] ^= tl;
    sl[10] ^= tl;
    sl[15] ^= tl;
    sl[20] ^= tl;

    th = bch0 ^ ((bch2 << 1) | (bcl2 & _mask32) >> (32 - 1));
    tl = bcl0 ^ ((bcl2 << 1) | (bch2 & _mask32) >> (32 - 1));

    sh[1] ^= th;
    sh[6] ^= th;
    sh[11] ^= th;
    sh[16] ^= th;
    sh[21] ^= th;
    sl[1] ^= tl;
    sl[6] ^= tl;
    sl[11] ^= tl;
    sl[16] ^= tl;
    sl[21] ^= tl;

    th = bch1 ^ ((bch3 << 1) | (bcl3 & _mask32) >> (32 - 1));
    tl = bcl1 ^ ((bcl3 << 1) | (bch3 & _mask32) >> (32 - 1));

    sh[2] ^= th;
    sh[7] ^= th;
    sh[12] ^= th;
    sh[17] ^= th;
    sh[22] ^= th;
    sl[2] ^= tl;
    sl[7] ^= tl;
    sl[12] ^= tl;
    sl[17] ^= tl;
    sl[22] ^= tl;

    th = bch2 ^ ((bch4 << 1) | (bcl4 & _mask32) >> (32 - 1));
    tl = bcl2 ^ ((bcl4 << 1) | (bch4 & _mask32) >> (32 - 1));

    sh[3] ^= th;
    sl[3] ^= tl;
    sh[8] ^= th;
    sl[8] ^= tl;
    sh[13] ^= th;
    sl[13] ^= tl;
    sh[18] ^= th;
    sl[18] ^= tl;
    sh[23] ^= th;
    sl[23] ^= tl;

    th = bch3 ^ ((bch0 << 1) | (bcl0 & _mask32) >> (32 - 1));
    tl = bcl3 ^ ((bcl0 << 1) | (bch0 & _mask32) >> (32 - 1));

    sh[4] ^= th;
    sh[9] ^= th;
    sh[14] ^= th;
    sh[19] ^= th;
    sh[24] ^= th;
    sl[4] ^= tl;
    sl[9] ^= tl;
    sl[14] ^= tl;
    sl[19] ^= tl;
    sl[24] ^= tl;

    // Rho Pi
    th = sh[1];
    tl = sl[1];
    bch0 = sh[10];
    bcl0 = sl[10];
    sh[10] = (th << 1) | (tl & _mask32) >> (32 - 1);
    sl[10] = (tl << 1) | (th & _mask32) >> (32 - 1);

    th = bch0;
    tl = bcl0;
    bch0 = sh[7];
    bcl0 = sl[7];
    sh[7] = (th << 3) | (tl & _mask32) >> (32 - 3);
    sl[7] = (tl << 3) | (th & _mask32) >> (32 - 3);

    th = bch0;
    tl = bcl0;
    bch0 = sh[11];
    bcl0 = sl[11];
    sh[11] = (th << 6) | (tl & _mask32) >> (32 - 6);
    sl[11] = (tl << 6) | (th & _mask32) >> (32 - 6);

    th = bch0;
    tl = bcl0;
    bch0 = sh[17];
    bcl0 = sl[17];
    sh[17] = (th << 10) | (tl & _mask32) >> (32 - 10);
    sl[17] = (tl << 10) | (th & _mask32) >> (32 - 10);

    th = bch0;
    tl = bcl0;
    bch0 = sh[18];
    bcl0 = sl[18];
    sh[18] = (th << 15) | (tl & _mask32) >> (32 - 15);
    sl[18] = (tl << 15) | (th & _mask32) >> (32 - 15);

    th = bch0;
    tl = bcl0;
    bch0 = sh[3];
    bcl0 = sl[3];
    sh[3] = (th << 21) | (tl & _mask32) >> (32 - 21);
    sl[3] = (tl << 21) | (th & _mask32) >> (32 - 21);

    th = bch0;
    tl = bcl0;
    bch0 = sh[5];
    bcl0 = sl[5];
    sh[5] = (th << 28) | (tl & _mask32) >> (32 - 28);
    sl[5] = (tl << 28) | (th & _mask32) >> (32 - 28);

    th = bch0;
    tl = bcl0;
    bch0 = sh[16];
    bcl0 = sl[16];
    sh[16] = (tl << 4) | (th & _mask32) >> (32 - 4);
    sl[16] = (th << 4) | (tl & _mask32) >> (32 - 4);

    th = bch0;
    tl = bcl0;
    bch0 = sh[8];
    bcl0 = sl[8];
    sh[8] = (tl << 13) | (th & _mask32) >> (32 - 13);
    sl[8] = (th << 13) | (tl & _mask32) >> (32 - 13);

    th = bch0;
    tl = bcl0;
    bch0 = sh[21];
    bcl0 = sl[21];
    sh[21] = (tl << 23) | (th & _mask32) >> (32 - 23);
    sl[21] = (th << 23) | (tl & _mask32) >> (32 - 23);

    th = bch0;
    tl = bcl0;
    bch0 = sh[24];
    bcl0 = sl[24];
    sh[24] = (th << 2) | (tl & _mask32) >> (32 - 2);
    sl[24] = (tl << 2) | (th & _mask32) >> (32 - 2);

    th = bch0;
    tl = bcl0;
    bch0 = sh[4];
    bcl0 = sl[4];
    sh[4] = (th << 14) | (tl & _mask32) >> (32 - 14);
    sl[4] = (tl << 14) | (th & _mask32) >> (32 - 14);

    th = bch0;
    tl = bcl0;
    bch0 = sh[15];
    bcl0 = sl[15];
    sh[15] = (th << 27) | (tl & _mask32) >> (32 - 27);
    sl[15] = (tl << 27) | (th & _mask32) >> (32 - 27);

    th = bch0;
    tl = bcl0;
    bch0 = sh[23];
    bcl0 = sl[23];
    sh[23] = (tl << 9) | (th & _mask32) >> (32 - 9);
    sl[23] = (th << 9) | (tl & _mask32) >> (32 - 9);

    th = bch0;
    tl = bcl0;
    bch0 = sh[19];
    bcl0 = sl[19];
    sh[19] = (tl << 24) | (th & _mask32) >> (32 - 24);
    sl[19] = (th << 24) | (tl & _mask32) >> (32 - 24);

    th = bch0;
    tl = bcl0;
    bch0 = sh[13];
    bcl0 = sl[13];
    sh[13] = (th << 8) | (tl & _mask32) >> (32 - 8);
    sl[13] = (tl << 8) | (th & _mask32) >> (32 - 8);

    th = bch0;
    tl = bcl0;
    bch0 = sh[12];
    bcl0 = sl[12];
    sh[12] = (th << 25) | (tl & _mask32) >> (32 - 25);
    sl[12] = (tl << 25) | (th & _mask32) >> (32 - 25);

    th = bch0;
    tl = bcl0;
    bch0 = sh[2];
    bcl0 = sl[2];
    sh[2] = (tl << 11) | (th & _mask32) >> (32 - 11);
    sl[2] = (th << 11) | (tl & _mask32) >> (32 - 11);

    th = bch0;
    tl = bcl0;
    bch0 = sh[20];
    bcl0 = sl[20];
    sh[20] = (tl << 30) | (th & _mask32) >> (32 - 30);
    sl[20] = (th << 30) | (tl & _mask32) >> (32 - 30);

    th = bch0;
    tl = bcl0;
    bch0 = sh[14];
    bcl0 = sl[14];
    sh[14] = (th << 18) | (tl & _mask32) >> (32 - 18);
    sl[14] = (tl << 18) | (th & _mask32) >> (32 - 18);

    th = bch0;
    tl = bcl0;
    bch0 = sh[22];
    bcl0 = sl[22];
    sh[22] = (tl << 7) | (th & _mask32) >> (32 - 7);
    sl[22] = (th << 7) | (tl & _mask32) >> (32 - 7);

    th = bch0;
    tl = bcl0;
    bch0 = sh[9];
    bcl0 = sl[9];
    sh[9] = (tl << 29) | (th & _mask32) >> (32 - 29);
    sl[9] = (th << 29) | (tl & _mask32) >> (32 - 29);

    th = bch0;
    tl = bcl0;
    bch0 = sh[6];
    bcl0 = sl[6];
    sh[6] = (th << 20) | (tl & _mask32) >> (32 - 20);
    sl[6] = (tl << 20) | (th & _mask32) >> (32 - 20);

    th = bch0;
    tl = bcl0;
    sh[1] = (tl << 12) | (th & _mask32) >> (32 - 12);
    sl[1] = (th << 12) | (tl & _mask32) >> (32 - 12);

    // Chi
    bch0 = sh[0];
    bch1 = sh[1];
    bch2 = sh[2];
    bch3 = sh[3];
    bch4 = sh[4];
    sh[0] ^= (~bch1) & bch2;
    sh[1] ^= (~bch2) & bch3;
    sh[2] ^= (~bch3) & bch4;
    sh[3] ^= (~bch4) & bch0;
    sh[4] ^= (~bch0) & bch1;
    bcl0 = sl[0];
    bcl1 = sl[1];
    bcl2 = sl[2];
    bcl3 = sl[3];
    bcl4 = sl[4];
    sl[0] ^= (~bcl1) & bcl2;
    sl[1] ^= (~bcl2) & bcl3;
    sl[2] ^= (~bcl3) & bcl4;
    sl[3] ^= (~bcl4) & bcl0;
    sl[4] ^= (~bcl0) & bcl1;

    bch0 = sh[5];
    bch1 = sh[6];
    bch2 = sh[7];
    bch3 = sh[8];
    bch4 = sh[9];
    sh[5] ^= (~bch1) & bch2;
    sh[6] ^= (~bch2) & bch3;
    sh[7] ^= (~bch3) & bch4;
    sh[8] ^= (~bch4) & bch0;
    sh[9] ^= (~bch0) & bch1;
    bcl0 = sl[5];
    bcl1 = sl[6];
    bcl2 = sl[7];
    bcl3 = sl[8];
    bcl4 = sl[9];
    sl[5] ^= (~bcl1) & bcl2;
    sl[6] ^= (~bcl2) & bcl3;
    sl[7] ^= (~bcl3) & bcl4;
    sl[8] ^= (~bcl4) & bcl0;
    sl[9] ^= (~bcl0) & bcl1;

    bch0 = sh[10];
    bch1 = sh[11];
    bch2 = sh[12];
    bch3 = sh[13];
    bch4 = sh[14];
    sh[10] ^= (~bch1) & bch2;
    sh[11] ^= (~bch2) & bch3;
    sh[12] ^= (~bch3) & bch4;
    sh[13] ^= (~bch4) & bch0;
    sh[14] ^= (~bch0) & bch1;
    bcl0 = sl[10];
    bcl1 = sl[11];
    bcl2 = sl[12];
    bcl3 = sl[13];
    bcl4 = sl[14];
    sl[10] ^= (~bcl1) & bcl2;
    sl[11] ^= (~bcl2) & bcl3;
    sl[12] ^= (~bcl3) & bcl4;
    sl[13] ^= (~bcl4) & bcl0;
    sl[14] ^= (~bcl0) & bcl1;

    bch0 = sh[15];
    bch1 = sh[16];
    bch2 = sh[17];
    bch3 = sh[18];
    bch4 = sh[19];
    sh[15] ^= (~bch1) & bch2;
    sh[16] ^= (~bch2) & bch3;
    sh[17] ^= (~bch3) & bch4;
    sh[18] ^= (~bch4) & bch0;
    sh[19] ^= (~bch0) & bch1;
    bcl0 = sl[15];
    bcl1 = sl[16];
    bcl2 = sl[17];
    bcl3 = sl[18];
    bcl4 = sl[19];
    sl[15] ^= (~bcl1) & bcl2;
    sl[16] ^= (~bcl2) & bcl3;
    sl[17] ^= (~bcl3) & bcl4;
    sl[18] ^= (~bcl4) & bcl0;
    sl[19] ^= (~bcl0) & bcl1;

    bch0 = sh[20];
    bch1 = sh[21];
    bch2 = sh[22];
    bch3 = sh[23];
    bch4 = sh[24];
    sh[20] ^= (~bch1) & bch2;
    sh[21] ^= (~bch2) & bch3;
    sh[22] ^= (~bch3) & bch4;
    sh[23] ^= (~bch4) & bch0;
    sh[24] ^= (~bch0) & bch1;
    bcl0 = sl[20];
    bcl1 = sl[21];
    bcl2 = sl[22];
    bcl3 = sl[23];
    bcl4 = sl[24];
    sl[20] ^= (~bcl1) & bcl2;
    sl[21] ^= (~bcl2) & bcl3;
    sl[22] ^= (~bcl3) & bcl4;
    sl[23] ^= (~bcl4) & bcl0;
    sl[24] ^= (~bcl0) & bcl1;

    // Iota
    sh[0] ^= _hi[r];
    sl[0] ^= _lo[r];
  }

  // Write state back to buffer
  for (var i = 0; i < 25; i++) {
    _writeUint32LE(sl[i], buf, i * 8);
    _writeUint32LE(sh[i], buf, i * 8 + 4);
  }
}
