import 'dart:typed_data';
import 'hmac.dart';

/// PBKDF2 (Password-Based Key Derivation Function 2) per RFC 2898.
///
/// Used in BIP-39 to derive a 512-bit seed from a mnemonic phrase.
/// BIP-39 specifies: PBKDF2-HMAC-SHA512, 2048 iterations, 64-byte output.
class Pbkdf2 {
  Pbkdf2._();

  /// Derives a key using PBKDF2-HMAC-SHA512.
  ///
  /// [password] - The password bytes (mnemonic phrase in BIP-39)
  /// [salt] - The salt bytes ("mnemonic" + passphrase in BIP-39)
  /// [iterations] - Number of iterations (2048 for BIP-39)
  /// [keyLength] - Desired key length in bytes (64 for BIP-39)
  ///
  /// Returns the derived key of [keyLength] bytes.
  static Uint8List deriveKey({
    required Uint8List password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    // HMAC-SHA512 output length
    const hLen = 64;

    // Check derived key length (RFC 2898 Section 5.2)
    if (keyLength > (1 << 32 - 1) * hLen) {
      throw ArgumentError('Derived key too long');
    }

    // Calculate number of blocks needed
    final l = (keyLength + hLen - 1) ~/ hLen;
    // Bytes in last block
    final r = keyLength - (l - 1) * hLen;

    final dk = Uint8List(keyLength);

    for (var i = 1; i <= l; i++) {
      final block = _computeBlock(password, salt, iterations, i);
      final offset = (i - 1) * hLen;
      final len = (i == l) ? r : hLen;
      dk.setRange(offset, offset + len, block);
    }

    return dk;
  }

  /// Computes a single block: F(Password, Salt, c, i).
  ///
  /// F(P, S, c, i) = U_1 XOR U_2 XOR ... XOR U_c
  /// where:
  ///   U_1 = PRF(Password, Salt || INT(i))
  ///   U_2 = PRF(Password, U_1)
  ///   ...
  ///   U_c = PRF(Password, U_{c-1})
  static Uint8List _computeBlock(
    Uint8List password,
    Uint8List salt,
    int iterations,
    int blockIndex,
  ) {
    // U_1 = PRF(Password, Salt || INT_32_BE(i))
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setRange(0, salt.length, salt);
    // Append block index as 32-bit big-endian integer
    saltWithIndex[salt.length] = (blockIndex >> 24) & 0xff;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xff;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xff;
    saltWithIndex[salt.length + 3] = blockIndex & 0xff;

    var u = HmacSha512.compute(password, saltWithIndex);
    final result = Uint8List.fromList(u);

    // U_2 ... U_c: XOR each U_i into result
    for (var j = 2; j <= iterations; j++) {
      u = HmacSha512.compute(password, u);
      for (var k = 0; k < result.length; k++) {
        result[k] ^= u[k];
      }
    }

    return result;
  }
}
