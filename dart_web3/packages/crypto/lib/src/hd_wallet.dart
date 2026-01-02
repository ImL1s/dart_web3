import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'bip39.dart';
import 'hmac.dart';
import 'keccak.dart';
import 'ripemd160.dart';
import 'secp256k1.dart';
import 'sha2.dart';

/// Pure Dart implementation of BIP-32/44 Hierarchical Deterministic (HD) wallet.
/// 
/// Supports deriving child keys from a master seed using standard derivation paths.
class HDWallet {

  HDWallet._({
    required this.privateKey,
    required this.publicKey,
    required this.chainCode,
    required this.depth,
    required this.path,
    required this.index,
    required this.parentFingerprint,
  });

  /// Creates an HD wallet from a seed (typically from BIP-39 mnemonic).
  factory HDWallet.fromSeed(Uint8List seed) {
    if (seed.length < 16 || seed.length > 64) {
      throw ArgumentError('Seed must be between 16 and 64 bytes');
    }

    // BIP-32: Generate master key using HMAC-SHA512 with key "Bitcoin seed"
    final hmac = HmacSha512.compute(
      Uint8List.fromList(utf8.encode('Bitcoin seed')),
      seed,
    );
    final masterPrivateKey = Uint8List.sublistView(hmac, 0, 32);
    final masterChainCode = Uint8List.sublistView(hmac, 32, 64);

    // Validate master private key
    final privateKeyInt = _bytesToBigInt(masterPrivateKey);
    if (privateKeyInt >= _secp256k1Order || privateKeyInt == BigInt.zero) {
      throw StateError('Invalid master private key generated');
    }

    final publicKey = Secp256k1.getPublicKey(masterPrivateKey, compressed: true);

    return HDWallet._(
      privateKey: masterPrivateKey,
      publicKey: publicKey,
      chainCode: masterChainCode,
      depth: 0,
      path: 'm',
      index: 0,
      parentFingerprint: Uint8List(4),
    );
  }

  /// Creates an HD wallet from a BIP-39 mnemonic phrase.
  factory HDWallet.fromMnemonic(List<String> mnemonic, {String passphrase = ''}) {
    final seed = Bip39.toSeed(mnemonic, passphrase: passphrase);
    return HDWallet.fromSeed(seed);
  }
  final Uint8List privateKey;
  final Uint8List publicKey;
  final Uint8List chainCode;
  final int depth;
  final String path;
  final int index;
  final Uint8List parentFingerprint;

  /// Derives a child wallet using the specified derivation path.
  /// 
  /// Path format: "m/44'/60'/0'/0/0" (BIP-44 Ethereum path)
  /// Use apostrophe (') to indicate hardened derivation.
  HDWallet derive(String derivationPath) {
    if (!derivationPath.startsWith('m/') && !derivationPath.startsWith('/')) {
      throw ArgumentError('Invalid derivation path format');
    }

    final pathParts = derivationPath.split('/');
    var current = this;

    for (var i = (pathParts[0] == 'm') ? 1 : 0; i < pathParts.length; i++) {
      final part = pathParts[i];
      if (part.isEmpty) continue;

      final isHardened = part.endsWith("'");
      final indexStr = isHardened ? part.substring(0, part.length - 1) : part;
      final index = int.parse(indexStr);

      if (index < 0 || index >= (1 << 31)) {
        throw ArgumentError('Invalid child index: $index');
      }

      final childIndex = isHardened ? index + (1 << 31) : index;
      current = current.deriveChild(childIndex);
    }

    return current;
  }

