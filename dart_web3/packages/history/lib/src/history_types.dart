import 'package:dart_web3_core/dart_web3_core.dart';

/// Transaction history item type
enum TransactionType {
  transfer,
  contractCall,
  deployment,
  other,
}

/// Transaction history item
class HistoryItem {
  final String hash;
  final BigInt blockNumber;
  final DateTime timestamp;
  final EthereumAddress from;
  final EthereumAddress? to;
  final BigInt value;
  final TransactionType type;
  final String? functionName;
  final Map<String, dynamic> rawTransaction;

  const HistoryItem({
    required this.hash,
    required this.blockNumber,
    required this.timestamp,
    required this.from,
    this.to,
    required this.value,
    required this.type,
    this.functionName,
    required this.rawTransaction,
  });

  @override
  String toString() => 'HistoryItem(hash: $hash, type: $type, value: $value)';
}

/// Query parameters for fetching history
class HistoryQueryParams {
  final EthereumAddress address;
  final int? fromBlock;
  final int? toBlock;
  final int page;
  final int pageSize;
  final List<TransactionType>? types;

  const HistoryQueryParams({
    required this.address,
    this.fromBlock,
    this.toBlock,
    this.page = 1,
    this.pageSize = 20,
    this.types,
  });
}
