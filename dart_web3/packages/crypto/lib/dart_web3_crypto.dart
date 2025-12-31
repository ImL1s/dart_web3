/// Pure Dart cryptographic primitives for Web3 operations.
/// 
/// This library provides cryptographic functions needed for blockchain operations:
/// - secp256k1 elliptic curve operations
/// - Keccak-256 hashing
/// - BIP-39 mnemonic generation and validation
/// - BIP-32/44 hierarchical deterministic key derivation
/// - Multi-curve support (Ed25519, Sr25519)
library dart_web3_crypto;

export 'src/keccak.dart';
export 'src/secp256k1.dart';
export 'src/bip39.dart';
export 'src/hd_wallet.dart';
export 'src/curves.dart';