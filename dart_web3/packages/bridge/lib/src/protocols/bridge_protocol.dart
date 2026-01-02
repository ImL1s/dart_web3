import '../bridge_quote.dart';
import '../bridge_types.dart';

/// Abstract interface for bridge protocols
abstract class BridgeProtocol {
  /// Name of the bridge protocol
  String get name;

  /// Supported source chain IDs
  List<int> get supportedSourceChains;

  /// Supported destination chain IDs
  List<int> get supportedDestinationChains;

  /// Whether this protocol supports the given chain pair
  bool supportsChainPair(int sourceChainId, int destinationChainId);

  /// Get a bridge quote for the given parameters
  Future<BridgeQuote?> getQuote(BridgeParams params);

  /// Get supported tokens for a chain pair
  Future<List<BridgeToken>> getSupportedTokens(int sourceChainId, int destinationChainId);

  /// Check if a token pair is supported for bridging
  Future<bool> isTokenPairSupported(
    BridgeToken sourceToken,
    BridgeToken destinationToken,
    int sourceChainId,
    int destinationChainId,
  );

  /// Get bridge limits for a specific route
  Future<BridgeLimits> getBridgeLimits(
    BridgeToken token,
    int sourceChainId,
    int destinationChainId,
  );

  /// Get estimated bridge time for a route
  Future<Duration> getEstimatedTime(
    int sourceChainId,
    int destinationChainId,
    BigInt amount,
  );

  /// Get fee breakdown for a bridge operation
  Future<BridgeFeeBreakdown> getFeeBreakdown(BridgeParams params);

  /// Validate bridge parameters
  bool validateParams(BridgeParams params) {
    // Basic validation
    if (params.amount <= BigInt.zero) return false;
    if (params.slippage < 0 || params.slippage > 1) return false;
    if (!supportsChainPair(params.sourceChainId, params.destinationChainId)) {
      return false;
    }
    
    return true;
  }

  /// Calculate minimum output amount based on slippage
  BigInt calculateMinimumOutput(BigInt outputAmount, double slippage) {
    final slippageMultiplier = 1.0 - slippage;
    return BigInt.from(outputAmount.toDouble() * slippageMultiplier);
  }
}

/// Exception thrown when bridge operations fail
class BridgeException implements Exception {

  const BridgeException({
    required this.protocol,
    required this.message,
    this.code,
    this.originalError,
  });
  final String protocol;
  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() {
    return 'BridgeException($protocol): $message'
        '${code != null ? ' (code: $code)' : ''}';
  }
}

/// Bridge protocol configuration
class BridgeProtocolConfig {

  const BridgeProtocolConfig({
    this.apiKey,
    this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.headers = const {},
    this.testMode = false,
  });
  final String? apiKey;
  final String? baseUrl;
  final Duration timeout;
  final Map<String, String> headers;
  final bool testMode;
}

/// Bridge protocol capabilities
class BridgeCapabilities {

  const BridgeCapabilities({
    required this.supportsNativeTokens,
    required this.supportsERC20Tokens,
    required this.supportsNFTs,
    required this.supportsMultiHop,
    required this.supportsInstantFinality,
    required this.supportsRefunds,
    required this.supportedFeatures,
  });
  final bool supportsNativeTokens;
  final bool supportsERC20Tokens;
  final bool supportsNFTs;
  final bool supportsMultiHop;
  final bool supportsInstantFinality;
  final bool supportsRefunds;
  final List<String> supportedFeatures;
}

/// Bridge security information
class BridgeSecurity { // 0.0 (lowest risk) to 1.0 (highest risk)

  const BridgeSecurity({
    required this.securityModel,
    required this.challengePeriod,
    required this.validatorCount,
    required this.totalValueLocked,
    required this.audits,
    required this.riskScore,
  });
  final String securityModel; // 'optimistic', 'zk-proof', 'multi-sig', etc.
  final Duration challengePeriod;
  final int validatorCount;
  final BigInt totalValueLocked;
  final List<String> audits;
  final double riskScore;
}

/// Bridge protocol metadata
class BridgeProtocolMetadata {

  const BridgeProtocolMetadata({
    required this.name,
    required this.description,
    required this.website,
    required this.documentation,
    required this.capabilities,
    required this.security,
    this.additionalInfo,
  });
  final String name;
  final String description;
  final String website;
  final String documentation;
  final BridgeCapabilities capabilities;
  final BridgeSecurity security;
  final Map<String, dynamic>? additionalInfo;
}
