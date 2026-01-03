import 'dart:typed_data';

/// Bitcoin Script Opcodes and helpers.
class Script {
  Script._();

  static const int opDup = 0x76;
  static const int opHash160 = 0xa9;
  static const int opEqualVerify = 0x88;
  static const int opCheckSig = 0xac;
  static const int opCheckMultiSig = 0xae;
  static const int op0 = 0x00;
  static const int opFalse = 0x00;
  static const int opTrue = 0x51; // OP_1
  static const int opReturn = 0x6a;
  
  // Conditionally import sha256/ripemd160 if needed strictly for script execution (verify)
  // For now, we only construct standard scripts.

  /// Creates a P2PKH scriptPubKey.
  static Uint8List p2pkh(Uint8List pubKeyHash) {
    if (pubKeyHash.length != 20) throw ArgumentError('PubKeyHash must be 20 bytes');
    return Uint8List.fromList([
      opDup,
      opHash160,
      0x14, // Push 20 bytes
      ...pubKeyHash,
      opEqualVerify,
      opCheckSig,
    ]);
  }

  /// Creates a P2WPKH scriptPubKey.
  static Uint8List p2wpkh(Uint8List pubKeyHash) {
    if (pubKeyHash.length != 20) throw ArgumentError('PubKeyHash must be 20 bytes');
    return Uint8List.fromList([
      op0,
      0x14, // Push 20 bytes
      ...pubKeyHash,
    ]);
  }

  /// Creates a P2SH scriptPubKey from script hash.
  static Uint8List p2sh(Uint8List scriptHash) {
     if (scriptHash.length != 20) throw ArgumentError('ScriptHash must be 20 bytes');
     return Uint8List.fromList([
       opHash160,
       0x14,
       ...scriptHash,
       opEqualVerify,
     ]);
  }
}
