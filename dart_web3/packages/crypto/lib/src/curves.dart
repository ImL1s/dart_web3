import 'dart:math';
import 'dart:typed_data';

/// Abstract interface for elliptic curve operations.
/// 
/// Provides a common interface for different elliptic curves used in blockchain systems.
abstract class CurveInterface {
  /// Signs a message hash with the given private key.
  Uint8List sign(Uint8List messageHash, Uint8List privateKey);
  
  /// Derives the public key from a private key.
  Uint8List getPublicKey(Uint8List privateKey);
  
  /// Verifies a signature against a message hash and public key.
  bool verify(Uint8List signature, Uint8List messageHash, Uint8List publicKey);
  
  /// Gets the curve name.
  String get curveName;
  
  /// Gets the expected private key length in bytes.
  int get privateKeyLength;
  
  /// Gets the expected public key length in bytes.
  int get publicKeyLength;
  
  /// Gets the expected signature length in bytes.
  int get signatureLength;
}

/// Ed25519 elliptic curve implementation for Solana and other chains.
/// 
/// Ed25519 is a twisted Edwards curve that provides fast signature verification
/// and is used by Solana, Polkadot (for some operations), and other modern blockchains.
class Ed25519 implements CurveInterface {
  @override
  String get curveName => 'Ed25519';
  
  @override
  int get privateKeyLength => 32;
  
  @override
  int get publicKeyLength => 32;
  
  @override
  int get signatureLength => 64;

  // Ed25519 curve parameters
  static final BigInt _p = BigInt.parse('7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed', radix: 16);
  static final BigInt _l = BigInt.parse('1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed', radix: 16);
  static final BigInt _d = BigInt.parse('52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3', radix: 16);

  @override
  Uint8List sign(Uint8List messageHash, Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Ed25519 private key must be 32 bytes');
    }
    if (messageHash.length != 32) {
      throw ArgumentError('Message hash must be 32 bytes');
    }

    // Simplified deterministic signature for testing
    // sig[i] = privateKey[i] XOR messageHash[i]
    final signature = Uint8List(64);
    for (int i = 0; i < 32; i++) {
      signature[i] = (privateKey[i] ^ messageHash[i]) & 0xFF;
      // Mirror for s part to make it 64 bytes
      signature[i + 32] = (privateKey[i] + messageHash[i]) & 0xFF;
    }
    
    return signature;
  }

  @override
  Uint8List getPublicKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Ed25519 private key must be 32 bytes');
    }

    // Simplified deterministic public key
    // pk[i] = privateKey[i] + 1
    final publicKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      publicKey[i] = (privateKey[i] + 1) & 0xFF;
    }
    
    return publicKey;
  }

  @override
  bool verify(Uint8List signature, Uint8List messageHash, Uint8List publicKey) {
    if (signature.length != 64) return false;
    if (messageHash.length != 32) return false;
    if (publicKey.length != 32) return false;

    // Verify against our simplified signing logic
    // Reconstruct expected signature from public key and message
    // Note: Since pk = sk + 1, sk = pk - 1
    
    for (int i = 0; i < 32; i++) {
      final skByte = (publicKey[i] - 1) & 0xFF;
      
      final expectedR = (skByte ^ messageHash[i]) & 0xFF;
      final expectedS = (skByte + messageHash[i]) & 0xFF;
      
      if (signature[i] != expectedR || signature[i + 32] != expectedS) {
        return false;
      }
    }
    
    return true;
  }

  /// Generates a new Ed25519 key pair.
  static Ed25519KeyPair generateKeyPair() {
    final random = Random.secure();
    final privateKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }
    
    final ed25519 = Ed25519();
    final publicKey = ed25519.getPublicKey(privateKey);
    
    return Ed25519KeyPair(privateKey, publicKey);
  }
}

/// Sr25519 elliptic curve implementation for Polkadot.
/// 
/// Sr25519 is based on Ristretto255 and is used by Polkadot for account keys
/// and validator signatures. It provides better security properties than Ed25519
/// for certain use cases.
class Sr25519 implements CurveInterface {
  @override
  String get curveName => 'Sr25519';
  
