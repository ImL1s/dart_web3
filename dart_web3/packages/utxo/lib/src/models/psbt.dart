import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';

import 'transaction.dart';

/// Partially Signed Bitcoin Transaction (BIP-174).
class Psbt {
  Psbt({
    required this.unsignedTx,
    this.inputs = const [],
    this.outputs = const [],
    this.globalXpubs = const {},
  });

  /// Magic bytes for PSBT (hex: 70736274ff).
  static final Uint8List magic =
      Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff]);

  /// The global unsigned transaction.
  final BitcoinTransaction unsignedTx;

  /// Input maps.
  final List<PsbtInput> inputs;

  /// Output maps.
  final List<PsbtOutput> outputs;

  /// Global xpubs map (fingerprint + path).
  final Map<String, String> globalXpubs;

  /// Parses a PSBT from bytes.
  static Psbt fromBytes(Uint8List bytes) {
    if (bytes.length < 5 || !_bytesEqual(bytes.sublist(0, 5), magic)) {
      throw FormatException('Invalid PSBT magic bytes');
    }

    var offset = 5;

    // 1. Read Global Map
    final globalMap = _readMap(bytes, offset);
    offset = globalMap.endOffset;

    // Parse global transaction (Key 0x00)
    final txBytes = globalMap.data['00'];
    if (txBytes == null) {
      throw FormatException('PSBT missing global transaction');
    }

    final unsignedTx = BitcoinTransaction.fromBytes(txBytes);

    // 2. Read Inputs/Outputs
    // The number of inputs/outputs must match the unsignedTx
    // TODO: Implement proper reading loop based on tx input/output count

    return Psbt(unsignedTx: unsignedTx);
  }
}

class PsbtInput {
  PsbtInput({
    this.nonWitnessUtxo,
    this.witnessUtxo,
    this.partialSigs = const {},
    this.sighashType,
    this.redeemScript,
    this.witnessScript,
    this.bip32Derivation = const {},
    this.finalScriptSig,
    this.finalScriptWitness,
  });

  final Uint8List? nonWitnessUtxo;
  final TransactionOutput? witnessUtxo; // Need TransactionOutput parsing
  final Map<String, Uint8List> partialSigs;
  final int? sighashType;
  final Uint8List? redeemScript;
  final Uint8List? witnessScript;
  final Map<String, String> bip32Derivation;
  final Uint8List? finalScriptSig;
  final Uint8List? finalScriptWitness;
}

class PsbtOutput {
  PsbtOutput({
    this.redeemScript,
    this.witnessScript,
    this.bip32Derivation = const {},
  });

  final Uint8List? redeemScript;
  final Uint8List? witnessScript;
  final Map<String, String> bip32Derivation;
}

class _MapResult {
  _MapResult(this.data, this.endOffset);
  final Map<String, Uint8List> data;
  final int endOffset;
}

_MapResult _readMap(Uint8List bytes, int offset) {
  final map = <String, Uint8List>{};
  var current = offset;

  while (current < bytes.length) {
    // Read Key Length
    final keyLenVar = _readVarInt(bytes, current);
    final keyLen = keyLenVar.value;
    current = keyLenVar.nextOffset;

    if (keyLen == 0) {
      // Separator 0x00 indicates end of map
      break;
    }

    // Read Key
    final key = bytes.sublist(current, current + keyLen);
    current += keyLen;

    // Read Value Length
    final valLenVar = _readVarInt(bytes, current);
    final valLen = valLenVar.value;
    current = valLenVar.nextOffset;

    // Read Value
    final value = bytes.sublist(current, current + valLen);
    current += valLen;

    map[HexUtils.encode(key)] = value;
  }

  return _MapResult(map, current);
}

class _VarIntResult {
  _VarIntResult(this.value, this.nextOffset);
  final int value;
  final int nextOffset;
}

_VarIntResult _readVarInt(Uint8List bytes, int offset) {
  final first = bytes[offset];
  if (first < 0xfd) {
    return _VarIntResult(first, offset + 1);
  } else if (first == 0xfd) {
    final val = ByteData.sublistView(bytes, offset + 1, offset + 3)
        .getUint16(0, Endian.little);
    return _VarIntResult(val, offset + 3);
  } else if (first == 0xfe) {
    final val = ByteData.sublistView(bytes, offset + 1, offset + 5)
        .getUint32(0, Endian.little);
    return _VarIntResult(val, offset + 5);
  } else {
    final val = ByteData.sublistView(bytes, offset + 1, offset + 9)
        .getUint64(0, Endian.little);
    return _VarIntResult(val, offset + 9);
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
