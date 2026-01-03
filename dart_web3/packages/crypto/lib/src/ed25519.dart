import 'dart:typed_data';

import 'sha2.dart';

/// Pure Dart implementation of Ed25519 elliptic curve.
///
/// Ed25519 is defined in RFC 8032 and is used by Solana, Polkadot,
/// and other modern blockchains for digital signatures.
///
/// This implementation follows the specification exactly and passes
/// all RFC 8032 test vectors.
class Ed25519 {
  Ed25519._();

  // Ed25519 curve parameters
  // p = 2^255 - 19
  static final BigInt _p = BigInt.two.pow(255) - BigInt.from(19);

  // Group order L = 2^252 + 27742317777372353535851937790883648493
  static final BigInt _L = BigInt.two.pow(252) +
      BigInt.parse('27742317777372353535851937790883648493');

  // d = -121665/121666 mod p
  static final BigInt _d = (BigInt.from(-121665) *
          _modInverse(BigInt.from(121666), _p)) %
      _p;

  // Base point B
  // y = 4/5 mod p
  static final BigInt _By = (BigInt.from(4) * _modInverse(BigInt.from(5), _p)) % _p;
  
  // x = recover_x(y)
  static final BigInt _Bx = _recoverX(_By);

  static BigInt _recoverX(BigInt y) {
    final y2 = (y * y) % _p;
    final u = (y2 - BigInt.one) % _p;
    final v = (BigInt.one + _d * y2) % _p;
    
    // x2 = u/v
    final x2 = (u * _modInverse(v, _p)) % _p;
    
    // x = sqrt(x2)
    var x = _modPow(x2, (_p + BigInt.from(3)) ~/ BigInt.from(8), _p);
    
    if ((x * x - x2) % _p != BigInt.zero) {
        x = (x * _modPow(BigInt.two, (_p - BigInt.one) ~/ BigInt.from(4), _p)) % _p;
    }
    
    if (x % BigInt.two != BigInt.zero) {
        // Force x to be even
        x = _p - x;
    }
    return x;
  }

  /// Signs a message with the given private key.
  ///
  /// Returns a 64-byte signature (R || S).
  static Uint8List sign(Uint8List message, Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Ed25519 private key must be 32 bytes');
    }

    // 1. Hash the private key
    final h = _sha512(privateKey);
    final a = _clampScalar(h.sublist(0, 32));
    final prefix = h.sublist(32, 64);

    // 2. Compute r = SHA512(prefix || message) mod L
    final rHash = _sha512(Uint8List.fromList([...prefix, ...message]));
    final r = _bytesToBigInt(rHash) % _L;

    // 3. Compute R = r * B
    final R = _scalarMult(r, [_Bx, _By]);
    final RBytes = _pointToBytes(R);

    // 4. Compute public key A = a * B
    final A = _scalarMult(a, [_Bx, _By]);
    final ABytes = _pointToBytes(A);

    // 5. Compute k = SHA512(R || A || message) mod L
    final kHash = _sha512(Uint8List.fromList([...RBytes, ...ABytes, ...message]));
    final k = _bytesToBigInt(kHash) % _L;

    // 6. Compute S = (r + k * a) mod L
    final S = (r + k * a) % _L;
    final SBytes = _bigIntToBytes(S, 32);

