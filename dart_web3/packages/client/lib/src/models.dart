import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';

/// Block data.
class Block {
  Block({
    required this.hash,
    required this.parentHash,
    required this.number,
    required this.timestamp,
    required this.miner,
    required this.gasLimit,
    required this.gasUsed,
    required this.transactions,
    this.baseFeePerGas,
  });

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      hash: json['hash'] as String,
      parentHash: json['parentHash'] as String,
      number: BigInt.parse((json['number'] as String).substring(2), radix: 16),
      timestamp:
          BigInt.parse((json['timestamp'] as String).substring(2), radix: 16),
      miner: json['miner'] as String,
      gasLimit:
          BigInt.parse((json['gasLimit'] as String).substring(2), radix: 16),
      gasUsed:
          BigInt.parse((json['gasUsed'] as String).substring(2), radix: 16),
      baseFeePerGas: json['baseFeePerGas'] != null
          ? BigInt.parse(
              (json['baseFeePerGas'] as String).substring(2),
              radix: 16,
            )
          : null,
      transactions: (json['transactions'] as List).map((t) {
        if (t is String) return t;
        return (t as Map<String, dynamic>)['hash'] as String;
      }).toList(),
    );
  }
  final String hash;
  final String parentHash;
  final BigInt number;
  final BigInt timestamp;
  final String miner;
  final BigInt gasLimit;
  final BigInt gasUsed;
  final BigInt? baseFeePerGas;
  final List<String> transactions;
}

/// Transaction data.
class Transaction {
  Transaction({
    required this.hash,
    required this.from,
    required this.value,
    required this.gasLimit,
    required this.data,
    required this.nonce,
    required this.chainId,
    this.blockHash,
    this.blockNumber,
    this.transactionIndex,
    this.to,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      hash: json['hash'] as String,
      blockHash: json['blockHash'] as String?,
      blockNumber: json['blockNumber'] != null
          ? BigInt.parse(
              (json['blockNumber'] as String).substring(2),
              radix: 16,
            )
          : null,
      transactionIndex: json['transactionIndex'] != null
          ? int.parse(
              (json['transactionIndex'] as String).substring(2),
              radix: 16,
            )
          : null,
      from: json['from'] as String,
      to: json['to'] as String?,
      value: BigInt.parse((json['value'] as String).substring(2), radix: 16),
      gasLimit: BigInt.parse((json['gas'] as String).substring(2), radix: 16),
      gasPrice: json['gasPrice'] != null
          ? BigInt.parse((json['gasPrice'] as String).substring(2), radix: 16)
          : null,
      maxFeePerGas: json['maxFeePerGas'] != null
          ? BigInt.parse(
              (json['maxFeePerGas'] as String).substring(2),
              radix: 16,
            )
          : null,
      maxPriorityFeePerGas: json['maxPriorityFeePerGas'] != null
          ? BigInt.parse(
              (json['maxPriorityFeePerGas'] as String).substring(2),
              radix: 16,
            )
          : null,
      data: HexUtils.decode(json['input'] as String),
      nonce: BigInt.parse((json['nonce'] as String).substring(2), radix: 16),
      chainId: json['chainId'] != null
          ? int.parse((json['chainId'] as String).substring(2), radix: 16)
          : 1,
    );
  }
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
}

/// Transaction receipt.
class TransactionReceipt {
  TransactionReceipt({
    required this.transactionHash,
    required this.transactionIndex,
    required this.blockHash,
    required this.blockNumber,
    required this.from,
    required this.cumulativeGasUsed,
    required this.gasUsed,
    required this.logs,
    required this.status,
    this.to,
    this.contractAddress,
    this.effectiveGasPrice,
  });

