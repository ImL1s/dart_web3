import 'dart:typed_data';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'public_key.dart';

/// Represents a Solana Keypair.
class KeyPair {
  KeyPair(this._keyPair);

  factory KeyPair.fromSeed(Uint8List seed) {
    // Solana/Ed25519 often uses the seed directly as the private key
    final publicKeyBytes = Ed25519.derivePublicKey(seed);
    return KeyPair(Ed25519KeyPair(seed, publicKeyBytes));
  }

  factory KeyPair.fromSecretKey(Uint8List secretKey) {
    if (secretKey.length == 64) {
      // Solana secret key format: [private_key(32) | public_key(32)]
      final privateKey = secretKey.sublist(0, 32);
      final publicKey = secretKey.sublist(32, 64);
      return KeyPair(Ed25519KeyPair(privateKey, publicKey));
    } else if (secretKey.length == 32) {
      return KeyPair.fromSeed(secretKey);
    }
    throw ArgumentError('Invalid secret key length');
  }

  final Ed25519KeyPair _keyPair;

  PublicKey get publicKey => PublicKey(_keyPair.publicKey);

  Uint8List get secretKey {
    final result = Uint8List(64);
    result.setAll(0, _keyPair.privateKey);
    result.setAll(32, _keyPair.publicKey);
    return result;
  }

  Uint8List sign(Uint8List message) {
    return _keyPair.sign(message);
  }
}
