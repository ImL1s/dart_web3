/// Pure Dart cryptographic primitives for Web3 operations.
///
/// This library provides cryptographic functions needed for blockchain operations:
/// - secp256k1 elliptic curve operations
/// - Keccak-256 hashing (Ethereum)
/// - SHA-256/512 hashing (Bitcoin/BIP standards)
/// - HMAC-SHA256/512 (BIP-32/39)
/// - PBKDF2-HMAC-SHA512 (BIP-39 seed derivation)
/// - RIPEMD-160 (Bitcoin HASH160)
/// - BIP-39 mnemonic generation and validation
/// - BIP-32/44 hierarchical deterministic key derivation
/// - Multi-curve support (Ed25519, Sr25519)
library dart_web3_crypto;

// Hash functions
export 'src/keccak.dart';
export 'src/sha2.dart';
export 'src/ripemd160.dart';

// Message authentication
export 'src/hmac.dart';

// Key derivation
export 'src/pbkdf2.dart';

// Elliptic curves
export 'src/secp256k1.dart';
export 'src/curves.dart';

// BIP standards
export 'src/bip39.dart';
export 'src/hd_wallet.dart';