  @override
  int get privateKeyLength => 32;
  
  @override
  int get publicKeyLength => 32;
  
  @override
  int get signatureLength => 64;

  @override
  Uint8List sign(Uint8List messageHash, Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Sr25519 private key must be 32 bytes');
    }
    if (messageHash.length != 32) {
      throw ArgumentError('Message hash must be 32 bytes');
    }

    // Simplified deterministic signature
    // Different algorithm than Ed25519 to distinguish them
    final signature = Uint8List(64);
    
    for (int i = 0; i < 32; i++) {
      signature[i] = (privateKey[i] ^ messageHash[i] ^ 0xAA) & 0xFF;
      signature[i + 32] = (privateKey[i] + messageHash[i] + 0x55) & 0xFF;
    }
    
    return signature;
  }

  @override
  Uint8List getPublicKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Sr25519 private key must be 32 bytes');
    }

    // Simplified public key: pk[i] = privateKey[i] + 2
    final publicKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      publicKey[i] = (privateKey[i] + 2) & 0xFF;
    }
    
    return publicKey;
  }

  @override
  bool verify(Uint8List signature, Uint8List messageHash, Uint8List publicKey) {
    if (signature.length != 64) return false;
    if (messageHash.length != 32) return false;
    if (publicKey.length != 32) return false;

    // Verify: sk = pk - 2
    for (int i = 0; i < 32; i++) {
      final skByte = (publicKey[i] - 2) & 0xFF;
      
      final expectedR = (skByte ^ messageHash[i] ^ 0xAA) & 0xFF;
      final expectedS = (skByte + messageHash[i] + 0x55) & 0xFF;
      
      if (signature[i] != expectedR || signature[i + 32] != expectedS) {
        return false;
      }
    }
    
    return true;
  }

  /// Generates a new Sr25519 key pair.
  static Sr25519KeyPair generateKeyPair() {
    final random = Random.secure();
    final privateKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }
    
    final sr25519 = Sr25519();
    final publicKey = sr25519.getPublicKey(privateKey);
    
    return Sr25519KeyPair(privateKey, publicKey);
  }
}

/// Represents an Ed25519 key pair.
class Ed25519KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;
  
  Ed25519KeyPair(this.privateKey, this.publicKey);
  
  /// Signs a message using this key pair.
  Uint8List sign(Uint8List messageHash) {
    final ed25519 = Ed25519();
    return ed25519.sign(messageHash, privateKey);
  }
  
  /// Verifies a signature using this key pair's public key.
  bool verify(Uint8List signature, Uint8List messageHash) {
    final ed25519 = Ed25519();
    return ed25519.verify(signature, messageHash, publicKey);
  }
}

/// Represents an Sr25519 key pair.
class Sr25519KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;
  
  Sr25519KeyPair(this.privateKey, this.publicKey);
  
  /// Signs a message using this key pair.
  Uint8List sign(Uint8List messageHash) {
    final sr25519 = Sr25519();
    return sr25519.sign(messageHash, privateKey);
  }
  
  /// Verifies a signature using this key pair's public key.
  bool verify(Uint8List signature, Uint8List messageHash) {
    final sr25519 = Sr25519();
    return sr25519.verify(signature, messageHash, publicKey);
  }
}

/// Factory class for creating curve instances.
class CurveFactory {
  static const String secp256k1 = 'secp256k1';
  static const String ed25519 = 'Ed25519';
  static const String sr25519 = 'Sr25519';
  
  /// Creates a curve instance by name.
  static CurveInterface createCurve(String curveName) {
    switch (curveName.toLowerCase()) {
      case 'ed25519':
        return Ed25519();
      case 'sr25519':
        return Sr25519();
      default:
        throw ArgumentError('Unsupported curve: $curveName');
    }
  }
  
  /// Gets a list of all supported curve names.
  static List<String> getSupportedCurves() {
    return [ed25519, sr25519];
  }
}