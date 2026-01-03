import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_utxo/src/models/transaction.dart';

/// Represents an Unspent Transaction Output.
class Utxo {
  Utxo({
    required this.txHash,
    required this.vout,
    required this.value,
    required this.scriptPubKey,
    this.blockHeight,
    this.isCoinbase = false,
  });

  /// Transaction hash (hex string or bytes).
  final String txHash;

  /// Output index.
  final int vout;

  /// Amount in satoshis.
  final BigInt value;

  /// Script Public Key (locking script).
  final Uint8List scriptPubKey;

  /// Block height where this UTXO was confirmed.
  final int? blockHeight;

  /// Whether this is a coinbase output.
  final bool isCoinbase;

  /// Converts this UTXO to a transaction input.
  TransactionInput toInput({
    Uint8List? scriptSig,
    int sequence = 0xffffffff,
    List<Uint8List>? witness,
  }) {
    return TransactionInput(
      txId: HexUtils.decode(txHash).reversed.toList() is Uint8List 
          ? HexUtils.decode(txHash).reversed.toList() as Uint8List 
          : Uint8List.fromList(HexUtils.decode(txHash).reversed.toList()),
      vout: vout,
      scriptSig: scriptSig,
      sequence: sequence,
      witness: witness,
    );
  }
}
