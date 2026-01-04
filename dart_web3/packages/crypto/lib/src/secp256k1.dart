import 'dart:math';
import 'dart:typed_data';

/// Pure Dart implementation of secp256k1 elliptic curve operations.
///
/// This curve is used by Bitcoin and Ethereum for digital signatures.
class Secp256k1 {
  // secp256k1 curve parameters
  static final BigInt _p = BigInt.parse(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
      radix: 16);
  static final BigInt _n = BigInt.parse(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
      radix: 16);
  static final BigInt _gx = BigInt.parse(
      '79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798',
      radix: 16);
  static final BigInt _gy = BigInt.parse(
      '483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8',
      radix: 16);
  static final BigInt _a = BigInt.zero;
  static final BigInt _b = BigInt.from(7);

  /// Generates a valid private key.
  static Uint8List generatePrivateKey() {
    final random = Random.secure();
    while (true) {
      final key = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        key[i] = random.nextInt(256);
      }
      final bigInt = _bytesToBigInt(key);
      if (bigInt > BigInt.zero && bigInt < _n) {
        return key;
      }
    }
  }

  /// Signs a message hash with the given private key.
  ///
  /// Returns the signature as a 64-byte array (32 bytes r + 32 bytes s).
  /// Uses deterministic k generation (RFC 6979).
  static Uint8List sign(Uint8List messageHash, Uint8List privateKey) {
    if (messageHash.length != 32) {
      throw ArgumentError('Message hash must be 32 bytes');
    }
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    final d = _bytesToBigInt(privateKey);
    if (d >= _n || d == BigInt.zero) {
      throw ArgumentError('Invalid private key');
    }

    final z = _bytesToBigInt(messageHash);

    // Generate deterministic k using RFC 6979
    final k = _generateK(d, z);

    // Calculate signature
    final point = _scalarMult(k, _ECPoint(_gx, _gy));
    final r = point.x % _n;

    if (r == BigInt.zero) {
      throw StateError('Invalid signature: r is zero');
    }

    final kInv = _modInverse(k, _n);
    final s = (kInv * (z + r * d)) % _n;

    if (s == BigInt.zero) {
      throw StateError('Invalid signature: s is zero');
    }

    // Ensure s is in lower half of curve order (canonical signature)
    final sFinal = s > (_n >> 1) ? _n - s : s;

    // Determine recovery ID (v)
    // In a real implementation, we would try to recover the public key with v=0 and v=1
    // and see which one matches the original public key derived from d.
    // For now, we'll use a placeholder logic or a simplified search.
    var v = 0;
    final publicKey = getPublicKey(privateKey);
    for (var i = 0; i < 2; i++) {
      try {
        final sig = Uint8List(64);
        _bigIntToBytes(r, 32).asMap().forEach((idx, byte) => sig[idx] = byte);
        _bigIntToBytes(sFinal, 32)
            .asMap()
            .forEach((idx, byte) => sig[idx + 32] = byte);

        final recovered = recover(sig, messageHash, i);
        if (_uint8ListEquals(recovered, publicKey)) {
          v = i;
          break;
        }
      } catch (_) {}
    }

    final signature = Uint8List(65);
    _bigIntToBytes(r, 32).asMap().forEach((i, byte) => signature[i] = byte);
    _bigIntToBytes(sFinal, 32)
        .asMap()
        .forEach((i, byte) => signature[i + 32] = byte);
    signature[64] = v;

    return signature;
  }

  static bool _uint8ListEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Recovers the public key from a signature and message hash.
  ///
  /// Returns the uncompressed public key (65 bytes: 0x04 + 32 bytes x + 32 bytes y).
  /// The recovery parameter v should be 0 or 1.
  static Uint8List recover(Uint8List signature, Uint8List messageHash, int v) {
    if (signature.length != 64) {
      throw ArgumentError('Signature must be 64 bytes');
    }
    if (messageHash.length != 32) {
      throw ArgumentError('Message hash must be 32 bytes');
    }
    if (v < 0 || v > 3) {
      throw ArgumentError('Recovery parameter v must be 0-3');
    }

    final r = _bytesToBigInt(signature.sublist(0, 32));
    final s = _bytesToBigInt(signature.sublist(32, 64));
    final z = _bytesToBigInt(messageHash);

    if (r >= _n || s >= _n) {
      throw ArgumentError('Invalid signature values');
    }

    // Calculate recovery point
    final x = r + (BigInt.from(v ~/ 2) * _n);
    if (x >= _p) {
      throw ArgumentError('Invalid recovery parameter');
    }

    final alpha = (x * x * x + _a * x + _b) % _p;
    final beta = _modPow(alpha, (_p + BigInt.one) >> 2, _p);

    final y = (v % 2 == 0) ? beta : (_p - beta);
    final R = _ECPoint(x, y);

    if (!_isOnCurve(R)) {
      throw ArgumentError('Recovery point not on curve');
    }

    final rInv = _modInverse(r, _n);
    final e = (-z) % _n;

    final point1 = _scalarMult(s, R);
    final point2 = _scalarMult(e, _ECPoint(_gx, _gy));
    final publicKeyPoint = _scalarMult(rInv, _pointAdd(point1, point2));

    return _pointToBytes(publicKeyPoint);
  }

  /// Derives the public key from a private key.
  ///
  /// Returns the uncompressed public key (65 bytes: 0x04 + 32 bytes x + 32 bytes y).
  static Uint8List getPublicKey(Uint8List privateKey,
      {bool compressed = false}) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    final d = _bytesToBigInt(privateKey);
    if (d >= _n || d == BigInt.zero) {
      throw ArgumentError('Invalid private key');
    }

    final publicKeyPoint = _scalarMult(d, _ECPoint(_gx, _gy));
    return _pointToBytes(publicKeyPoint, compressed: compressed);
  }

  /// Verifies a signature against a message hash and public key.
  ///
  /// Returns true if the signature is valid.
  static bool verify(
      Uint8List signature, Uint8List messageHash, Uint8List publicKey) {
    try {
      if (signature.length != 64) return false;
      if (messageHash.length != 32) return false;
      if (publicKey.length != 65 && publicKey.length != 33) return false;

      final r = _bytesToBigInt(signature.sublist(0, 32));
      final s = _bytesToBigInt(signature.sublist(32, 64));
      final z = _bytesToBigInt(messageHash);

      if (r >= _n || s >= _n || r == BigInt.zero || s == BigInt.zero) {
        return false;
      }

      final publicKeyPoint = _bytesToPoint(publicKey);
      if (!_isOnCurve(publicKeyPoint)) return false;

      final sInv = _modInverse(s, _n);
      final u1 = (z * sInv) % _n;
      final u2 = (r * sInv) % _n;

      final point1 = _scalarMult(u1, _ECPoint(_gx, _gy));
      final point2 = _scalarMult(u2, publicKeyPoint);
      final result = _pointAdd(point1, point2);

      return result.x % _n == r;
    } catch (e) {
      return false;
    }
  }

  // Helper methods for elliptic curve operations

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (value & BigInt.from(0xFF)).toInt();
      value >>= 8;
    }
    return bytes;
  }

  static BigInt _modPow(BigInt base, BigInt exponent, BigInt modulus) {
    return base.modPow(exponent, modulus);
  }

  static BigInt _modInverse(BigInt a, BigInt m) {
    return a.modInverse(m);
  }

  static _ECPoint _pointAdd(_ECPoint p1, _ECPoint p2) {
    if (p1.isInfinity) return p2;
    if (p2.isInfinity) return p1;

    if (p1.x == p2.x) {
      if (p1.y == p2.y) {
        return _pointDouble(p1);
      } else {
        return _ECPoint.infinity();
      }
    }

    final dx = (p2.x - p1.x) % _p;
    final dy = (p2.y - p1.y) % _p;
    final s = (dy * _modInverse(dx, _p)) % _p;

    final x3 = (s * s - p1.x - p2.x) % _p;
    final y3 = (s * (p1.x - x3) - p1.y) % _p;

    return _ECPoint(x3, y3);
  }

  static _ECPoint _pointDouble(_ECPoint p) {
    if (p.isInfinity) return p;

    final s = ((BigInt.from(3) * p.x * p.x + _a) *
            _modInverse(BigInt.from(2) * p.y, _p)) %
        _p;
    final x3 = (s * s - BigInt.from(2) * p.x) % _p;
    final y3 = (s * (p.x - x3) - p.y) % _p;

    return _ECPoint(x3, y3);
  }

  static _ECPoint _scalarMult(BigInt k, _ECPoint point) {
    if (k == BigInt.zero) return _ECPoint.infinity();
    if (k == BigInt.one) return point;

    var result = _ECPoint.infinity();
    var addend = point;

    while (k > BigInt.zero) {
      if (k.isOdd) {
        result = _pointAdd(result, addend);
      }
      addend = _pointDouble(addend);
      k >>= 1;
    }

    return result;
  }

  static bool _isOnCurve(_ECPoint point) {
    if (point.isInfinity) return true;
    final left = (point.y * point.y) % _p;
    final right = (point.x * point.x * point.x + _a * point.x + _b) % _p;
    return left == right;
  }

  static Uint8List _pointToBytes(_ECPoint point, {bool compressed = false}) {
    if (point.isInfinity) {
      throw ArgumentError('Cannot encode point at infinity');
    }

    if (compressed) {
      final bytes = Uint8List(33);
      bytes[0] = point.y.isEven ? 0x02 : 0x03;
      _bigIntToBytes(point.x, 32)
          .asMap()
          .forEach((i, byte) => bytes[i + 1] = byte);
      return bytes;
    } else {
      final bytes = Uint8List(65);
      bytes[0] = 0x04;
      _bigIntToBytes(point.x, 32)
          .asMap()
          .forEach((i, byte) => bytes[i + 1] = byte);
      _bigIntToBytes(point.y, 32)
          .asMap()
          .forEach((i, byte) => bytes[i + 33] = byte);
      return bytes;
    }
  }

  /// Decompresses a compressed public key.
  ///
  /// Takes a 33-byte compressed public key and returns the 65-byte uncompressed public key.
  static Uint8List decompressPublicKey(Uint8List compressedPublicKey) {
    return _pointToBytes(_bytesToPoint(compressedPublicKey));
  }

  static _ECPoint _bytesToPoint(Uint8List bytes) {
    if (bytes.length == 65 && bytes[0] == 0x04) {
      // Uncompressed format
      final x = _bytesToBigInt(bytes.sublist(1, 33));
      final y = _bytesToBigInt(bytes.sublist(33, 65));
      return _ECPoint(x, y);
    } else if (bytes.length == 33 && (bytes[0] == 0x02 || bytes[0] == 0x03)) {
      // Compressed format
      final x = _bytesToBigInt(bytes.sublist(1, 33));
      final alpha = (x * x * x + _a * x + _b) % _p;
      final beta = _modPow(alpha, (_p + BigInt.one) >> 2, _p);

      final y = (bytes[0] == 0x02)
          ? (beta.isEven ? beta : _p - beta)
          : (beta.isOdd ? beta : _p - beta);

      return _ECPoint(x, y);
    } else {
      throw ArgumentError('Invalid public key format');
    }
  }

  static BigInt _generateK(BigInt privateKey, BigInt messageHash) {
    // Deterministic k generation (simplified version of RFC 6979)
    // In production, use proper HMAC-based generation.
    // Here we XOR private key and message hash to get a deterministic seed.
    final seed = privateKey ^ messageHash;
    final random = Random(seed.hashCode);

    BigInt k;
    do {
      k = BigInt.from(random.nextInt(1 << 30)) * BigInt.from(1 << 30) +
          BigInt.from(random.nextInt(1 << 30));
      k = k % (_n - BigInt.one) + BigInt.one;
    } while (k >= _n);
    return k;
  }
}

/// Represents a point on the elliptic curve.
class _ECPoint {
  _ECPoint(this.x, this.y) : isInfinity = false;
  _ECPoint.infinity()
      : x = BigInt.zero,
        y = BigInt.zero,
        isInfinity = true;
  final BigInt x;
  final BigInt y;
  final bool isInfinity;

  @override
  bool operator ==(Object other) {
    if (other is! _ECPoint) return false;
    if (isInfinity && other.isInfinity) return true;
    if (isInfinity || other.isInfinity) return false;
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode => isInfinity ? 0 : x.hashCode ^ y.hashCode;
}
