import 'package:web3_universal_utxo/src/models/utxo.dart';

import '../models/address.dart';

class SelectionResult {
  SelectionResult({
    required this.inputs,
    required this.outputs,
    required this.fee,
    required this.change,
  });

  final List<Utxo> inputs;
  final List<Utxo> outputs; // Changed from TransactionOutput model for simplicity in this abstract, but usually should be TxOutput
  final BigInt fee;
  final BigInt change;
}

abstract class CoinSelector {
  SelectionResult select(
    List<Utxo> utxos,
    BigInt targetAmount, {
    required int feeRate, // sats/vbyte
    required AddressType changeType,
    int outputCount = 2, // 1 target + 1 change
  });
}

class SimpleCoinSelector implements CoinSelector {
  // Input sizes (vbytes)
  static const int inputSizeP2PKH = 148;
  static const int inputSizeP2WPKH = 68;
  static const int inputSizeP2TR = 58;

  // Output sizes
  static const int outputSizeP2PKH = 34;
  static const int outputSizeP2WPKH = 31;
  static const int outputSizeP2TR = 43;
  static const int overhead = 10; // Version, locktime...

  @override
  SelectionResult select(
    List<Utxo> utxos,
    BigInt targetAmount, {
    required int feeRate,
    required AddressType changeType,
    int outputCount = 2,
  }) {
    // 1. Sort by value descending (optimization to reduce inputs)
    final sorted = List<Utxo>.from(utxos)
      ..sort((a, b) => b.value.compareTo(a.value));

    var accumulated = BigInt.zero;
    final selected = <Utxo>[];
    var bytes = overhead + (outputCount * _getOutputSize(changeType));

    for (final utxo in sorted) {
      selected.add(utxo);
      accumulated += utxo.value;
      bytes += _getInputSize(utxo);

      final fee = BigInt.from(bytes * feeRate);
      if (accumulated >= targetAmount + fee) {
        final change = accumulated - targetAmount - fee;
        return SelectionResult(
          inputs: selected,
          outputs: [], // Caller constructs outputs
          fee: fee,
          change: change,
        );
      }
    }

    throw Exception('Insufficient funds');
  }

  int _getInputSize(Utxo utxo) {
    // Simplistic size estimation based on script length or assumption
    // Ideally Utxo should contain type or we infer it.
    // Assuming P2WPKH for now if untyped, or based on script length.
    final scriptLen = utxo.scriptPubKey.length;
    if (scriptLen == 22 && utxo.scriptPubKey[0] == 0x00) return inputSizeP2WPKH;
    if (scriptLen == 34 && utxo.scriptPubKey[0] == 0x51) return inputSizeP2TR;
    return inputSizeP2PKH; // Fallback to largest
  }

  int _getOutputSize(AddressType type) {
    switch (type) {
      case AddressType.p2pkh:
      case AddressType.p2sh:
        return outputSizeP2PKH;
      case AddressType.p2wpkh:
      case AddressType.p2wsh:
        return outputSizeP2WPKH;
      case AddressType.p2tr:
        return outputSizeP2TR;
    }
  }
}