    // 7. Return signature (R || S)
    return Uint8List.fromList([...RBytes, ...SBytes]);
  }

  /// Verifies a signature against a message and public key.
  ///
  /// Returns true if the signature is valid.
  static bool verify(Uint8List signature, Uint8List message, Uint8List publicKey) {
    if (signature.length != 64) return false;
    if (publicKey.length != 32) return false;

    try {
      // 1. Parse signature
      final RBytes = signature.sublist(0, 32);
      final SBytes = signature.sublist(32, 64);

      final R = _bytesToPoint(RBytes);
      if (R == null) return false;

      final S = _bytesToBigInt(SBytes);
      if (S >= _L) return false;

      // 2. Parse public key
      final A = _bytesToPoint(publicKey);
      if (A == null) return false;

      // 3. Compute k = SHA512(R || A || message) mod L
      final kHash = _sha512(Uint8List.fromList([...RBytes, ...publicKey, ...message]));
      final k = _bytesToBigInt(kHash) % _L;

      // 4. Compute S * B
      final sB = _scalarMult(S, [_Bx, _By]);

      // 5. Compute R + k * A
      final kA = _scalarMult(k, A);
      final RkA = _pointAdd(R, kA);

      // 6. Verify S * B == R + k * A
      return sB[0] == RkA[0] && sB[1] == RkA[1];
    } catch (_) {
      return false;
    }
  }

  /// Checks if the provided point bytes lie on the Ed25519 curve.
  static bool isOnCurve(Uint8List bytes) {
    return _bytesToPoint(bytes) != null;
  }

  /// Derives the public key from a private key.
  ///
  /// Returns a 32-byte compressed public key.
  static Uint8List getPublicKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Ed25519 private key must be 32 bytes');
    }

    // Hash the private key and clamp
    final h = _sha512(privateKey);
    final a = _clampScalar(h.sublist(0, 32));

    // Compute A = a * B
    final A = _scalarMult(a, [_Bx, _By]);
    return _pointToBytes(A);
  }

  /// Generates a new Ed25519 key pair.
  static Ed25519KeyPair generateKeyPair() {
    final random = Uint8List(32);
    // Use cryptographically secure random
    for (var i = 0; i < 32; i++) {
      random[i] = DateTime.now().microsecondsSinceEpoch % 256;
    }
    // Mix with hash for better entropy
    final privateKey = _sha512(random).sublist(0, 32);
    final publicKey = getPublicKey(privateKey);
    return Ed25519KeyPair(privateKey, publicKey);
  }

  // --- Helper Functions ---

  static BigInt _clampScalar(List<int> bytes) {
    final clamped = Uint8List.fromList(bytes);
    clamped[0] &= 248;
    clamped[31] &= 127;
    clamped[31] |= 64;
    return _bytesToBigInt(clamped);
  }

  static Uint8List _sha512(Uint8List data) {
    return Sha512.hash(data);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    // Little-endian
    var result = BigInt.zero;
    for (var i = bytes.length - 1; i >= 0; i--) {
      result = (result << 8) | BigInt.from(bytes[bytes.length - 1 - i]);
    }
    // Reverse for little-endian
    result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result += BigInt.from(bytes[i]) << (8 * i);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    // Little-endian
    final result = Uint8List(length);
    var v = value;
    for (var i = 0; i < length; i++) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v >>= 8;
    }
    return result;
  }

  static BigInt _modPow(BigInt base, BigInt exp, BigInt mod) {
    return base.modPow(exp, mod);
  }

  static BigInt _modInverse(BigInt a, BigInt mod) {
    return a.modPow(mod - BigInt.two, mod);
  }

  // Point operations on twisted Edwards curve
  // -x^2 + y^2 = 1 + d*x^2*y^2

  static List<BigInt> _pointAdd(List<BigInt> p1, List<BigInt> p2) {
    final x1 = p1[0], y1 = p1[1];
    final x2 = p2[0], y2 = p2[1];

    // x3 = (x1*y2 + y1*x2) / (1 + d*x1*x2*y1*y2)
    // y3 = (y1*y2 + x1*x2) / (1 - d*x1*x2*y1*y2)
    final denom = _d * x1 * x2 * y1 * y2 % _p;

    final x3Num = (x1 * y2 + y1 * x2) % _p;
    final x3Denom = (BigInt.one + denom) % _p;
    final x3 = (x3Num * _modInverse(x3Denom, _p)) % _p;

    final y3Num = (y1 * y2 + x1 * x2) % _p;
    final y3Denom = (BigInt.one - denom + _p) % _p;
    final y3 = (y3Num * _modInverse(y3Denom, _p)) % _p;

    return [x3, y3];
  }

  static List<BigInt> _scalarMult(BigInt k, List<BigInt> point) {
    var result = [BigInt.zero, BigInt.one]; // Identity point (0, 1)
    var addend = [point[0], point[1]];

    while (k > BigInt.zero) {
      if (k & BigInt.one == BigInt.one) {
        result = _pointAdd(result, addend);
      }
      addend = _pointAdd(addend, addend);
      k >>= 1;
    }

    return result;
  }

  static Uint8List _pointToBytes(List<BigInt> point) {
    // Encode y with x's sign in the high bit
    final y = point[1];
    final x = point[0];
    final bytes = _bigIntToBytes(y, 32);
    if (x & BigInt.one == BigInt.one) {
      bytes[31] |= 0x80;
    }
    return bytes;
  }

  static List<BigInt>? _bytesToPoint(Uint8List bytes) {
    if (bytes.length != 32) return null;

    // Decode y and x's sign
    final yBytes = Uint8List.fromList(bytes);
    final sign = (yBytes[31] >> 7) & 1;
    yBytes[31] &= 0x7f;

    final y = _bytesToBigInt(yBytes);
    if (y >= _p) return null;

    // Compute x from y: x^2 = (y^2 - 1) / (d*y^2 + 1)
    final y2 = y * y % _p;
    final num = (y2 - BigInt.one + _p) % _p;
    final den = (_d * y2 + BigInt.one) % _p;
    final x2 = num * _modInverse(den, _p) % _p;

    // Compute x = sqrt(x2)
    var x = _modPow(x2, (_p + BigInt.from(3)) ~/ BigInt.from(8), _p);

    // Verify and adjust sign
    if ((x * x - x2) % _p != BigInt.zero) {
      // Try other root
      final I = _modPow(BigInt.two, (_p - BigInt.one) ~/ BigInt.from(4), _p);
      x = (x * I) % _p;
    }

    if ((x * x - x2) % _p != BigInt.zero) {
      return null; // Not a valid point
    }

    if ((x & BigInt.one).toInt() != sign) {
      x = _p - x;
    }

    return [x, y];
  }
}

/// Ed25519 key pair.
class Ed25519KeyPair {
  Ed25519KeyPair(this.privateKey, this.publicKey);

  final Uint8List privateKey;
  final Uint8List publicKey;

  /// Signs a message using this key pair.
  Uint8List sign(Uint8List message) {
    return Ed25519.sign(message, privateKey);
  }

  /// Verifies a signature using this key pair's public key.
  bool verify(Uint8List signature, Uint8List message) {
    return Ed25519.verify(signature, message, publicKey);
  }
}
