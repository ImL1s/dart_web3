import 'dart:math' as math;

import 'swap_quote.dart';
import 'swap_types.dart';

/// Dynamic slippage calculator for swap operations
class SlippageCalculator {
  /// Calculate dynamic slippage based on market conditions
  static double calculateDynamicSlippage({
    required SwapToken fromToken,
    required SwapToken toToken,
    required BigInt amount,
    required List<SwapQuote> quotes,
    double baseSlippage = 0.005, // 0.5% base
    double maxSlippage = 0.05, // 5% max
  }) {
    // Start with base slippage
    var dynamicSlippage = baseSlippage;

    // Adjust based on price impact
    if (quotes.isNotEmpty) {
      final avgPriceImpact =
          quotes.map((q) => q.priceImpact).reduce((a, b) => a + b) /
              quotes.length;

      // Increase slippage for high price impact swaps
      if (avgPriceImpact > 0.01) {
        // 1%
        dynamicSlippage += avgPriceImpact * 0.5;
      }
    }

    // Adjust based on quote variance (market volatility indicator)
    if (quotes.length > 1) {
      final variance = _calculateQuoteVariance(quotes);
      dynamicSlippage += variance * 0.1;
    }

    // Adjust based on swap size (larger swaps need more slippage)
    final sizeMultiplier = _calculateSizeMultiplier(amount, fromToken.decimals);
    dynamicSlippage *= sizeMultiplier;

    // Adjust based on token pair liquidity
    final liquidityMultiplier =
        _estimateLiquidityMultiplier(fromToken, toToken);
    dynamicSlippage *= liquidityMultiplier;

    // Cap at maximum slippage
    return math.min(dynamicSlippage, maxSlippage);
  }

  /// Calculate optimal slippage for a specific quote
  static double calculateOptimalSlippage({
    required SwapQuote quote,
    double confidenceLevel = 0.95, // 95% confidence
  }) {
    // Base slippage from price impact
    var optimalSlippage = quote.priceImpact * 1.5;

    // Add buffer based on confidence level
    final confidenceBuffer = (1.0 - confidenceLevel) * 0.1;
    optimalSlippage += confidenceBuffer;

    // Minimum slippage for any swap
    const minSlippage = 0.001; // 0.1%

    // Maximum reasonable slippage
    const maxSlippage = 0.1; // 10%

    return math.max(minSlippage, math.min(optimalSlippage, maxSlippage));
  }

  /// Get recommended slippage tiers for UI
  static List<SlippageTier> getSlippageTiers({
    required SwapToken fromToken,
    required SwapToken toToken,
    required BigInt amount,
  }) {
    final baseSlippage = _getBaseSlippageForPair(fromToken, toToken);

    return [
      SlippageTier(
        name: 'Low',
        slippage: baseSlippage * 0.5,
        description: 'May fail in volatile conditions',
        recommended: false,
      ),
      SlippageTier(
        name: 'Standard',
        slippage: baseSlippage,
        description: 'Recommended for most swaps',
        recommended: true,
      ),
      SlippageTier(
        name: 'High',
        slippage: baseSlippage * 2.0,
        description: 'Higher chance of success',
        recommended: false,
      ),
      SlippageTier(
        name: 'Custom',
        slippage: baseSlippage,
        description: 'Set your own slippage',
        recommended: false,
      ),
    ];
  }

  /// Calculate slippage impact on output amount
  static SlippageImpact calculateSlippageImpact({
    required BigInt expectedOutput,
    required double slippage,
  }) {
    final minimumOutput =
        (expectedOutput.toDouble() * (1.0 - slippage)).round();
    final potentialLoss = expectedOutput - BigInt.from(minimumOutput);
    final lossPercentage =
        (potentialLoss.toDouble() / expectedOutput.toDouble()) * 100;

    return SlippageImpact(
      expectedOutput: expectedOutput,
      minimumOutput: BigInt.from(minimumOutput),
      potentialLoss: potentialLoss,
      lossPercentage: lossPercentage,
      slippage: slippage,
    );
  }

  /// Validate slippage value
  static bool isValidSlippage(double slippage) {
    return slippage >= 0.0001 && slippage <= 0.5; // 0.01% to 50%
  }

  /// Get slippage warning level
  static SlippageWarningLevel getWarningLevel(double slippage) {
    if (slippage < 0.001) {
      return SlippageWarningLevel.tooLow;
    } else if (slippage <= 0.005) {
      return SlippageWarningLevel.none;
    } else if (slippage <= 0.02) {
      return SlippageWarningLevel.medium;
    } else if (slippage <= 0.05) {
      return SlippageWarningLevel.high;
    } else {
      return SlippageWarningLevel.extreme;
    }
  }