  factory TransactionReceipt.fromJson(Map<String, dynamic> json) {
    return TransactionReceipt(
      transactionHash: json['transactionHash'] as String,
      transactionIndex: int.parse(
        (json['transactionIndex'] as String).substring(2),
        radix: 16,
      ),
      blockHash: json['blockHash'] as String,
      blockNumber:
          BigInt.parse((json['blockNumber'] as String).substring(2), radix: 16),
      from: json['from'] as String,
      to: json['to'] as String?,
      cumulativeGasUsed: BigInt.parse(
        (json['cumulativeGasUsed'] as String).substring(2),
        radix: 16,
      ),
      gasUsed:
          BigInt.parse((json['gasUsed'] as String).substring(2), radix: 16),
      contractAddress: json['contractAddress'] as String?,
      logs: (json['logs'] as List)
          .map((l) => Log.fromJson(l as Map<String, dynamic>))
          .toList(),
      status: int.parse((json['status'] as String).substring(2), radix: 16),
      effectiveGasPrice: json['effectiveGasPrice'] != null
          ? BigInt.parse(
              (json['effectiveGasPrice'] as String).substring(2),
              radix: 16,
            )
          : null,
    );
  }
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

  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'transactionIndex': '0x${transactionIndex.toRadixString(16)}',
      'blockHash': blockHash,
      'blockNumber': '0x${blockNumber.toRadixString(16)}',
      'from': from,
      if (to != null) 'to': to,
      'cumulativeGasUsed': '0x${cumulativeGasUsed.toRadixString(16)}',
      'gasUsed': '0x${gasUsed.toRadixString(16)}',
      if (contractAddress != null) 'contractAddress': contractAddress,
      'logs': logs.map((l) => l.toJson()).toList(),
      'status': '0x${status.toRadixString(16)}',
      if (effectiveGasPrice != null)
        'effectiveGasPrice': '0x${effectiveGasPrice!.toRadixString(16)}',
    };
  }

  /// Whether the transaction succeeded.
  bool get success => status == 1;
}

/// Event log.
class Log {
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
      blockNumber:
          BigInt.parse((json['blockNumber'] as String).substring(2), radix: 16),
      transactionHash: json['transactionHash'] as String,
      transactionIndex: int.parse(
        (json['transactionIndex'] as String).substring(2),
        radix: 16,
      ),
      logIndex: int.parse((json['logIndex'] as String).substring(2), radix: 16),
      removed: json['removed'] as bool? ?? false,
    );
  }
  final String address;
  final List<String> topics;
  final Uint8List data;
  final String blockHash;
  final BigInt blockNumber;
  final String transactionHash;
  final int transactionIndex;
  final int logIndex;
  final bool removed;

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'topics': topics,
      'data': HexUtils.encode(data),
      'blockHash': blockHash,
      'blockNumber': '0x${blockNumber.toRadixString(16)}',
      'transactionHash': transactionHash,
      'transactionIndex': '0x${transactionIndex.toRadixString(16)}',
      'logIndex': '0x${logIndex.toRadixString(16)}',
      'removed': removed,
    };
  }
}

/// Log filter.
class LogFilter {
  LogFilter({this.address, this.topics, this.fromBlock, this.toBlock});
  final String? address;
  final List<dynamic>? topics;
  final String? fromBlock;
  final String? toBlock;

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
  final String? from;
  final String? to;
  final Uint8List? data;
  final BigInt? value;
  final BigInt? gasLimit;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;

  Map<String, dynamic> toJson() {
    return {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (data != null) 'data': HexUtils.encode(data!),
      if (value != null) 'value': '0x${value!.toRadixString(16)}',
      if (gasLimit != null) 'gas': '0x${gasLimit!.toRadixString(16)}',
      if (gasPrice != null) 'gasPrice': '0x${gasPrice!.toRadixString(16)}',
      if (maxFeePerGas != null)
        'maxFeePerGas': '0x${maxFeePerGas!.toRadixString(16)}',
      if (maxPriorityFeePerGas != null)
        'maxPriorityFeePerGas': '0x${maxPriorityFeePerGas!.toRadixString(16)}',
    };
  }
}

/// Fee data for EIP-1559 transactions.
class FeeData {
  FeeData({
    required this.gasPrice,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
  });
  final BigInt gasPrice;
  final BigInt maxFeePerGas;
  final BigInt maxPriorityFeePerGas;
}
