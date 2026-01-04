
import 'dart:typed_data';
// For BytesUtils if needed, or just dart:typed_data

/// Bitcoin Script Opcodes.
class OpCode {
  // Push value
  static const int op0 = 0x00;
  static const int opPushData1 = 0x4c;
  static const int opPushData2 = 0x4d;
  static const int opPushData4 = 0x4e;
  static const int op1Negate = 0x4f;
  static const int opReserved = 0x50;
  static const int opTrue = 0x51; // OP_1
  static const int op1 = 0x51;
  static const int op2 = 0x52;
  static const int op3 = 0x53;
  static const int op4 = 0x54;
  static const int op5 = 0x55;
  static const int op6 = 0x56;
  static const int op7 = 0x57;
  static const int op8 = 0x58;
  static const int op9 = 0x59;
  static const int op10 = 0x5a;
  static const int op11 = 0x5b;
  static const int op12 = 0x5c;
  static const int op13 = 0x5d;
  static const int op14 = 0x5e;
  static const int op15 = 0x5f;
  static const int op16 = 0x60;

  // Flow control
  static const int opNop = 0x61;
  static const int opIf = 0x63;
  static const int opNotIf = 0x64;
  static const int opElse = 0x67;
  static const int opEndIf = 0x68;
  static const int opVerify = 0x69;
  static const int opReturn = 0x6a;

  // Stack ops
  static const int opToAltStack = 0x6b;
  static const int opFromAltStack = 0x6c;
  static const int opIfDup = 0x73;
  static const int opDepth = 0x74;
  static const int opDrop = 0x75;
  static const int opDup = 0x76;
  static const int opNip = 0x77;
  static const int opOver = 0x78;

  // Bitwise logic
  static const int opEqual = 0x87;
  static const int opEqualVerify = 0x88;
  static const int opAdd = 0x93;
  static const int opSub = 0x94;
  static const int opMul = 0x95;

  // Crypto
  static const int opRipemd160 = 0xa6;
  static const int opSha1 = 0xa7;
  static const int opSha256 = 0xa8;
  static const int opHash160 = 0xa9;
  static const int opHash256 = 0xaa;
  static const int opCodeSeparator = 0xab;
  static const int opCheckSig = 0xac;
  static const int opCheckSigVerify = 0xad;
  static const int opCheckMultiSig = 0xae;
  static const int opCheckMultiSigVerify = 0xaf;
}

/// Bitcoin Script Parsing and Compilation.
class Script {
  Script(this.ops);

  /// Parses bytes into a Script.
  factory Script.fromBytes(Uint8List bytes) {
    final ops = <dynamic>[];
    var i = 0;
    while (i < bytes.length) {
      final op = bytes[i];
      i++;

      if (op > 0 && op <= 0x4b) {
        // Direct push of N bytes
        final len = op;
        if (i + len > bytes.length) throw Exception('Script truncated');
        ops.add(bytes.sublist(i, i + len));
        i += len;
      } else if (op == OpCode.opPushData1) {
        if (i + 1 > bytes.length) throw Exception('Script truncated');
        final len = bytes[i];
        i++;
        if (i + len > bytes.length) throw Exception('Script truncated');
        ops.add(bytes.sublist(i, i + len));
        i += len;
      } else if (op == OpCode.opPushData2) {
        if (i + 2 > bytes.length) throw Exception('Script truncated');
        final len = ByteData.sublistView(bytes, i, i + 2).getUint16(0, Endian.little);
        i += 2;
        if (i + len > bytes.length) throw Exception('Script truncated');
        ops.add(bytes.sublist(i, i + len));
        i += len;
      } else if (op == OpCode.opPushData4) {
        if (i + 4 > bytes.length) throw Exception('Script truncated');
        final len = ByteData.sublistView(bytes, i, i + 4).getUint32(0, Endian.little);
        i += 4;
        if (i + len > bytes.length) throw Exception('Script truncated');
        ops.add(bytes.sublist(i, i + len));
        i += len;
      } else {
        // Regular OpCode or Op0
        ops.add(op);
      }
    }
    return Script(ops);
  }

