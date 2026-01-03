/// Pure Dart cryptographic primitives for Web3 operations.
///
/// This library provides cryptographic functions needed for blockchain operations:
/// - secp256k1 elliptic curve operations
/// - Ed25519 curve (Solana, Polkadot)
/// - Schnorr signatures (Bitcoin Taproot, BIP-340)
/// - Keccak-256 hashing (Ethereum)
/// - SHA-256/512 hashing (Bitcoin/BIP standards)
/// - HMAC-SHA256/512 (BIP-32/39)
/// - PBKDF2-HMAC-SHA512 (BIP-39 seed derivation)
/// - RIPEMD-160 (Bitcoin HASH160)
/// - Base58Check encoding (Bitcoin addresses)
/// - Bech32/Bech32m encoding (SegWit/Taproot addresses)
/// - BIP-39 mnemonic generation and validation
/// - BIP-32/44 hierarchical deterministic key derivation
library dart_web3_crypto;

// Address encoding
export 'src/base58.dart';
// BIP standards
export 'src/bip39.dart';
export 'src/curves.dart' hide Ed25519, Ed25519KeyPair;
// Ed25519 (Solana, Polkadot)
export 'src/ed25519.dart';
export 'src/hd_wallet.dart';
// Message authentication
export 'src/hmac.dart';
// Hash functions
export 'src/keccak.dart';
// Key derivation
export 'src/pbkdf2.dart';
export 'src/ripemd160.dart';
// Schnorr signatures (BIP-340)
export 'src/schnorr.dart';
// Elliptic curves
export 'src/secp256k1.dart';
export 'src/sha2.dart';
