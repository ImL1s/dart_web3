import 'bridge_types.dart';

/// Bridge quote from a protocol
class BridgeQuote {
  BridgeQuote({
    required this.protocol,
    required this.params,
    required this.outputAmount,
    required this.minimumOutputAmount,
    required this.route,
    required this.feeBreakdown,
    required this.limits,
    required this.estimatedTime,
    required this.confidence,
    required this.validUntil,
    this.metadata,
  });

  factory BridgeQuote.fromJson(Map<String, dynamic> json) {
    return BridgeQuote(
      protocol: json['protocol'] as String,
      params: BridgeParams(
        fromToken:
            BridgeToken.fromJson(json['fromToken'] as Map<String, dynamic>),
        toToken: BridgeToken.fromJson(json['toToken'] as Map<String, dynamic>),
        sourceChainId: json['sourceChainId'] as int,
        destinationChainId: json['destinationChainId'] as int,
        amount: BigInt.parse(json['amount'] as String),
        fromAddress: json['fromAddress'] as String,
        toAddress: json['toAddress'] as String,
        slippage: (json['slippage'] as num).toDouble(),
      ),
      outputAmount: BigInt.parse(json['outputAmount'] as String),
      minimumOutputAmount: BigInt.parse(json['minimumOutputAmount'] as String),
      route: BridgeRoute.fromJson(json['route'] as Map<String, dynamic>),
      feeBreakdown: BridgeFeeBreakdown.fromJson(
          json['feeBreakdown'] as Map<String, dynamic>),
      limits: BridgeLimits.fromJson(json['limits'] as Map<String, dynamic>),
      estimatedTime: Duration(seconds: json['estimatedTimeSeconds'] as int),
      confidence: (json['confidence'] as num).toDouble(),
      validUntil: Duration(seconds: json['validUntilSeconds'] as int),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String protocol;
  final BridgeParams params;
  final BigInt outputAmount;
  final BigInt minimumOutputAmount;
  final BridgeRoute route;
  final BridgeFeeBreakdown feeBreakdown;
  final BridgeLimits limits;
  final Duration estimatedTime;
  final double confidence;
  final Duration validUntil;
  final Map<String, dynamic>? metadata;

  /// Calculate the effective exchange rate
  double get exchangeRate {
    if (outputAmount == BigInt.zero) return 0;
    return outputAmount.toDouble() / params.amount.toDouble();
  }

  /// Calculate net output amount after all fees
  BigInt get netOutputAmount => outputAmount - feeBreakdown.totalFee;

  /// Get fee as percentage of input amount
  double get feePercentage => feeBreakdown.getFeePercentage(params.amount);

  /// Check if the quote is still valid
  bool get isValid => DateTime.now().isBefore(DateTime.now().add(validUntil));

  /// Check if the amount is within bridge limits
  bool get isAmountValid => limits.isAmountValid(params.amount);

  /// Get estimated time in human-readable format
  String get estimatedTimeFormatted {
    final minutes = estimatedTime.inMinutes;
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = estimatedTime.inHours;
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0
          ? '${hours}h ${remainingMinutes}m'
          : '${hours}h';
    }
  }

  /// Get confidence level description
  String get confidenceDescription {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.6) return 'Low';
    return 'Very Low';
  }

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'fromToken': params.fromToken.toJson(),
      'toToken': params.toToken.toJson(),
      'sourceChainId': params.sourceChainId,
      'destinationChainId': params.destinationChainId,
      'amount': params.amount.toString(),
      'fromAddress': params.fromAddress,
      'toAddress': params.toAddress,
      'slippage': params.slippage,
      'outputAmount': outputAmount.toString(),
      'minimumOutputAmount': minimumOutputAmount.toString(),
      'route': route.toJson(),
      'feeBreakdown': feeBreakdown.toJson(),
      'limits': limits.toJson(),
      'estimatedTimeSeconds': estimatedTime.inSeconds,
      'confidence': confidence,
      'validUntilSeconds': validUntil.inSeconds,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'BridgeQuote(protocol: $protocol, '
        'outputAmount: $outputAmount, '
        'fee: ${feePercentage.toStringAsFixed(2)}%, '
        'time: $estimatedTimeFormatted, '
        'confidence: $confidenceDescription)';
  }
}

/// Comparison result between two bridge quotes
class BridgeQuoteComparison {
  const BridgeQuoteComparison({
    required this.quote1,
    required this.quote2,
    required this.outputDifference,
    required this.feeDifference,
    required this.timeDifference,
    required this.confidenceDifference,
  });
  final BridgeQuote quote1;
  final BridgeQuote quote2;
  final BigInt outputDifference;
  final BigInt feeDifference;
  final Duration timeDifference;
  final double confidenceDifference;