  /// List of operations. Can be [int] (OpCode) or [Uint8List] (Push Data).
  final List<dynamic> ops;

  /// Compiles the script to bytes.
  Uint8List compile() {
    final buffer = BytesBuilder();
    for (final op in ops) {
      if (op is int) {
        buffer.addByte(op);
      } else if (op is Uint8List) {
        _writePushData(buffer, op);
      } else if (op is List<int>) {
        _writePushData(buffer, Uint8List.fromList(op));
      } else {
        throw ArgumentError('Invalid script operation: $op');
      }
    }
    return buffer.toBytes();
  }

  void _writePushData(BytesBuilder buffer, Uint8List data) {
    if (data.isEmpty) {
      buffer.addByte(OpCode.op0);
    } else if (data.length <= 75) {
      buffer.addByte(data.length);
      buffer.add(data);
    } else if (data.length <= 0xff) {
      buffer.addByte(OpCode.opPushData1);
      buffer.addByte(data.length);
      buffer.add(data);
    } else if (data.length <= 0xffff) {
      buffer.addByte(OpCode.opPushData2);
      buffer.add(Uint8List(2)..buffer.asByteData().setUint16(0, data.length, Endian.little));
      buffer.add(data);
    } else {
      buffer.addByte(OpCode.opPushData4);
      buffer.add(Uint8List(4)..buffer.asByteData().setUint32(0, data.length, Endian.little));
      buffer.add(data);
    }
  }

  // --- Type Matching ---

  bool get isP2PKH {
    // OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG
    return ops.length == 5 &&
        ops[0] == OpCode.opDup &&
        ops[1] == OpCode.opHash160 &&
        ops[2] is Uint8List && (ops[2] as Uint8List).length == 20 &&
        ops[3] == OpCode.opEqualVerify &&
        ops[4] == OpCode.opCheckSig;
  }

  bool get isP2SH {
     // OP_HASH160 <20 bytes> OP_EQUAL
     return ops.length == 3 &&
         ops[0] == OpCode.opHash160 &&
         ops[1] is Uint8List && (ops[1] as Uint8List).length == 20 &&
         ops[2] == OpCode.opEqual;
  }

  bool get isP2WPKH {
    // OP_0 <20 bytes>
    return ops.length == 2 &&
        ops[0] == OpCode.op0 &&
        ops[1] is Uint8List && (ops[1] as Uint8List).length == 20;
  }

  bool get isP2WSH {
    // OP_0 <32 bytes>
    return ops.length == 2 &&
        ops[0] == OpCode.op0 &&
        ops[1] is Uint8List && (ops[1] as Uint8List).length == 32;
  }

  bool get isP2TR {
    // OP_1 <32 bytes>
    return ops.length == 2 &&
        ops[0] == OpCode.op1 &&
        ops[1] is Uint8List && (ops[1] as Uint8List).length == 32;
  }

  // --- Static Builders (Helpers) ---

  static Uint8List p2pkh(Uint8List pubKeyHash) {
     return Script([
       OpCode.opDup,
       OpCode.opHash160,
       pubKeyHash,
       OpCode.opEqualVerify,
       OpCode.opCheckSig,
     ]).compile();
  }

  static Uint8List p2sh(Uint8List scriptHash) {
    return Script([
      OpCode.opHash160,
      scriptHash,
      OpCode.opEqual, 
    ]).compile(); // Note: Previous uses OP_EQUALVERIFY, Standard P2SH is OP_EQUAL for ScriptHash?
    // Wait, P2SH scriptPubKey is OP_HASH160 <hash> OP_EQUAL.
    // The previous implementation used OP_EQUALVERIFY. Let's verify standard.
    // BIP-16: OP_HASH160 [20-byte-hash-value] OP_EQUAL
  }

  static Uint8List p2wpkh(Uint8List pubKeyHash) {
    return Script([
      OpCode.op0,
      pubKeyHash,
    ]).compile();
  }

  static Uint8List p2tr(Uint8List outputKey) {
    return Script([
      OpCode.op1,
      outputKey,
    ]).compile();
  }
}
