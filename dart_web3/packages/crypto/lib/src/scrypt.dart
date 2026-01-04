import 'dart:typed_data';
import 'pbkdf2.dart';

class Scrypt {
  static Uint8List derive(
      Uint8List password, Uint8List salt, int n, int r, int p, int dkLen) {
    final b = Pbkdf2.deriveSha256(
      password: password,
      salt: salt,
      iterations: 1,
      keyLength: p * 128 * r,
    );

    for (var i = 0; i < p; i++) {
      _smix(b, i * 128 * r, r, n);
    }

    return Pbkdf2.deriveSha256(
      password: password,
      salt: b,
      iterations: 1,
      keyLength: dkLen,
    );
  }

  static void _smix(Uint8List b, int bOffset, int r, int n) {
    final x = Uint32List(32 * r);
    for (var i = 0; i < 32 * r; i++) {
      x[i] = _decodeLE32(b, bOffset + i * 4);
    }

    final v = List<Uint32List>.generate(n, (_) => Uint32List(32 * r));
    for (var i = 0; i < n; i++) {
      v[i].setAll(0, x);
      _blockMix(x, r);
    }

    for (var i = 0; i < n; i++) {
      final j = x[32 * r - 16] & (n - 1);
      final vj = v[j];
      for (var k = 0; k < 32 * r; k++) {
        x[k] ^= vj[k];
      }
      _blockMix(x, r);
    }

    for (var i = 0; i < 32 * r; i++) {
      _encodeLE32(b, bOffset + i * 4, x[i]);
    }
  }

  static void _blockMix(Uint32List x, int r) {
    final y = Uint32List(32 * r);
    final b = Uint32List(16);
    b.setRange(0, 16, x, 32 * r - 16);

    for (var i = 0; i < 2 * r; i++) {
      for (var j = 0; j < 16; j++) {
        b[j] ^= x[i * 16 + j];
      }
      _salsa20_8(b);
      final dest = (i.isEven) ? (i ~/ 2) * 16 : (r + (i ~/ 2)) * 16;
      y.setRange(dest, dest + 16, b);
    }
    x.setAll(0, y);
  }

  static void _salsa20_8(Uint32List x) {
    final z = Uint32List.fromList(x);
    for (var i = 0; i < 8; i += 2) {
      _qr(z, 0, 4, 8, 12);
      _qr(z, 5, 9, 13, 1);
      _qr(z, 10, 14, 2, 6);
      _qr(z, 15, 3, 7, 11);
      _qr(z, 0, 1, 2, 3);
      _qr(z, 5, 6, 7, 4);
      _qr(z, 10, 11, 8, 9);
      _qr(z, 15, 12, 13, 14);
    }
    for (var i = 0; i < 16; i++) {
      x[i] = (x[i] + z[i]) & 0xFFFFFFFF;
    }
  }

  static void _qr(Uint32List z, int a, int b, int c, int d) {
    z[b] ^= _rol((z[a] + z[d]) & 0xFFFFFFFF, 7);
    z[c] ^= _rol((z[b] + z[a]) & 0xFFFFFFFF, 9);
    z[d] ^= _rol((z[c] + z[b]) & 0xFFFFFFFF, 13);
    z[a] ^= _rol((z[d] + z[c]) & 0xFFFFFFFF, 18);
  }

  static int _rol(int value, int shift) {
    return ((value << shift) & 0xFFFFFFFF) |
        ((value & 0xFFFFFFFF) >>> (32 - shift));
  }

  static int _decodeLE32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static void _encodeLE32(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
    bytes[offset + 3] = (value >> 24) & 0xFF;
  }
}