  /// Derives a direct child wallet with the specified index.
  /// 
  /// Use index >= 2^31 for hardened derivation.
  HDWallet deriveChild(int index) {
    if (index < 0) {
      throw ArgumentError('Child index must be non-negative');
    }

    final isHardened = index >= (1 << 31);
    final data = <int>[];

    if (isHardened) {
      // Hardened derivation: use private key
      data.add(0x00);
      data.addAll(privateKey);
    } else {
      // Non-hardened derivation: use public key
      data.addAll(publicKey);
    }

    // Add index as big-endian 32-bit integer
    data.addAll(_intToBytes(index, 4));

    // BIP-32: Generate child key material using HMAC-SHA512
    final hmac = HmacSha512.compute(chainCode, Uint8List.fromList(data));
    final childPrivateKeyBytes = Uint8List.sublistView(hmac, 0, 32);
    final childChainCode = Uint8List.sublistView(hmac, 32, 64);

    // Validate child private key
    final childPrivateKeyInt = _bytesToBigInt(childPrivateKeyBytes);
    if (childPrivateKeyInt >= _secp256k1Order) {
      throw StateError('Invalid child private key generated');
    }

    // Calculate final child private key
    final parentPrivateKeyInt = _bytesToBigInt(privateKey);
    final finalChildPrivateKeyInt = (childPrivateKeyInt + parentPrivateKeyInt) % _secp256k1Order;

    if (finalChildPrivateKeyInt == BigInt.zero) {
      throw StateError('Invalid child private key (zero)');
    }

    final finalChildPrivateKey = _bigIntToBytes(finalChildPrivateKeyInt, 32);
    final childPublicKey = Secp256k1.getPublicKey(finalChildPrivateKey, compressed: true);

    // BIP-32: Parent fingerprint = first 4 bytes of HASH160(parent public key)
    // HASH160 = RIPEMD160(SHA256(data))
    final parentHash160 = Ripemd160.hash160(publicKey);
    final parentFingerprint = Uint8List.sublistView(parentHash160, 0, 4);

    // Build child path
    final childPath = path == 'm' 
        ? 'm/${isHardened ? "${index - (1 << 31)}'" : index.toString()}'
        : '$path/${isHardened ? "${index - (1 << 31)}'" : index.toString()}';

    return HDWallet._(
      privateKey: finalChildPrivateKey,
      publicKey: childPublicKey,
      chainCode: childChainCode,
      depth: depth + 1,
      path: childPath,
      index: index,
      parentFingerprint: parentFingerprint,
    );
  }

  /// Gets the Ethereum address for this wallet.
  EthereumAddress getAddress() {
    // Get uncompressed public key (remove 0x04 prefix)
    final uncompressedPublicKey = Secp256k1.getPublicKey(privateKey);
    final publicKeyBytes = uncompressedPublicKey.sublist(1); // Remove 0x04 prefix
    
    // Hash the public key and take last 20 bytes
    final hash = Keccak256.hash(publicKeyBytes);
    final addressBytes = hash.sublist(12, 32);
    
    return EthereumAddress.fromHex(HexUtils.encode(addressBytes));
  }

  /// Gets the private key as bytes.
  Uint8List getPrivateKey() {
    return Uint8List.fromList(privateKey);
  }

  /// Gets the public key as bytes (compressed format).
  Uint8List getPublicKey() {
    return Uint8List.fromList(publicKey);
  }

  /// Gets the extended private key (xprv) in Base58 format.
  String getExtendedPrivateKey() {
    return _serializeKey(isPrivate: true);
  }

  /// Gets the extended public key (xpub) in Base58 format.
  String getExtendedPublicKey() {
    return _serializeKey(isPrivate: false);
  }

  // Helper methods

  String _serializeKey({required bool isPrivate}) {
    final data = <int>[];
    
    // Version bytes (mainnet)
    if (isPrivate) {
      data.addAll([0x04, 0x88, 0xAD, 0xE4]); // xprv
    } else {
      data.addAll([0x04, 0x88, 0xB2, 0x1E]); // xpub
    }
    
    // Depth
    data.add(depth);
    
    // Parent fingerprint
    data.addAll(parentFingerprint);
    
    // Child index
    data.addAll(_intToBytes(index, 4));
    
    // Chain code
    data.addAll(chainCode);
    
    // Key data
    if (isPrivate) {
      data.add(0x00);
      data.addAll(privateKey);
    } else {
      data.addAll(publicKey);
    }

    // BIP-32: Checksum = first 4 bytes of double SHA-256
    final checksum = Sha256.doubleHash(Uint8List.fromList(data)).sublist(0, 4);

    data.addAll(checksum);
    
    return _base58Encode(Uint8List.fromList(data));
  }

  static final BigInt _secp256k1Order = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (value & BigInt.from(0xFF)).toInt();
      value >>= 8;
    }
    return bytes;
  }

  static Uint8List _intToBytes(int value, int length) {
    final bytes = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (value >> (8 * (length - 1 - i))) & 0xFF;
    }
    return bytes;
  }

  static String _base58Encode(Uint8List data) {
    // Simplified Base58 encoding
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    
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
        result = '1' + result;
      } else {
        break;
      }
    }
    
    return result;
  }
}
