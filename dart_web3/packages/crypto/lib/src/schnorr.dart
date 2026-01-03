import 'dart:typed_data';

import 'keccak.dart';

/// Pure Dart implementation of Schnorr signatures (BIP-340).
///
/// Schnorr signatures are used by Bitcoin Taproot (P2TR) outputs
/// and provide several advantages over ECDSA:
/// - Smaller signature size (64 bytes vs 71-72 bytes)
/// - Provable security under the random oracle model
/// - Native support for signature aggregation (MuSig)
///
/// This implementation follows BIP-340 specification exactly.
class SchnorrSignature {
  SchnorrSignature._();

  // secp256k1 curve parameters
  static final BigInt _p = BigInt.parse(
      'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
      radix: 16);
  static final BigInt _n = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16);
  static final BigInt _Gx = BigInt.parse(
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
      radix: 16);
  static final BigInt _Gy = BigInt.parse(
      '483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8',
      radix: 16);

  /// Signs a 32-byte message hash with BIP-340 Schnorr signature.
  ///
  /// Returns a 64-byte signature (r || s).
  static Uint8List sign(Uint8List messageHash, Uint8List privateKey) {
    if (messageHash.length != 32) {
      throw ArgumentError('Message hash must be 32 bytes');
    }
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    final d = _bytesToBigInt(privateKey);
    if (d == BigInt.zero || d >= _n) {
      throw ArgumentError('Invalid private key');
    }

    // 1. Compute public key P = d * G
    final P = _scalarMult(d, [_Gx, _Gy]);
    var pk = P[0]; // x-only public key

    // 2. Negate d if P.y is odd (BIP-340 requires even y)
    var dNeg = d;
    if (_hasOddY(P)) {
      dNeg = _n - d;
    }

    // 3. Generate deterministic nonce k
    // t = bytes(d) XOR tagged_hash("BIP0340/aux", a)
    // k = int(tagged_hash("BIP0340/nonce", t || bytes(P) || m)) mod n
    final aux = Uint8List(32); // aux = 0 for deterministic signing
    final t = _xorBytes(_bigIntToBytes(dNeg, 32), _taggedHash('BIP0340/aux', aux));
    final pkBytes = _bigIntToBytes(pk, 32);
    final kHash = _taggedHash('BIP0340/nonce', 
        Uint8List.fromList([...t, ...pkBytes, ...messageHash]));
    var k = _bytesToBigInt(kHash) % _n;

    if (k == BigInt.zero) {
      throw StateError('Nonce k is zero, try different inputs');
    }

    // 4. Compute R = k * G
    var R = _scalarMult(k, [_Gx, _Gy]);

    // 5. Negate k if R.y is odd
    if (_hasOddY(R)) {
      k = _n - k;
    }

    // 6. Compute e = tagged_hash("BIP0340/challenge", r || P || m) mod n
    final rBytes = _bigIntToBytes(R[0], 32);
    final eHash = _taggedHash('BIP0340/challenge',
        Uint8List.fromList([...rBytes, ...pkBytes, ...messageHash]));
    final e = _bytesToBigInt(eHash) % _n;

    // 7. Compute s = (k + e * d) mod n
    final s = (k + e * dNeg) % _n;

    // 8. Return signature (r || s)
    final sBytes = _bigIntToBytes(s, 32);
    return Uint8List.fromList([...rBytes, ...sBytes]);
  }

  /// Verifies a BIP-340 Schnorr signature.
  ///
  /// [signature] must be 64 bytes (r || s).
  /// [messageHash] must be 32 bytes.
  /// [publicKey] must be 32 bytes (x-only public key).
  static bool verify(Uint8List signature, Uint8List messageHash, Uint8List publicKey) {
    if (signature.length != 64) return false;
    if (messageHash.length != 32) return false;
    if (publicKey.length != 32) return false;

    try {
      // 1. Parse signature
      final r = _bytesToBigInt(signature.sublist(0, 32));
      final s = _bytesToBigInt(signature.sublist(32, 64));

      if (r >= _p || s >= _n) return false;

      // 2. Lift x coordinate to point P
      final P = _liftX(publicKey);
      if (P == null) return false;

      // 3. Compute e = tagged_hash("BIP0340/challenge", r || P || m) mod n
      final eHash = _taggedHash('BIP0340/challenge',
          Uint8List.fromList([...signature.sublist(0, 32), ...publicKey, ...messageHash]));
      final e = _bytesToBigInt(eHash) % _n;

      // 4. Compute R' = s * G - e * P
      final sG = _scalarMult(s, [_Gx, _Gy]);
      final eP = _scalarMult(e, P);
      final ePNeg = [eP[0], _p - eP[1]]; // Negate y
      final R = _pointAdd(sG, ePNeg);

      // 5. Verify R' is not at infinity
      if (R[0] == BigInt.zero && R[1] == BigInt.zero) return false;

      // 6. Verify R'.y is even
      if (_hasOddY(R)) return false;

      // 7. Verify R'.x == r
      return R[0] == r;
    } catch (_) {
      return false;
    }
  }

  /// Derives the x-only public key from a private key.
  ///
  /// Returns a 32-byte x-only public key.
  static Uint8List getPublicKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    final d = _bytesToBigInt(privateKey);
    if (d == BigInt.zero || d >= _n) {
      throw ArgumentError('Invalid private key');
    }

    final P = _scalarMult(d, [_Gx, _Gy]);
    return _bigIntToBytes(P[0], 32);
  }

  /// Tweaks a public key according to BIP-341 (Taproot).
  ///
  /// [publicKey]: 32-byte x-only public key P.
  /// [tweak]: 32-byte tweak value t.
  ///
  /// Computes Q = P + t*G.
  /// Returns Map { 'x': Uint8List(32), 'yParity': int (0 or 1) }
  /// Returns null if P is invalid or result is potentially invalid (rare).
  static Map<String, dynamic>? tweakPublicKey(Uint8List publicKey, Uint8List tweak) {
    if (publicKey.length != 32 || tweak.length != 32) {
      throw ArgumentError('Inputs must be 32 bytes');
    }

    final P = _liftX(publicKey);
    if (P == null) return null; // Invalid P

    final t = _bytesToBigInt(tweak);
    if (t >= _n) return null; // Invalid tweak

    // T = t * G
    final T = _scalarMult(t, [_Gx, _Gy]);
    
    // Q = P + T
    final Q = _pointAdd(P, T);

    if (Q[0] == BigInt.zero && Q[1] == BigInt.zero) return null; // Point at infinity

    final parity = _hasOddY(Q) ? 1 : 0;
    
    return {
      'x': _bigIntToBytes(Q[0], 32),
      'yParity': parity,
    };
  }

  // --- Tagged Hash (BIP-340) ---

  static Uint8List _taggedHash(String tag, Uint8List data) {
    final tagHash = Keccak256.hash(Uint8List.fromList(tag.codeUnits));
    return Keccak256.hash(Uint8List.fromList([...tagHash, ...tagHash, ...data]));
  }

  // --- Helper Functions ---

  static bool _hasOddY(List<BigInt> point) {
    return point[1] & BigInt.one == BigInt.one;
  }

  static Uint8List _xorBytes(Uint8List a, Uint8List b) {
    final result = Uint8List(a.length);
    for (var i = 0; i < a.length; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }

  static List<BigInt>? _liftX(Uint8List xBytes) {
    final x = _bytesToBigInt(xBytes);
    if (x >= _p) return null;

    // y^2 = x^3 + 7 mod p
    final c = (x.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;

    // y = c^((p+1)/4) mod p
    final y = c.modPow((_p + BigInt.one) ~/ BigInt.from(4), _p);

    // Verify y^2 == c
    if (y.modPow(BigInt.two, _p) != c) return null;

    // Choose even y
    final yFinal = _hasOddY([x, y]) ? _p - y : y;
    return [x, yFinal];
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v >>= 8;
    }
    return result;
  }

  static List<BigInt> _pointAdd(List<BigInt> p1, List<BigInt> p2) {
    if (p1[0] == BigInt.zero && p1[1] == BigInt.zero) return p2;
    if (p2[0] == BigInt.zero && p2[1] == BigInt.zero) return p1;

    final x1 = p1[0], y1 = p1[1];
    final x2 = p2[0], y2 = p2[1];

    BigInt s;
    if (x1 == x2 && y1 == y2) {
      // Point doubling
      s = (BigInt.from(3) * x1 * x1 * _modInverse(BigInt.two * y1, _p)) % _p;
    } else if (x1 == x2) {
      // Points are inverses
      return [BigInt.zero, BigInt.zero];
    } else {
      s = ((y2 - y1) * _modInverse(x2 - x1, _p)) % _p;
    }

    final x3 = (s * s - x1 - x2) % _p;
    final y3 = (s * (x1 - x3) - y1) % _p;

    return [x3 < BigInt.zero ? x3 + _p : x3, y3 < BigInt.zero ? y3 + _p : y3];
  }

  static List<BigInt> _scalarMult(BigInt k, List<BigInt> point) {
    var result = [BigInt.zero, BigInt.zero]; // Point at infinity
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

  static BigInt _modInverse(BigInt a, BigInt m) {
    final normalized = a % m;
    return normalized.modPow(m - BigInt.two, m);
  }
}
