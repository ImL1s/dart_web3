import 'swap_types.dart';

/// Swap quote from an aggregator
class SwapQuote {
  const SwapQuote({
    required this.aggregator,
    required this.params,
    required this.outputAmount,
    required this.minimumOutputAmount,
    required this.route,
    required this.transaction,
    required this.estimatedGas,
    required this.gasCost,
    required this.priceImpact,
    required this.validUntil,
    this.crossChainInfo,
    this.metadata,
  });

  factory SwapQuote.fromJson(Map<String, dynamic> json) {
    return SwapQuote(
      aggregator: json['aggregator'] as String,
      params: SwapParams(
        fromToken:
            SwapToken.fromJson(json['fromToken'] as Map<String, dynamic>),
        toToken: SwapToken.fromJson(json['toToken'] as Map<String, dynamic>),
        amount: BigInt.parse(json['amount'] as String),
        fromAddress: json['fromAddress'] as String,
        toAddress: json['toAddress'] as String?,
        slippage: (json['slippage'] as num).toDouble(),
        enableMevProtection: json['enableMevProtection'] as bool? ?? false,
      ),
      outputAmount: BigInt.parse(json['outputAmount'] as String),
      minimumOutputAmount: BigInt.parse(json['minimumOutputAmount'] as String),
      route: SwapRoute.fromJson(json['route'] as Map<String, dynamic>),
      transaction:
          SwapTransaction.fromJson(json['transaction'] as Map<String, dynamic>),
      estimatedGas: BigInt.parse(json['estimatedGas'] as String),
      gasCost: BigInt.parse(json['gasCost'] as String),
      priceImpact: (json['priceImpact'] as num).toDouble(),
      validUntil: Duration(seconds: json['validUntilSeconds'] as int),
      crossChainInfo: json['crossChainInfo'] != null
          ? CrossChainSwapInfo.fromJson(
              json['crossChainInfo'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String aggregator;
  final SwapParams params;
  final BigInt outputAmount;
  final BigInt minimumOutputAmount;
  final SwapRoute route;
  final SwapTransaction transaction;
  final BigInt estimatedGas;
  final BigInt gasCost;
  final double priceImpact;
  final Duration validUntil;
  final CrossChainSwapInfo? crossChainInfo;
  final Map<String, dynamic>? metadata;

  /// Calculate the effective exchange rate
  double get exchangeRate {
    if (outputAmount == BigInt.zero) return 0;
    return outputAmount.toDouble() / params.amount.toDouble();
  }

  /// Calculate the total cost including gas
  BigInt get totalCost => gasCost;

  /// Calculate net output amount after gas costs (in output token terms)
  BigInt get netOutputAmount {
    // This is a simplified calculation - in reality you'd need to convert gas cost to output token
    return outputAmount;
  }

  /// Check if the quote is still valid
  bool get isValid => DateTime.now().isBefore(DateTime.now().add(validUntil));

  /// Check if this is a cross-chain swap
  bool get isCrossChain => crossChainInfo != null;

  Map<String, dynamic> toJson() {
    return {
      'aggregator': aggregator,
      'fromToken': params.fromToken.toJson(),
      'toToken': params.toToken.toJson(),
      'amount': params.amount.toString(),
      'fromAddress': params.fromAddress,
      if (params.toAddress != null) 'toAddress': params.toAddress,
      'slippage': params.slippage,
      'enableMevProtection': params.enableMevProtection,
      'outputAmount': outputAmount.toString(),
      'minimumOutputAmount': minimumOutputAmount.toString(),
      'route': route.toJson(),
      'transaction': transaction.toJson(),
      'estimatedGas': estimatedGas.toString(),
      'gasCost': gasCost.toString(),
      'priceImpact': priceImpact,
      'validUntilSeconds': validUntil.inSeconds,
      if (crossChainInfo != null) 'crossChainInfo': crossChainInfo!.toJson(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'SwapQuote(aggregator: $aggregator, '
        'outputAmount: $outputAmount, '
        'priceImpact: ${(priceImpact * 100).toStringAsFixed(2)}%, '
        'gasCost: $gasCost)';
  }
}

/// Comparison result between two quotes
class QuoteComparison {
  const QuoteComparison({
    required this.quote1,
    required this.quote2,
    required this.outputDifference,
    required this.gasDifference,
    required this.priceImpactDifference,
  });
  final SwapQuote quote1;
  final SwapQuote quote2;
  final BigInt outputDifference;
  final BigInt gasDifference;
  final double priceImpactDifference;

  /// Returns true if quote1 is better than quote2
  bool get isQuote1Better => outputDifference > BigInt.zero;

  /// Returns the better quote
  SwapQuote get betterQuote => isQuote1Better ? quote1 : quote2;

  static QuoteComparison compare(SwapQuote quote1, SwapQuote quote2) {
    return QuoteComparison(
      quote1: quote1,
      quote2: quote2,
      outputDifference: quote1.netOutputAmount - quote2.netOutputAmount,
      gasDifference: quote1.gasCost - quote2.gasCost,
      priceImpactDifference: quote1.priceImpact - quote2.priceImpact,
    );
  }
}