  /// Returns true if quote1 is better than quote2 overall
  bool get isQuote1Better {
    // Simple scoring system - can be made more sophisticated
    var score1 = 0;
    var score2 = 0;

    // Higher output is better
    if (outputDifference > BigInt.zero) {
      score1 += 3;
    } else if (outputDifference < BigInt.zero) {
      score2 += 3;
    }

    // Lower fees are better
    if (feeDifference < BigInt.zero) {
      score1 += 2;
    } else if (feeDifference > BigInt.zero) {
      score2 += 2;
    }

    // Faster is better (but less important than cost)
    if (timeDifference.isNegative) {
      score1 += 1;
    } else if (timeDifference > Duration.zero) {
      score2 += 1;
    }

    // Higher confidence is better
    if (confidenceDifference > 0) {
      score1 += 1;
    } else if (confidenceDifference < 0) {
      score2 += 1;
    }

    return score1 > score2;
  }

  /// Returns the better quote
  BridgeQuote get betterQuote => isQuote1Better ? quote1 : quote2;

  static BridgeQuoteComparison compare(BridgeQuote quote1, BridgeQuote quote2) {
    return BridgeQuoteComparison(
      quote1: quote1,
      quote2: quote2,
      outputDifference: quote1.netOutputAmount - quote2.netOutputAmount,
      feeDifference:
          quote1.feeBreakdown.totalFee - quote2.feeBreakdown.totalFee,
      timeDifference: quote1.estimatedTime - quote2.estimatedTime,
      confidenceDifference: quote1.confidence - quote2.confidence,
    );
  }
}

/// Bridge quote aggregation result
class BridgeQuoteAggregation {
  const BridgeQuoteAggregation({
    required this.quotes,
    this.bestQuote,
    this.fastestQuote,
    this.cheapestQuote,
    this.mostReliableQuote,
  });

  /// Create aggregation from a list of quotes
  factory BridgeQuoteAggregation.fromQuotes(List<BridgeQuote> quotes) {
    if (quotes.isEmpty) {
      return const BridgeQuoteAggregation(quotes: []);
    }

    // Sort quotes by different criteria
    final sortedByOutput = List<BridgeQuote>.from(quotes)
      ..sort((a, b) => b.netOutputAmount.compareTo(a.netOutputAmount));

    final sortedByTime = List<BridgeQuote>.from(quotes)
      ..sort((a, b) => a.estimatedTime.compareTo(b.estimatedTime));

    final sortedByFee = List<BridgeQuote>.from(quotes)
      ..sort(
          (a, b) => a.feeBreakdown.totalFee.compareTo(b.feeBreakdown.totalFee));

    final sortedByConfidence = List<BridgeQuote>.from(quotes)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return BridgeQuoteAggregation(
      quotes: quotes,
      bestQuote: sortedByOutput.first, // Best overall (highest net output)
      fastestQuote: sortedByTime.first,
      cheapestQuote: sortedByFee.first,
      mostReliableQuote: sortedByConfidence.first,
    );
  }
  final List<BridgeQuote> quotes;
  final BridgeQuote? bestQuote;
  final BridgeQuote? fastestQuote;
  final BridgeQuote? cheapestQuote;
  final BridgeQuote? mostReliableQuote;

  /// Get quotes filtered by criteria
  List<BridgeQuote> getQuotesFiltered({
    Duration? maxTime,
    BigInt? maxFee,
    double? minConfidence,
  }) {
    return quotes.where((quote) {
      if (maxTime != null && quote.estimatedTime > maxTime) return false;
      if (maxFee != null && quote.feeBreakdown.totalFee > maxFee) return false;
      if (minConfidence != null && quote.confidence < minConfidence) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get average metrics across all quotes
  BridgeMetrics get averageMetrics {
    if (quotes.isEmpty) {
      return BridgeMetrics(
        averageTime: Duration.zero,
        averageFee: BigInt.zero,
        averageConfidence: 0,
        averageOutput: BigInt.zero,
      );
    }

    final totalTime = quotes.fold<int>(
      0,
      (sum, quote) => sum + quote.estimatedTime.inSeconds,
    );

    final totalFee = quotes.fold<BigInt>(
      BigInt.zero,
      (sum, quote) => sum + quote.feeBreakdown.totalFee,
    );

    final totalConfidence = quotes.fold<double>(
      0,
      (sum, quote) => sum + quote.confidence,
    );

    final totalOutput = quotes.fold<BigInt>(
      BigInt.zero,
      (sum, quote) => sum + quote.netOutputAmount,
    );

    return BridgeMetrics(
      averageTime: Duration(seconds: totalTime ~/ quotes.length),
      averageFee: totalFee ~/ BigInt.from(quotes.length),
      averageConfidence: totalConfidence / quotes.length,
      averageOutput: totalOutput ~/ BigInt.from(quotes.length),
    );
  }
}

/// Average metrics for bridge quotes
class BridgeMetrics {
  BridgeMetrics({
    required this.averageTime,
    required this.averageFee,
    required this.averageConfidence,
    required this.averageOutput,
  });
  final Duration averageTime;
  final BigInt averageFee;
  final double averageConfidence;
  final BigInt averageOutput;
}
