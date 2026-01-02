import '../swap_quote.dart';
import '../swap_types.dart';

/// Abstract interface for DEX aggregators
abstract class DexAggregator {
  /// Name of the aggregator
  String get name;

  /// Supported chain IDs
  List<int> get supportedChains;

  /// Whether this aggregator supports cross-chain swaps
  bool get supportsCrossChain;

  /// Get a swap quote for the given parameters
  Future<SwapQuote?> getQuote(SwapParams params);

  /// Get multiple quotes with different slippage tolerances
  Future<List<SwapQuote>> getQuotes(
    SwapParams params, {
    List<double> slippages = const [0.001, 0.005, 0.01, 0.03],
  });

  /// Check if a token pair is supported
  Future<bool> isTokenPairSupported(SwapToken fromToken, SwapToken toToken);

  /// Get supported tokens for a chain
  Future<List<SwapToken>> getSupportedTokens(int chainId);

  /// Get the current gas price estimate
  Future<BigInt> getGasPrice(int chainId);

  /// Validate swap parameters
  bool validateParams(SwapParams params) {
    // Basic validation
    if (params.amount <= BigInt.zero) return false;
    if (params.slippage < 0 || params.slippage > 1) return false;
    if (params.fromToken.chainId != params.toToken.chainId && !supportsCrossChain) {
      return false;
    }
    if (!supportedChains.contains(params.fromToken.chainId)) return false;
    
    return true;
  }

  /// Calculate minimum output amount based on slippage
  BigInt calculateMinimumOutput(BigInt outputAmount, double slippage) {
    final slippageMultiplier = 1.0 - slippage;
    return BigInt.from(outputAmount.toDouble() * slippageMultiplier);
  }
}

/// Exception thrown when aggregator operations fail
class AggregatorException implements Exception {

  const AggregatorException({
    required this.aggregator,
    required this.message,
    this.code,
    this.originalError,
  });
  final String aggregator;
  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() {
    return 'AggregatorException($aggregator): $message'
        '${code != null ? ' (code: $code)' : ''}';
  }
}

/// Rate limiting information for aggregators
class RateLimit {

  const RateLimit({
    required this.requestsPerMinute,
    required this.requestsPerHour,
    required this.resetTime,
  });
  final int requestsPerMinute;
  final int requestsPerHour;
  final Duration resetTime;
}

/// Aggregator configuration
class AggregatorConfig {

  const AggregatorConfig({
    this.apiKey,
    this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.rateLimit,
    this.headers = const {},
  });
  final String? apiKey;
  final String? baseUrl;
  final Duration timeout;
  final RateLimit? rateLimit;
  final Map<String, String> headers;
}
