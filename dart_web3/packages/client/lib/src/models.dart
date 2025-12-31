import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';

/// Block data.
class Block {
  final String hash;
  final String parentHash;
  final BigInt number;
  final BigInt timestamp;
  final String miner;
  final BigInt gasLimit;
  final BigInt gasUsed;
  final BigInt? baseFeePerGas;
  final List<String> transactions;

  Block({
    required this.hash,
    required this.parentHash,
    required this.number,
    required this.timestamp,
    required this.miner,
    required this.gasLimit,
    required this.gasUsed,
    this.baseFeePerGas,
    required this.transactions,
  });

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      hash: json['hash'] as String,
      parentHash: json['parentHash'] as String,
      number: BigInt.parse((json['number'] as String).substring(2), radix: 16),
      timestamp: BigInt.parse((json['timestamp'] as String).substring(2), radix: 16),
      miner: json['miner'] as String,
      gasLimit: BigInt.parse((json['gasLimit'] as String).substring(2), radix: 16),
      gasUsed: BigInt.parse((json['gasUsed'] as String).substring(2), radix: 16),
      baseFeePerGas: json['baseFeePerGas'] != null
          ? BigInt.parse((json['baseFeePerGas'] as String).substring(2), radix: 16)
          : null,
      transactions: (json['transactions'] as List).map((t) {
        if (t is String) return t;
        return t['hash'] as String;
      }).toList(),
    );
  }
}

/// Transaction data.
class Transaction {
  final String hash;
  final String? blockHash;
  final BigInt? blockNumber;
  final int? transactionIndex;
  final String from;
  final String? to;
  final BigInt value;
  final BigInt gasLimit;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;
  final Uint8List data;
  final BigInt nonce;
  final int chainId;

  Transaction({
    required this.hash,
    this.blockHash,
    this.blockNumber,
    this.transactionIndex,
    required this.from,
    this.to,
    required this.value,
    required this.gasLimit,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    required this.data,
    required this.nonce,
    required this.chainId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      hash: json['hash'] as String,
      blockHash: json['blockHash'] as String?,
      blockNumber: json['blockNumber'] != null
          ? BigInt.parse((json['blockNumber'] as String).substring(2), radix: 16)
          : null,
      transactionIndex: json['transactionIndex'] != null
          ? int.parse((json['transactionIndex'] as String).substring(2), radix: 16)
          : null,
      from: json['from'] as String,
      to: json['to'] as String?,
      value: BigInt.parse((json['value'] as String).substring(2), radix: 16),
      gasLimit: BigInt.parse((json['gas'] as String).substring(2), radix: 16),
      gasPrice: json['gasPrice'] != null
          ? BigInt.parse((json['gasPrice'] as String).substring(2), radix: 16)
          : null,
      maxFeePerGas: json['maxFeePerGas'] != null
          ? BigInt.parse((json['maxFeePerGas'] as String).substring(2), radix: 16)
          : null,
      maxPriorityFeePerGas: json['maxPriorityFeePerGas'] != null
          ? BigInt.parse((json['maxPriorityFeePerGas'] as String).substring(2), radix: 16)
          : null,
      data: HexUtils.decode(json['input'] as String),
      nonce: BigInt.parse((json['nonce'] as String).substring(2), radix: 16),
      chainId: json['chainId'] != null
          ? int.parse((json['chainId'] as String).substring(2), radix: 16)
          : 1,
    );
  }
}

/// Transaction receipt.
class TransactionReceipt {
  final String transactionHash;
  final int transactionIndex;
  final String blockHash;
  final BigInt blockNumber;
  final String from;
  final String? to;
  final BigInt cumulativeGasUsed;
  final BigInt gasUsed;
  final String? contractAddress;
  final List<Log> logs;
  final int status;
  final BigInt? effectiveGasPrice;

  TransactionReceipt({
    required this.transactionHash,
    required this.transactionIndex,
    required this.blockHash,
    required this.blockNumber,
    required this.from,
    this.to,
    required this.cumulativeGasUsed,
    required this.gasUsed,
    this.contractAddress,
    required this.logs,
    required this.status,
    this.effectiveGasPrice,
  });

