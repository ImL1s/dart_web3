import 'dart:typed_data';
import 'package:pointycastle/digests/sha3.dart';

/// Represents an Aptos address.
///
/// Aptos addresses are 32-byte values derived from public keys using SHA3-256.
class AptosAddress {
  AptosAddress._(this._bytes);

  /// Create address from 32 bytes.
  factory AptosAddress.fromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Address must be 32 bytes');
    }
    return AptosAddress._(bytes);
  }

  /// Create address from hex string (with or without 0x prefix).
  factory AptosAddress.fromHex(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    // Pad to 64 characters if needed
    final paddedHex = cleanHex.padLeft(64, '0');
    final bytes = _hexDecode(paddedHex);
    return AptosAddress.fromBytes(bytes);
  }

  /// Derive address from public key (Aptos uses SHA3-256 with scheme byte).
  factory AptosAddress.fromPublicKey(Uint8List publicKey) {
    // Aptos address = SHA3-256(public_key || 0x00) where 0x00 is Ed25519 scheme
    final input = Uint8List(publicKey.length + 1);
    input.setAll(0, publicKey);
    input[publicKey.length] = 0x00; // Ed25519 scheme identifier

    // SHA3-256 using pointycastle (256-bit output)
    final sha3 = SHA3Digest(256);
    final hash = sha3.process(input);
    return AptosAddress._(hash);
  }

  final Uint8List _bytes;

  /// Get address as bytes.
  Uint8List get bytes => _bytes;

  /// Get address as hex string with 0x prefix.
  String toHex() => '0x${_hexEncode(_bytes)}';

  /// Get short form address (first 4 and last 4 chars).
  String toShortString() {
    final hex = toHex();
    return '${hex.substring(0, 6)}...${hex.substring(hex.length - 4)}';
  }

  @override
  String toString() => toHex();

  @override
  bool operator ==(Object other) {
    if (other is AptosAddress) {
      for (var i = 0; i < 32; i++) {
        if (_bytes[i] != other._bytes[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);

  static Uint8List _hexDecode(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
