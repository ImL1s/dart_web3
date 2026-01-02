import 'dart:typed_data';

/// Bridge token information
class BridgeToken { // Token addresses on different chains

  const BridgeToken({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.chainId,
    this.logoUri,
    this.addressByChain,
  });

  factory BridgeToken.fromJson(Map<String, dynamic> json) {
    return BridgeToken(
      address: json['address'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      chainId: json['chainId'] as int,
      logoUri: json['logoUri'] as String?,
      addressByChain: json['addressByChain'] != null
          ? Map<int, String>.from(json['addressByChain'] as Map)
          : null,
    );
  }
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final int chainId;
  final String? logoUri;
  final Map<int, String>? addressByChain;

  /// Get token address on a specific chain
  String? getAddressOnChain(int targetChainId) {
    if (targetChainId == chainId) return address;
    return addressByChain?[targetChainId];
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'symbol': symbol,
      'name': name,
      'decimals': decimals,
      'chainId': chainId,
      if (logoUri != null) 'logoUri': logoUri,
      if (addressByChain != null) 'addressByChain': addressByChain,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeToken &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          chainId == other.chainId;

  @override
  int get hashCode => address.hashCode ^ chainId.hashCode;
}

/// Bridge transfer parameters
class BridgeParams {

  const BridgeParams({
    required this.fromToken,
    required this.toToken,
    required this.sourceChainId,
    required this.destinationChainId,
    required this.amount,
    required this.fromAddress,
    required this.toAddress,
    this.slippage = 0.005, // 0.5% default
    this.deadline,
    this.metadata,
  });
  final BridgeToken fromToken;
  final BridgeToken toToken;
  final int sourceChainId;
  final int destinationChainId;
  final BigInt amount;
  final String fromAddress;
  final String toAddress;
  final double slippage;
  final Duration? deadline;
  final Map<String, dynamic>? metadata;

  /// Check if this is a cross-chain transfer
  bool get isCrossChain => sourceChainId != destinationChainId;

  BridgeParams copyWith({
    BridgeToken? fromToken,
    BridgeToken? toToken,
    int? sourceChainId,
    int? destinationChainId,
    BigInt? amount,
    String? fromAddress,
    String? toAddress,
    double? slippage,
    Duration? deadline,
    Map<String, dynamic>? metadata,
  }) {
    return BridgeParams(
      fromToken: fromToken ?? this.fromToken,
      toToken: toToken ?? this.toToken,
      sourceChainId: sourceChainId ?? this.sourceChainId,
      destinationChainId: destinationChainId ?? this.destinationChainId,
      amount: amount ?? this.amount,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      slippage: slippage ?? this.slippage,
      deadline: deadline ?? this.deadline,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Bridge transaction data
class BridgeTransaction {

  const BridgeTransaction({
    required this.to,
    required this.data,
    required this.value,
    required this.gasLimit,
    required this.chainId, this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  factory BridgeTransaction.fromJson(Map<String, dynamic> json) {
    return BridgeTransaction(
      to: json['to'] as String,
      data: Uint8List.fromList((json['data'] as String).codeUnits),
      value: BigInt.parse(json['value'] as String),
      gasLimit: BigInt.parse(json['gasLimit'] as String),
      gasPrice: json['gasPrice'] != null 
          ? BigInt.parse(json['gasPrice'] as String) 
          : null,
      maxFeePerGas: json['maxFeePerGas'] != null 
          ? BigInt.parse(json['maxFeePerGas'] as String) 
          : null,
      maxPriorityFeePerGas: json['maxPriorityFeePerGas'] != null 
          ? BigInt.parse(json['maxPriorityFeePerGas'] as String) 
          : null,
      chainId: json['chainId'] as int,
    );
  }
  final String to;
  final Uint8List data;
  final BigInt value;
  final BigInt gasLimit;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;
  final int chainId;

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'data': String.fromCharCodes(data),
      'value': value.toString(),
      'gasLimit': gasLimit.toString(),
      if (gasPrice != null) 'gasPrice': gasPrice.toString(),
      if (maxFeePerGas != null) 'maxFeePerGas': maxFeePerGas.toString(),
      if (maxPriorityFeePerGas != null) 
        'maxPriorityFeePerGas': maxPriorityFeePerGas.toString(),
      'chainId': chainId,
    };
  }
}

/// Bridge route information
class BridgeRoute {

  const BridgeRoute({
    required this.protocol,
    required this.steps,
    required this.estimatedTime,
    required this.totalFee,
    required this.confidence,
    this.metadata,
  });

  factory BridgeRoute.fromJson(Map<String, dynamic> json) {
    return BridgeRoute(
      protocol: json['protocol'] as String,
      steps: (json['steps'] as List)
          .map((e) => BridgeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      estimatedTime: Duration(seconds: json['estimatedTimeSeconds'] as int),
      totalFee: BigInt.parse(json['totalFee'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String protocol;
  final List<BridgeStep> steps;
  final Duration estimatedTime;
  final BigInt totalFee;
  final double confidence; // 0.0 to 1.0
  final Map<String, dynamic>? metadata;

  /// Check if this is a direct bridge (single step)
  bool get isDirect => steps.length == 1;

  /// Get total number of transactions required
  int get totalTransactions => steps.length;

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'steps': steps.map((e) => e.toJson()).toList(),
      'estimatedTimeSeconds': estimatedTime.inSeconds,
      'totalFee': totalFee.toString(),
      'confidence': confidence,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Individual step in a bridge route
class BridgeStep {

  const BridgeStep({
    required this.fromChainId,
    required this.toChainId,
    required this.protocol,
    required this.fromToken,
    required this.toToken,
    required this.inputAmount,
    required this.outputAmount,
    required this.fee,
    required this.estimatedTime,
    this.transaction,
  });

  factory BridgeStep.fromJson(Map<String, dynamic> json) {
    return BridgeStep(
      fromChainId: json['fromChainId'] as int,
      toChainId: json['toChainId'] as int,
      protocol: json['protocol'] as String,
      fromToken: BridgeToken.fromJson(json['fromToken'] as Map<String, dynamic>),
      toToken: BridgeToken.fromJson(json['toToken'] as Map<String, dynamic>),
      inputAmount: BigInt.parse(json['inputAmount'] as String),
      outputAmount: BigInt.parse(json['outputAmount'] as String),
      fee: BigInt.parse(json['fee'] as String),
      estimatedTime: Duration(seconds: json['estimatedTimeSeconds'] as int),
      transaction: json['transaction'] != null
          ? BridgeTransaction.fromJson(json['transaction'] as Map<String, dynamic>)
          : null,
    );
  }
  final int fromChainId;
  final int toChainId;
  final String protocol;
  final BridgeToken fromToken;
  final BridgeToken toToken;
  final BigInt inputAmount;
  final BigInt outputAmount;
  final BigInt fee;
  final Duration estimatedTime;
  final BridgeTransaction? transaction;

  Map<String, dynamic> toJson() {
    return {
      'fromChainId': fromChainId,
      'toChainId': toChainId,
      'protocol': protocol,
      'fromToken': fromToken.toJson(),
      'toToken': toToken.toJson(),
      'inputAmount': inputAmount.toString(),
      'outputAmount': outputAmount.toString(),
      'fee': fee.toString(),
      'estimatedTimeSeconds': estimatedTime.inSeconds,
      if (transaction != null) 'transaction': transaction!.toJson(),
    };
  }
}

/// Bridge status enumeration
enum BridgeStatus {
  pending,
  sourceConfirmed,
  bridging,
  destinationPending,
  completed,
  failed,
  refunded,
}

/// Bridge protocol types
enum BridgeProtocolType {
  layerZero,
  wormhole,
  stargate,
  nativeBridge,
  celerCBridge,
  hopProtocol,
  acrossBridge,
  synapseBridge,
}

/// Fee breakdown for bridge operations
class BridgeFeeBreakdown {

  const BridgeFeeBreakdown({
    required this.protocolFee,
    required this.gasFee,
    required this.relayerFee,
    required this.liquidityFee,
    required this.totalFee,
    required this.feeToken,
  });

  factory BridgeFeeBreakdown.fromJson(Map<String, dynamic> json) {
    return BridgeFeeBreakdown(
      protocolFee: BigInt.parse(json['protocolFee'] as String),
      gasFee: BigInt.parse(json['gasFee'] as String),
      relayerFee: BigInt.parse(json['relayerFee'] as String),
      liquidityFee: BigInt.parse(json['liquidityFee'] as String),
      totalFee: BigInt.parse(json['totalFee'] as String),
      feeToken: json['feeToken'] as String,
    );
  }
  final BigInt protocolFee;
  final BigInt gasFee;
  final BigInt relayerFee;
  final BigInt liquidityFee;
  final BigInt totalFee;
  final String feeToken;

  /// Get fee as percentage of transfer amount
  double getFeePercentage(BigInt transferAmount) {
    if (transferAmount == BigInt.zero) return 0;
    return (totalFee.toDouble() / transferAmount.toDouble()) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'protocolFee': protocolFee.toString(),
      'gasFee': gasFee.toString(),
      'relayerFee': relayerFee.toString(),
      'liquidityFee': liquidityFee.toString(),
      'totalFee': totalFee.toString(),
      'feeToken': feeToken,
    };
  }
}

/// Bridge limits for a specific route
class BridgeLimits {

  const BridgeLimits({
    required this.minAmount,
    required this.maxAmount,
    required this.dailyLimit,
    required this.remainingDailyLimit,
  });

  factory BridgeLimits.fromJson(Map<String, dynamic> json) {
    return BridgeLimits(
      minAmount: BigInt.parse(json['minAmount'] as String),
      maxAmount: BigInt.parse(json['maxAmount'] as String),
      dailyLimit: BigInt.parse(json['dailyLimit'] as String),
      remainingDailyLimit: BigInt.parse(json['remainingDailyLimit'] as String),
    );
  }
  final BigInt minAmount;
  final BigInt maxAmount;
  final BigInt dailyLimit;
  final BigInt remainingDailyLimit;

  /// Check if amount is within limits
  bool isAmountValid(BigInt amount) {
    return amount >= minAmount && 
           amount <= maxAmount && 
           amount <= remainingDailyLimit;
  }

  Map<String, dynamic> toJson() {
    return {
      'minAmount': minAmount.toString(),
      'maxAmount': maxAmount.toString(),
      'dailyLimit': dailyLimit.toString(),
      'remainingDailyLimit': remainingDailyLimit.toString(),
    };
  }
}