  factory TransactionReceipt.fromJson(Map<String, dynamic> json) {
    return TransactionReceipt(
      transactionHash: json['transactionHash'] as String,
      transactionIndex: int.parse((json['transactionIndex'] as String).substring(2), radix: 16),
      blockHash: json['blockHash'] as String,
      blockNumber: BigInt.parse((json['blockNumber'] as String).substring(2), radix: 16),
      from: json['from'] as String,
      to: json['to'] as String?,
      cumulativeGasUsed:
          BigInt.parse((json['cumulativeGasUsed'] as String).substring(2), radix: 16),
      gasUsed: BigInt.parse((json['gasUsed'] as String).substring(2), radix: 16),
      contractAddress: json['contractAddress'] as String?,
      logs: (json['logs'] as List).map((l) => Log.fromJson(l as Map<String, dynamic>)).toList(),
      status: int.parse((json['status'] as String).substring(2), radix: 16),
      effectiveGasPrice: json['effectiveGasPrice'] != null
          ? BigInt.parse((json['effectiveGasPrice'] as String).substring(2), radix: 16)
          : null,
    );
  }

  /// Whether the transaction succeeded.
  bool get success => status == 1;
}

/// Event log.
class Log {
  final String address;
  final List<String> topics;
  final Uint8List data;
  final String blockHash;
  final BigInt blockNumber;
  final String transactionHash;
  final int transactionIndex;
  final int logIndex;
  final bool removed;

  Log({
    required this.address,
    required this.topics,
    required this.data,
    required this.blockHash,
    required this.blockNumber,
    required this.transactionHash,
    required this.transactionIndex,
    required this.logIndex,
    required this.removed,
  });

  factory Log.fromJson(Map<String, dynamic> json) {
    return Log(
      address: json['address'] as String,
      topics: (json['topics'] as List).cast<String>(),
      data: HexUtils.decode(json['data'] as String),
      blockHash: json['blockHash'] as String,
      blockNumber: BigInt.parse((json['blockNumber'] as String).substring(2), radix: 16),
      transactionHash: json['transactionHash'] as String,
      transactionIndex: int.parse((json['transactionIndex'] as String).substring(2), radix: 16),
      logIndex: int.parse((json['logIndex'] as String).substring(2), radix: 16),
      removed: json['removed'] as bool? ?? false,
    );
  }
}

/// Log filter.
class LogFilter {
  final String? address;
  final List<String?>? topics;
  final String? fromBlock;
  final String? toBlock;

  LogFilter({this.address, this.topics, this.fromBlock, this.toBlock});

  Map<String, dynamic> toJson() {
    return {
      if (address != null) 'address': address,
      if (topics != null) 'topics': topics,
      if (fromBlock != null) 'fromBlock': fromBlock,
      if (toBlock != null) 'toBlock': toBlock,
    };
  }
}

/// Call request.
class CallRequest {
  final String? from;
  final String? to;
  final Uint8List? data;
  final BigInt? value;
  final BigInt? gasLimit;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;

  CallRequest({
    this.from,
    this.to,
    this.data,
    this.value,
    this.gasLimit,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  Map<String, dynamic> toJson() {
    return {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (data != null) 'data': HexUtils.encode(data!),
      if (value != null) 'value': '0x${value!.toRadixString(16)}',
      if (gasLimit != null) 'gas': '0x${gasLimit!.toRadixString(16)}',
      if (gasPrice != null) 'gasPrice': '0x${gasPrice!.toRadixString(16)}',
      if (maxFeePerGas != null) 'maxFeePerGas': '0x${maxFeePerGas!.toRadixString(16)}',
      if (maxPriorityFeePerGas != null)
        'maxPriorityFeePerGas': '0x${maxPriorityFeePerGas!.toRadixString(16)}',
    };
  }
}

/// Fee data for EIP-1559 transactions.
class FeeData {
  final BigInt gasPrice;
  final BigInt maxFeePerGas;
  final BigInt maxPriorityFeePerGas;

  FeeData({
    required this.gasPrice,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
  });
}