  /// Calculate variance in quote outputs (volatility indicator)
  static double _calculateQuoteVariance(List<SwapQuote> quotes) {
    if (quotes.length < 2) return 0;

    final outputs = quotes.map((q) => q.outputAmount.toDouble()).toList();
    final mean = outputs.reduce((a, b) => a + b) / outputs.length;

    final variance = outputs
            .map((output) => math.pow(output - mean, 2))
            .reduce((a, b) => a + b) /
        outputs.length;

    final standardDeviation = math.sqrt(variance);
    return standardDeviation / mean; // Coefficient of variation
  }

  /// Calculate size multiplier based on swap amount
  static double _calculateSizeMultiplier(BigInt amount, int decimals) {
    final normalizedAmount = amount.toDouble() / math.pow(10, decimals);

    // Larger swaps need more slippage tolerance
    if (normalizedAmount > 100000) {
      return 2; // Very large swap
    } else if (normalizedAmount > 10000) {
      return 1.5; // Large swap
    } else if (normalizedAmount > 1000) {
      return 1.2; // Medium swap
    } else {
      return 1; // Small swap
    }
  }

  /// Estimate liquidity multiplier for token pair
  static double _estimateLiquidityMultiplier(
      SwapToken fromToken, SwapToken toToken) {
    // This is a simplified heuristic - in practice you'd use on-chain liquidity data

    final majorTokens = [
      'ETH',
      'WETH',
      'USDC',
      'USDT',
      'DAI',
      'WBTC',
      'BTC',
    ];

    final fromMajor = majorTokens.contains(fromToken.symbol.toUpperCase());
    final toMajor = majorTokens.contains(toToken.symbol.toUpperCase());

    if (fromMajor && toMajor) {
      return 1; // High liquidity pair
    } else if (fromMajor || toMajor) {
      return 1.3; // Medium liquidity pair
    } else {
      return 1.8; // Low liquidity pair
    }
  }

  /// Get base slippage for a token pair
  static double _getBaseSlippageForPair(
      SwapToken fromToken, SwapToken toToken) {
    // Stablecoin pairs have lower slippage
    final stablecoins = ['USDC', 'USDT', 'DAI', 'BUSD', 'FRAX'];
    final fromStable = stablecoins.contains(fromToken.symbol.toUpperCase());
    final toStable = stablecoins.contains(toToken.symbol.toUpperCase());

    if (fromStable && toStable) {
      return 0.001; // 0.1% for stablecoin pairs
    } else if (fromStable || toStable) {
      return 0.003; // 0.3% for one stablecoin
    } else {
      return 0.005; // 0.5% for volatile pairs
    }
  }
}

/// Slippage tier for UI selection
class SlippageTier {
  const SlippageTier({
    required this.name,
    required this.slippage,
    required this.description,
    required this.recommended,
  });
  final String name;
  final double slippage;
  final String description;
  final bool recommended;

  /// Get slippage as percentage string
  String get slippagePercentage => '${(slippage * 100).toStringAsFixed(2)}%';
}

/// Slippage impact calculation result
class SlippageImpact {
  const SlippageImpact({
    required this.expectedOutput,
    required this.minimumOutput,
    required this.potentialLoss,
    required this.lossPercentage,
    required this.slippage,
  });
  final BigInt expectedOutput;
  final BigInt minimumOutput;
  final BigInt potentialLoss;
  final double lossPercentage;
  final double slippage;

  /// Get formatted loss percentage
  String get formattedLossPercentage => '${lossPercentage.toStringAsFixed(3)}%';

  /// Get formatted slippage percentage
  String get formattedSlippage => '${(slippage * 100).toStringAsFixed(2)}%';
}

/// Slippage warning levels
enum SlippageWarningLevel {
  none,
  tooLow,
  medium,
  high,
  extreme,
}

/// Extension to get warning messages
extension SlippageWarningLevelExtension on SlippageWarningLevel {
  String get message {
    switch (this) {
      case SlippageWarningLevel.none:
        return '';
      case SlippageWarningLevel.tooLow:
        return 'Slippage too low - transaction may fail';
      case SlippageWarningLevel.medium:
        return 'Medium slippage - monitor for front-running';
      case SlippageWarningLevel.high:
        return 'High slippage - significant price impact possible';
      case SlippageWarningLevel.extreme:
        return 'Extreme slippage - high risk of value loss';
    }
  }

  bool get isWarning => this != SlippageWarningLevel.none;
}
