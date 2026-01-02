import 'dart:typed_data';

/// Token information for swaps
class SwapToken {

  const SwapToken({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.chainId,
    this.logoUri,
  });

  factory SwapToken.fromJson(Map<String, dynamic> json) {
    return SwapToken(
      address: json['address'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      chainId: json['chainId'] as int,
      logoUri: json['logoUri'] as String?,
    );
  }
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final int chainId;
  final String? logoUri;

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'symbol': symbol,
      'name': name,
      'decimals': decimals,
      'chainId': chainId,
      if (logoUri != null) 'logoUri': logoUri,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwapToken &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          chainId == other.chainId;

  @override
  int get hashCode => address.hashCode ^ chainId.hashCode;
}

/// Swap parameters
class SwapParams {

  const SwapParams({
    required this.fromToken,
    required this.toToken,
    required this.amount,
    required this.fromAddress,
    this.toAddress,
    this.slippage = 0.005, // 0.5% default
    this.enableMevProtection = false,
    this.deadline,
    this.metadata,
  });
  final SwapToken fromToken;
  final SwapToken toToken;
  final BigInt amount;
  final String fromAddress;
  final String? toAddress;
  final double slippage;
  final bool enableMevProtection;
  final Duration? deadline;
  final Map<String, dynamic>? metadata;

  SwapParams copyWith({
    SwapToken? fromToken,
    SwapToken? toToken,
    BigInt? amount,
    String? fromAddress,
    String? toAddress,
    double? slippage,
    bool? enableMevProtection,
    Duration? deadline,
    Map<String, dynamic>? metadata,
  }) {
    return SwapParams(
      fromToken: fromToken ?? this.fromToken,
      toToken: toToken ?? this.toToken,
      amount: amount ?? this.amount,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      slippage: slippage ?? this.slippage,
      enableMevProtection: enableMevProtection ?? this.enableMevProtection,
      deadline: deadline ?? this.deadline,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Swap route information
class SwapRoute {

  const SwapRoute({
    required this.path,
    required this.exchanges,
    required this.portions,
    required this.gasEstimate,
    this.metadata,
  });

  factory SwapRoute.fromJson(Map<String, dynamic> json) {
    return SwapRoute(
      path: (json['path'] as List)
          .map((e) => SwapToken.fromJson(e as Map<String, dynamic>))
          .toList(),
      exchanges: (json['exchanges'] as List).cast<String>(),
      portions: (json['portions'] as List).cast<double>(),
      gasEstimate: BigInt.parse(json['gasEstimate'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final List<SwapToken> path;
  final List<String> exchanges;
  final List<double> portions;
  final BigInt gasEstimate;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'path': path.map((e) => e.toJson()).toList(),
      'exchanges': exchanges,
      'portions': portions,
      'gasEstimate': gasEstimate.toString(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Swap transaction data
class SwapTransaction {

  const SwapTransaction({
    required this.to,
    required this.data,
    required this.value,
    required this.gasLimit,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  factory SwapTransaction.fromJson(Map<String, dynamic> json) {
    return SwapTransaction(
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
    );
  }
  final String to;
  final Uint8List data;
  final BigInt value;
  final BigInt gasLimit;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;

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
    };
  }
}

/// Swap status enumeration
enum SwapStatus {
  pending,
  confirmed,
  failed,
  cancelled,
}

/// MEV protection options
enum MevProtectionType {
  none,
  flashbots,
  mevBlocker,
  eden,
}

/// Cross-chain swap information
class CrossChainSwapInfo {

  const CrossChainSwapInfo({
    required this.sourceChainId,
    required this.destinationChainId,
    required this.bridgeProtocol,
    required this.estimatedTime,
    required this.bridgeFee,
  });

  factory CrossChainSwapInfo.fromJson(Map<String, dynamic> json) {
    return CrossChainSwapInfo(
      sourceChainId: json['sourceChainId'] as int,
      destinationChainId: json['destinationChainId'] as int,
      bridgeProtocol: json['bridgeProtocol'] as String,
      estimatedTime: Duration(seconds: json['estimatedTimeSeconds'] as int),
      bridgeFee: BigInt.parse(json['bridgeFee'] as String),
    );
  }
  final int sourceChainId;
  final int destinationChainId;
  final String bridgeProtocol;
  final Duration estimatedTime;
  final BigInt bridgeFee;

  Map<String, dynamic> toJson() {
    return {
      'sourceChainId': sourceChainId,
      'destinationChainId': destinationChainId,
      'bridgeProtocol': bridgeProtocol,
      'estimatedTimeSeconds': estimatedTime.inSeconds,
      'bridgeFee': bridgeFee.toString(),
    };
  }
}
