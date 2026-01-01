import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// HMAC-SHA512 implementation per RFC 2104.
///
/// Used in BIP-32 for HD key derivation and BIP-39 for seed generation.
class HmacSha512 {
  HmacSha512._();

  /// Computes HMAC-SHA512.
  ///
  /// [key] - The secret key
  /// [data] - The message to authenticate
  ///
  /// Returns a 64-byte (512-bit) MAC.
  static Uint8List compute(Uint8List key, Uint8List data) {
    final hmac = crypto.Hmac(crypto.sha512, key);
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
}

/// HMAC-SHA256 implementation per RFC 2104.
class HmacSha256 {
  HmacSha256._();

  /// Computes HMAC-SHA256.
  ///
  /// [key] - The secret key
  /// [data] - The message to authenticate
  ///
  /// Returns a 32-byte (256-bit) MAC.
  static Uint8List compute(Uint8List key, Uint8List data) {
    final hmac = crypto.Hmac(crypto.sha256, key);
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
}
