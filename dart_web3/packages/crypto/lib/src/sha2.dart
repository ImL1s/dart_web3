import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// SHA-256 hash function (FIPS 180-4).
///
/// Produces a 256-bit (32-byte) hash value.
/// Used in BIP-39 for mnemonic checksum calculation.
class Sha256 {
  Sha256._();

  /// Computes SHA-256 hash of the input data.
  ///
  /// Returns a 32-byte hash.
  static Uint8List hash(Uint8List data) {
    final digest = crypto.sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Computes double SHA-256: SHA256(SHA256(data)).
  ///
  /// Used in Bitcoin/BIP-32 for extended key checksums.
  /// Returns a 32-byte hash.
  static Uint8List doubleHash(Uint8List data) {
    return hash(hash(data));
  }
}

/// SHA-512 hash function (FIPS 180-4).
///
/// Produces a 512-bit (64-byte) hash value.
/// Used in BIP-32/39 via HMAC-SHA512.
class Sha512 {
  Sha512._();

  /// Computes SHA-512 hash of the input data.
  ///
  /// Returns a 64-byte hash.
  static Uint8List hash(Uint8List data) {
    final digest = crypto.sha512.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
}
