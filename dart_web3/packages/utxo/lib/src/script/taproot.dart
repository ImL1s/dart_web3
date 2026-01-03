
import 'dart:typed_data';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// Represents a Taproot Script Leaf (BIP-341).
class TapLeaf {
  TapLeaf({required this.script, this.version = 0xc0});

  final Uint8List script;
  final int version; // Leaf version (default 0xc0)

  /// Calculates the leaf hash (tagged hash).
  Uint8List get hash {
    final buffer = BytesBuilder();
    buffer.addByte(version);
    _addCompactSize(buffer, script.length);
    buffer.add(script);
    
    return _taggedHash('TapLeaf', buffer.toBytes());
  }
  
  void _addCompactSize(BytesBuilder buffer, int size) {
    if (size < 253) {
      buffer.addByte(size);
    } else if (size <= 0xffff) {
      buffer.addByte(253);
      buffer.addByte(size & 0xff);
      buffer.addByte((size >> 8) & 0xff);
    } else {
      // For scripts larger than 64KB, logic extends here (rare for standard leaves)
      buffer.addByte(254);
      buffer.addByte(size & 0xff);
      buffer.addByte((size >> 8) & 0xff);
      buffer.addByte((size >> 16) & 0xff);
      buffer.addByte((size >> 24) & 0xff);
    }
  }
}

/// Represents a branch in the Taproot Merkle Tree.
class TapBranch {
  TapBranch(this.left, this.right);
  
  final Uint8List left; // Hash of left child
  final Uint8List right; // Hash of right child
  
  Uint8List get hash {
    // Lexicographical sort
    Uint8List first, second;
    if (_compare(left, right) < 0) {
      first = left;
      second = right;
    } else {
      first = right;
      second = left;
    }
    
    return _taggedHash('TapBranch', Uint8List.fromList([...first, ...second]));
  }
  
  int _compare(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    }
    return 0;
  }
}

/// Helper for Taproot Tree construction and Tweaking.
class TaprootKey {
  
  /// Tweaks a public key with a script merkle root (or null for key-path only).
  /// [internalKey]: 32-byte x-only internal public key.
  /// [merkleRoot]: Root of the script tree (optional).
  /// 
  /// Returns a Map containing:
  /// - 'outputKey': 32-byte tweaked public key (Q)
  /// - 'parity': int (0 or 1)
  /// - 'scriptConfig': The data that was hashed to create the tweak (needed for control block)
  static Map<String, dynamic> tweak(Uint8List internalKey, [Uint8List? merkleRoot]) {
    if (internalKey.length != 32) throw ArgumentError('Internal key must be 32 bytes');
    
    // t = hash_TapTweak(P || merkleRoot)
    final buffer = BytesBuilder();
    buffer.add(internalKey);
    if (merkleRoot != null) {
      buffer.add(merkleRoot);
    }
    
    final tweakHash = _taggedHash('TapTweak', buffer.toBytes());
    
    // Q = P + t*G
    final tweaked = SchnorrSignature.tweakPublicKey(internalKey, tweakHash);
    
    if (tweaked == null) {
      throw Exception('Taproot tweak resulted in invalid point (rare)');
    }
    
    return {
      'outputKey': tweaked['x'],
      'parity': tweaked['yParity'],
      'tweakHash': tweakHash,
    };
  }
}

Uint8List _taggedHash(String tag, Uint8List data) {
  final tagHash = _sha256(Uint8List.fromList(tag.codeUnits));
  return _sha256(Uint8List.fromList([...tagHash, ...tagHash, ...data]));
}

Uint8List _sha256(Uint8List data) {
  return Sha256.hash(data); // Use static method from web3_universal_crypto
}
