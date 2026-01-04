import 'dart:convert';
import 'dart:typed_data';

import 'bip39.dart';
import 'ed25519.dart';
import 'hmac.dart';

/// Pure Dart implementation of SLIP-0010 Ed25519 HD Wallet.
///
/// SLIP-0010 defines hierarchical deterministic key derivation for Ed25519.
/// Unlike BIP-32, Ed25519 derivation:
/// - Only supports hardened derivation (all indices must be >= 2^31)
/// - Does not support public key derivation
/// - Uses the hash directly as private key (no addition with parent)
///
/// Supported derivation paths:
/// - Solana: m/44'/501'/0'/0'
/// - TON: m/44'/607'/0'
///
/// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0010.md
class Ed25519HdWallet {
  Ed25519HdWallet._({
    required this.privateKey,
    required this.chainCode,
    required this.depth,
    required this.path,
    required this.index,
  });

  /// Creates an Ed25519 HD wallet from a seed (typically from BIP-39 mnemonic).
  ///
  /// The seed should be 128-512 bits (16-64 bytes).
  factory Ed25519HdWallet.fromSeed(Uint8List seed) {
    if (seed.length < 16 || seed.length > 64) {
      throw ArgumentError('Seed must be between 16 and 64 bytes');
    }

    // SLIP-0010: Generate master key using HMAC-SHA512 with key "ed25519 seed"
    final hmac = HmacSha512.compute(
      Uint8List.fromList(utf8.encode('ed25519 seed')),
      seed,
    );
    final masterPrivateKey = Uint8List.sublistView(hmac, 0, 32);
    final masterChainCode = Uint8List.sublistView(hmac, 32, 64);

    return Ed25519HdWallet._(
      privateKey: masterPrivateKey,
      chainCode: masterChainCode,
      depth: 0,
      path: 'm',
      index: 0,
    );
  }

  /// Creates an Ed25519 HD wallet from a BIP-39 mnemonic phrase.
  factory Ed25519HdWallet.fromMnemonic(
    List<String> mnemonic, {
    String passphrase = '',
  }) {
    final seed = Bip39.toSeed(mnemonic, passphrase: passphrase);
    return Ed25519HdWallet.fromSeed(seed);
  }

  /// The 32-byte Ed25519 private key.
  final Uint8List privateKey;

  /// The 32-byte chain code for derivation.
  final Uint8List chainCode;

  /// The depth in the derivation tree (0 for master).
  final int depth;

  /// The derivation path string (e.g., "m/44'/501'/0'/0'").
  final String path;

  /// The child index (including hardened bit if applicable).
  final int index;

  /// Hardened key offset (2^31).
  static const int _hardenedOffset = 0x80000000;

  /// Derives a child wallet using the specified derivation path.
  ///
  /// Path format: "m/44'/501'/0'/0'" (Solana BIP-44 path)
  /// All indices MUST be hardened (end with ') for Ed25519.
  ///
  /// Throws [ArgumentError] if path contains non-hardened indices.
  Ed25519HdWallet derive(String derivationPath) {
    if (!derivationPath.startsWith('m/') && !derivationPath.startsWith('/')) {
      throw ArgumentError('Invalid derivation path format: $derivationPath');
    }

    final pathParts = derivationPath.split('/');
    var current = this;

    for (var i = (pathParts[0] == 'm') ? 1 : 0; i < pathParts.length; i++) {
      final part = pathParts[i];
      if (part.isEmpty) continue;

      final isHardened = part.endsWith("'");
      if (!isHardened) {
        throw ArgumentError(
          'Ed25519 (SLIP-0010) only supports hardened derivation. '
          'Index "$part" must end with apostrophe (\')',
        );
      }

      final indexStr = part.substring(0, part.length - 1);
      final index = int.parse(indexStr);

      if (index < 0 || index >= _hardenedOffset) {
        throw ArgumentError('Invalid child index: $index');
      }

      current = current.deriveChild(index + _hardenedOffset);
    }

    return current;
  }

  /// Derives a direct child wallet with the specified index.
  ///
  /// The index MUST be >= 2^31 (hardened) for Ed25519.
  ///
  /// Throws [ArgumentError] if index is not hardened.
  Ed25519HdWallet deriveChild(int index) {
    if (index < _hardenedOffset) {
      throw ArgumentError(
        'Ed25519 (SLIP-0010) only supports hardened derivation. '
        'Index must be >= 2^31 (0x80000000)',
      );
    }

    // SLIP-0010 Ed25519 child key derivation:
    // I = HMAC-SHA512(Key = chainCode, Data = 0x00 || privateKey || ser32(index))
    final data = <int>[];
    data.add(0x00); // Padding to make private key 33 bytes
    data.addAll(privateKey);
    data.addAll(_serializeIndex(index));

    final hmac = HmacSha512.compute(chainCode, Uint8List.fromList(data));
    final childPrivateKey = Uint8List.sublistView(hmac, 0, 32);
    final childChainCode = Uint8List.sublistView(hmac, 32, 64);

    // Build child path
    final childIndex = index - _hardenedOffset;
    final childPath = path == 'm' ? "m/$childIndex'" : "$path/$childIndex'";

    return Ed25519HdWallet._(
      privateKey: childPrivateKey,
      chainCode: childChainCode,
      depth: depth + 1,
      path: childPath,
      index: index,
    );
  }

  /// Gets the private key as bytes.
  Uint8List getPrivateKey() {
    return Uint8List.fromList(privateKey);
  }

  /// Gets the Ed25519 public key (32 bytes).
  Uint8List getPublicKey() {
    return Ed25519.derivePublicKey(privateKey);
  }

  /// Gets the Solana address (Base58 encoded public key).
  ///
  /// Solana addresses are simply the Base58 encoded 32-byte public key.
  String getSolanaAddress() {
    final publicKey = getPublicKey();
    return _base58Encode(publicKey);
  }

  /// Serializes a 32-bit index as big-endian bytes.
  static Uint8List _serializeIndex(int index) {
    return Uint8List.fromList([
      (index >> 24) & 0xFF,
      (index >> 16) & 0xFF,
      (index >> 8) & 0xFF,
      index & 0xFF,
    ]);
  }

  /// Base58 encoding (Bitcoin alphabet).
  static String _base58Encode(Uint8List data) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    var num = BigInt.zero;
    for (final byte in data) {
      num = num * BigInt.from(256) + BigInt.from(byte);
    }

    var result = '';
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      result = alphabet[remainder.toInt()] + result;
      num = num ~/ BigInt.from(58);
    }

    // Add leading zeros
    for (final byte in data) {
      if (byte == 0) {
        result = '1$result';
      } else {
        break;
      }
    }

    return result;
  }

  @override
  String toString() {
    return 'Ed25519HdWallet(path: $path, depth: $depth)';
  }
}
