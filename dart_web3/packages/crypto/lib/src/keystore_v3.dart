import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'aes.dart';
import 'keccak.dart';
import 'pbkdf2.dart';
import 'scrypt.dart';

/// Implements the Ethereum Keystore V3 specification.
class KeystoreV3 {
  /// Encrypts a private key using a passphrase.
  static Map<String, dynamic> encrypt(
    Uint8List privateKey,
    String password, {
    bool useScrypt = true,
    String? address,
    int? n, // Scrypt N
    int? r, // Scrypt r
    int? p, // Scrypt p
  }) {
    final random = Random.secure();
    final salt = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      salt[i] = random.nextInt(256);
    }

    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    Uint8List derivedKey;
    String kdfName;
    Map<String, dynamic> kdfParams;

    if (useScrypt) {
      kdfName = 'scrypt';
      final scryptN = n ?? 262144;
      final scryptR = r ?? 8;
      final scryptP = p ?? 1;
      kdfParams = {
        'dklen': 32,
        'n': scryptN,
        'r': scryptR,
        'p': scryptP,
        'salt': _toHex(salt),
      };
      derivedKey =
          Scrypt.derive(passwordBytes, salt, scryptN, scryptR, scryptP, 32);
    } else {
      kdfName = 'pbkdf2';
      final iterations = 262144;
      kdfParams = {
        'dklen': 32,
        'c': iterations,
        'prf': 'hmac-sha256',
        'salt': _toHex(salt),
      };
      derivedKey = Pbkdf2.deriveSha256(
          password: passwordBytes,
          salt: salt,
          iterations: iterations,
          keyLength: 32);
    }

    final encryptionKey = derivedKey.sublist(0, 16);
    final aes = AES(encryptionKey);
    final ciphertext = aes.ctr(privateKey, iv);

    // mac = keccak256(derivedKey[16...32] + ciphertext)
    final macData = Uint8List.fromList(derivedKey.sublist(16, 32) + ciphertext);
    final mac = Keccak256.hash(macData);

    return {
      'version': 3,
      'id': _generateUUID(random),
      'address': address?.replaceFirst('0x', '').toLowerCase(),
      'crypto': {
        'ciphertext': _toHex(ciphertext),
        'cipherparams': {'iv': _toHex(iv)},
        'cipher': 'aes-128-ctr',
        'kdf': kdfName,
        'kdfparams': kdfParams,
        'mac': _toHex(mac),
      },
    };
  }

  /// Decrypts a Keystore V3 JSON object.
  static Uint8List decrypt(Map<String, dynamic> json, String password) {
    if (json['version'] != 3) {
      throw ArgumentError('Only Keystore V3 is supported');
    }

    final crypto = (json['crypto'] ?? json['Crypto']) as Map<String, dynamic>?;
    if (crypto == null) {
      throw ArgumentError('Invalid keystore: missing crypto section');
    }

    final ciphertext = _fromHex(crypto['ciphertext'] as String);
    final cipherparams = crypto['cipherparams'] as Map<String, dynamic>;
    final iv = _fromHex(cipherparams['iv'] as String);
    final mac = _fromHex(crypto['mac'] as String);
    final kdf = crypto['kdf'] as String;
    final kdfParams = crypto['kdfparams'] as Map<String, dynamic>;

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    Uint8List derivedKey;

    if (kdf == 'scrypt') {
      final n = kdfParams['n'] as int;
      final r = kdfParams['r'] as int;
      final p = kdfParams['p'] as int;
      final salt = _fromHex(kdfParams['salt'] as String);
      derivedKey = Scrypt.derive(passwordBytes, salt, n, r, p, 32);
    } else if (kdf == 'pbkdf2') {
      final iterations = kdfParams['c'] as int;
      final salt = _fromHex(kdfParams['salt'] as String);
      derivedKey = Pbkdf2.deriveSha256(
          password: passwordBytes,
          salt: salt,
          iterations: iterations,
          keyLength: 32);
    } else {
      throw ArgumentError('Unsupported KDF: $kdf');
    }

    // Verify MAC
    final macData = Uint8List.fromList(derivedKey.sublist(16, 32) + ciphertext);
    final calculatedMac = Keccak256.hash(macData);
    if (!_uint8ListEquals(calculatedMac, mac)) {
      throw StateError('Invalid password or corrupted keystore (MAC mismatch)');
    }

    final encryptionKey = derivedKey.sublist(0, 16);
    final aes = AES(encryptionKey);
    return aes.ctr(ciphertext, iv);
  }

  static String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  static Uint8List _fromHex(String input) {
    final hex = input.replaceFirst('0x', '');
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static bool _uint8ListEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static String _generateUUID(Random random) {
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }

    // Set version to 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = _toHex(bytes);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
