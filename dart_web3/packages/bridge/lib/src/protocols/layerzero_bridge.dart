import 'dart:convert';
import 'package:http/http.dart' as http;

import '../bridge_quote.dart';
import '../bridge_types.dart';
import 'bridge_protocol.dart';

/// LayerZero bridge protocol implementation
class LayerZeroBridge extends BridgeProtocol {

  LayerZeroBridge({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  final BridgeProtocolConfig config;
  final http.Client _httpClient;

  @override
  String get name => 'LayerZero';

  @override
  List<int> get supportedSourceChains => [
    1,     // Ethereum
    56,    // BSC
    137,   // Polygon
    42161, // Arbitrum
    10,    // Optimism
    43114, // Avalanche
    250,   // Fantom
    8453,  // Base
  ];

  @override
  List<int> get supportedDestinationChains => supportedSourceChains;

  String get _baseUrl => config.baseUrl ?? 'https://api.layerzero.network';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (config.apiKey != null) 'Authorization': 'Bearer ${config.apiKey}',
    ...config.headers,
  };

  @override
  bool supportsChainPair(int sourceChainId, int destinationChainId) {
    return supportedSourceChains.contains(sourceChainId) &&
           supportedDestinationChains.contains(destinationChainId) &&
           sourceChainId != destinationChainId;
  }

  @override
  Future<BridgeQuote?> getQuote(BridgeParams params) async {
    if (!validateParams(params)) {
      throw BridgeException(
        protocol: name,
        message: 'Invalid bridge parameters',
      );
    }

    try {
      final url = '$_baseUrl/v1/quote';
      
      final body = {
        'fromChainId': _getLayerZeroChainId(params.sourceChainId),
        'toChainId': _getLayerZeroChainId(params.destinationChainId),
        'fromToken': params.fromToken.address,
        'toToken': params.toToken.address,
        'amount': params.amount.toString(),
        'fromAddress': params.fromAddress,
        'toAddress': params.toAddress,
        'slippage': (params.slippage * 10000).round(), // Basis points
      };

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(config.timeout);

      if (response.statusCode != 200) {
        throw BridgeException(
          protocol: name,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseQuoteResponse(data, params);
    } catch (e) {
      if (e is BridgeException) rethrow;
      throw BridgeException(
        protocol: name,
        message: 'Failed to get quote: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<List<BridgeToken>> getSupportedTokens(
    int sourceChainId,
    int destinationChainId,
  ) async {
    if (!supportsChainPair(sourceChainId, destinationChainId)) {
      throw BridgeException(
        protocol: name,
        message: 'Chain pair not supported: $sourceChainId -> $destinationChainId',
      );
    }

    try {
      final url = '$_baseUrl/v1/tokens';
      final queryParams = {
        'fromChainId': _getLayerZeroChainId(sourceChainId).toString(),
        'toChainId': _getLayerZeroChainId(destinationChainId).toString(),
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await _httpClient.get(uri, headers: _headers)
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw BridgeException(
          protocol: name,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tokens = data['tokens'] as List<dynamic>? ?? [];
      
      return tokens.map((token) {
        final tokenData = token as Map<String, dynamic>;
        return BridgeToken(
          address: tokenData['address'] as String,
          symbol: tokenData['symbol'] as String,
          name: tokenData['name'] as String,
          decimals: tokenData['decimals'] as int,
          chainId: sourceChainId,
          logoUri: tokenData['logoUri'] as String?,
          addressByChain: Map<int, String>.from(
            tokenData['addressByChain'] as Map? ?? {},
          ),
        );
      }).toList();
    } catch (e) {
      if (e is BridgeException) rethrow;
      throw BridgeException(
        protocol: name,
        message: 'Failed to get supported tokens: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isTokenPairSupported(
    BridgeToken sourceToken,
    BridgeToken destinationToken,
    int sourceChainId,
    int destinationChainId,
  ) async {
    try {
      final tokens = await getSupportedTokens(sourceChainId, destinationChainId);
      return tokens.any((token) => 
        token.address.toLowerCase() == sourceToken.address.toLowerCase() &&
        token.getAddressOnChain(destinationChainId)?.toLowerCase() == 
        destinationToken.address.toLowerCase(),
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Future<BridgeLimits> getBridgeLimits(
    BridgeToken token,
    int sourceChainId,
    int destinationChainId,
  ) async {
    try {
      final url = '$_baseUrl/v1/limits';
      final queryParams = {
        'fromChainId': _getLayerZeroChainId(sourceChainId).toString(),
        'toChainId': _getLayerZeroChainId(destinationChainId).toString(),
        'token': token.address,
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await _httpClient.get(uri, headers: _headers)
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw BridgeException(
          protocol: name,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return BridgeLimits.fromJson(data);
    } catch (e) {
      if (e is BridgeException) rethrow;
      // Return default limits if API call fails
      return BridgeLimits(
        minAmount: BigInt.from(1000000), // 0.001 tokens (assuming 18 decimals)
        maxAmount: BigInt.parse('1000000000000000000000000'), // 1M tokens
        dailyLimit: BigInt.parse('10000000000000000000000000'), // 10M tokens
        remainingDailyLimit: BigInt.parse('10000000000000000000000000'),
      );
    }
  }

  @override
  Future<Duration> getEstimatedTime(
    int sourceChainId,
    int destinationChainId,
    BigInt amount,
  ) async {
    // LayerZero typically takes 5-20 minutes depending on the chains
    final baseTime = Duration(minutes: 10);
    
    // Add extra time for high-traffic chains
    final highTrafficChains = [1, 137, 56]; // Ethereum, Polygon, BSC
    if (highTrafficChains.contains(sourceChainId) || 
        highTrafficChains.contains(destinationChainId)) {
      return baseTime + Duration(minutes: 10);
    }
    
    return baseTime;
  }

  @override
  Future<BridgeFeeBreakdown> getFeeBreakdown(BridgeParams params) async {
    try {
      final url = '$_baseUrl/v1/fees';
      
      final body = {
        'fromChainId': _getLayerZeroChainId(params.sourceChainId),
        'toChainId': _getLayerZeroChainId(params.destinationChainId),
        'fromToken': params.fromToken.address,
        'amount': params.amount.toString(),
      };

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return BridgeFeeBreakdown.fromJson(data);
      }
    } catch (e) {
      // Fall back to estimated fees if API call fails
    }

    // Estimate fees based on typical LayerZero costs
    final protocolFee = params.amount * BigInt.from(5) ~/ BigInt.from(10000); // 0.05%
    final gasFee = BigInt.from(50000000000000000); // ~0.05 ETH equivalent
    final relayerFee = BigInt.from(10000000000000000); // ~0.01 ETH equivalent
    final totalFee = protocolFee + gasFee + relayerFee;

    return BridgeFeeBreakdown(
      protocolFee: protocolFee,
      gasFee: gasFee,
      relayerFee: relayerFee,
      liquidityFee: BigInt.zero,
      totalFee: totalFee,
      feeToken: 'ETH',
    );
  }

  BridgeQuote _parseQuoteResponse(Map<String, dynamic> data, BridgeParams params) {
    final outputAmount = BigInt.parse(data['outputAmount'] as String);
    final minimumOutputAmount = calculateMinimumOutput(outputAmount, params.slippage);
    
    // Parse fee breakdown
    final feeData = data['fees'] as Map<String, dynamic>? ?? {};
    final feeBreakdown = BridgeFeeBreakdown(
      protocolFee: BigInt.parse(feeData['protocolFee'] as String? ?? '0'),
      gasFee: BigInt.parse(feeData['gasFee'] as String? ?? '0'),
      relayerFee: BigInt.parse(feeData['relayerFee'] as String? ?? '0'),
      liquidityFee: BigInt.parse(feeData['liquidityFee'] as String? ?? '0'),
      totalFee: BigInt.parse(feeData['totalFee'] as String? ?? '0'),
      feeToken: feeData['feeToken'] as String? ?? 'ETH',
    );

    // Parse route
    final routeData = data['route'] as Map<String, dynamic>? ?? {};
    final route = BridgeRoute(
      protocol: name,
      steps: [
        BridgeStep(
          fromChainId: params.sourceChainId,
          toChainId: params.destinationChainId,
          protocol: name,
          fromToken: params.fromToken,
          toToken: params.toToken,
          inputAmount: params.amount,
          outputAmount: outputAmount,
          fee: feeBreakdown.totalFee,
          estimatedTime: Duration(
            seconds: routeData['estimatedTimeSeconds'] as int? ?? 600,
          ),
        ),
      ],
      estimatedTime: Duration(
        seconds: routeData['estimatedTimeSeconds'] as int? ?? 600,
      ),
      totalFee: feeBreakdown.totalFee,
      confidence: (routeData['confidence'] as num?)?.toDouble() ?? 0.9,
    );

    // Parse limits
    final limitsData = data['limits'] as Map<String, dynamic>? ?? {};
    final limits = BridgeLimits(
      minAmount: BigInt.parse(limitsData['minAmount'] as String? ?? '1000000'),
      maxAmount: BigInt.parse(limitsData['maxAmount'] as String? ?? '1000000000000000000000000'),
      dailyLimit: BigInt.parse(limitsData['dailyLimit'] as String? ?? '10000000000000000000000000'),
      remainingDailyLimit: BigInt.parse(limitsData['remainingDailyLimit'] as String? ?? '10000000000000000000000000'),
    );

    return BridgeQuote(
      protocol: name,
      params: params,
      outputAmount: outputAmount,
      minimumOutputAmount: minimumOutputAmount,
      route: route,
      feeBreakdown: feeBreakdown,
      limits: limits,
      estimatedTime: route.estimatedTime,
      confidence: route.confidence,
      validUntil: const Duration(minutes: 10), // LayerZero quotes valid for 10 minutes
      metadata: {
        'layerZeroData': data,
      },
    );
  }

  int _getLayerZeroChainId(int evmChainId) {
    // Map EVM chain IDs to LayerZero chain IDs
    switch (evmChainId) {
      case 1: return 101;    // Ethereum
      case 56: return 102;   // BSC
      case 137: return 109;  // Polygon
      case 42161: return 110; // Arbitrum
      case 10: return 111;   // Optimism
      case 43114: return 106; // Avalanche
      case 250: return 112;  // Fantom
      case 8453: return 184; // Base
      default:
        throw BridgeException(
          protocol: name,
          message: 'Unsupported chain ID: $evmChainId',
        );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
