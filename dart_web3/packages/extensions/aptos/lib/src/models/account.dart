import 'dart:typed_data';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'address.dart';

/// Represents an Aptos account with Ed25519 keypair.
class AptosAccount {
  AptosAccount._(this._keyPair);

  /// Create account from seed (32 bytes).
  factory AptosAccount.fromSeed(Uint8List seed) {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be 32 bytes');
    }
    final publicKey = Ed25519.derivePublicKey(seed);
    return AptosAccount._(Ed25519KeyPair(seed, publicKey));
  }

  /// Create account from private key hex string.
  factory AptosAccount.fromPrivateKeyHex(String privateKeyHex) {
    final hex = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;
    final bytes = _hexDecode(hex);
    return AptosAccount.fromSeed(bytes);
  }

  /// Generate a new random account.
  factory AptosAccount.generate() {
    final seed = Uint8List(32);
    final random = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 32; i++) {
      seed[i] = (random + i * 31) % 256;
    }
    return AptosAccount.fromSeed(Sha256.hash(seed));
  }

  final Ed25519KeyPair _keyPair;

  /// Get the account address.
  AptosAddress get address => AptosAddress.fromPublicKey(_keyPair.publicKey);

  /// Get the public key bytes (32 bytes).
  Uint8List get publicKey => _keyPair.publicKey;

  /// Get the public key as hex string.
  String get publicKeyHex => '0x${_hexEncode(_keyPair.publicKey)}';

  /// Get the private key bytes (32 bytes).
  Uint8List get privateKey => _keyPair.privateKey;

  /// Get the private key as hex string.
  String get privateKeyHex => '0x${_hexEncode(_keyPair.privateKey)}';

  /// Sign a message.
  Uint8List sign(Uint8List message) {
    return _keyPair.sign(message);
  }

  /// Sign a message and return signature as hex.
  String signHex(Uint8List message) {
    return '0x${_hexEncode(sign(message))}';
  }

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
