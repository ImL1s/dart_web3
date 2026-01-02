import 'dart:async';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'history_types.dart';

/// Service for fetching transaction history
class HistoryService {

  HistoryService();

  /// Fetch transaction history for an address
  Future<List<HistoryItem>> getHistory(HistoryQueryParams params) async {
    // In a real-world scenario, this would call an indexer API (Etherscan, Moralis, etc.)
    // Standard JSON-RPC doesn't provide efficient history by address.
    // For this SDK, we provide the abstraction and a placeholder for integration.
    return [];
  }

  /// Decode raw transaction into history item
  HistoryItem decodeTransaction(Map<String, dynamic> tx, DateTime timestamp) {
    final from = EthereumAddress.fromHex(tx['from'] as String);
    final to = tx['to'] != null ? EthereumAddress.fromHex(tx['to'] as String) : null;
    final value = BigInt.parse(tx['value'] as String);
    final input = tx['input'] as String;

    var type = TransactionType.transfer;
    String? functionName;

    if (to == null) {
      type = TransactionType.deployment;
    } else if (input != '0x' && input.isNotEmpty) {
      type = TransactionType.contractCall;
      // Basic decoding: extract method ID (first 4 bytes)
      if (input.length >= 10) {
        functionName = 'method_${input.substring(2, 10)}';
      }
    }

    return HistoryItem(
      hash: tx['hash'] as String,
      blockNumber: BigInt.parse(tx['blockNumber'] as String),
      timestamp: timestamp,
      from: from,
      to: to,
      value: value,
      type: type,
      functionName: functionName,
      rawTransaction: tx,
    );
  }
}
