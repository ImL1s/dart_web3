import 'dart:convert';
import 'package:http/http.dart' as http;

import '../bridge_quote.dart';
import '../bridge_types.dart';
import 'bridge_protocol.dart';

/// Stargate Finance bridge protocol implementation
class StargateBridge extends BridgeProtocol {
  StargateBridge({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  final BridgeProtocolConfig config;
  final http.Client _httpClient;

  @override
  String get name => 'Stargate';

  @override
  List<int> get supportedSourceChains => [
        1, // Ethereum
        56, // BSC
        137, // Polygon
        42161, // Arbitrum
        10, // Optimism
        43114, // Avalanche
        250, // Fantom
        8453, // Base
      ];

  @override
  List<int> get supportedDestinationChains => supportedSourceChains;

  String get _baseUrl => config.baseUrl ?? 'https://api.stargate.finance';

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
        'srcChainId': _getStargateChainId(params.sourceChainId),
        'dstChainId': _getStargateChainId(params.destinationChainId),
        'srcPoolId': await _getPoolId(params.fromToken, params.sourceChainId),
        'dstPoolId':
            await _getPoolId(params.toToken, params.destinationChainId),
        'amountLD': params.amount.toString(),
        'to': params.toAddress,
        'slippage': (params.slippage * 10000).round(), // Basis points
      };

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(config.timeout);

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
        message:
            'Chain pair not supported: $sourceChainId -> $destinationChainId',
      );
    }

    try {
      final url = '$_baseUrl/v1/pools';
      final queryParams = {
        'chainId': _getStargateChainId(sourceChainId).toString(),
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response =
          await _httpClient.get(uri, headers: _headers).timeout(config.timeout);

      if (response.statusCode != 200) {
        throw BridgeException(
          protocol: name,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final pools = data['pools'] as List<dynamic>? ?? [];

      return pools.map((pool) {
        final poolData = pool as Map<String, dynamic>;
        final tokenData = poolData['token'] as Map<String, dynamic>;

        return BridgeToken(
          address: tokenData['address'] as String,
          symbol: tokenData['symbol'] as String,
          name: tokenData['name'] as String,
          decimals: tokenData['decimals'] as int,
          chainId: sourceChainId,
          logoUri: tokenData['logoUri'] as String?,
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
      // Stargate supports stable assets (USDC, USDT, etc.) and ETH
      final supportedSymbols = [
        'USDC',
        'USDT',
        'BUSD',
        'DAI',
        'FRAX',
        'ETH',
        'WETH'
      ];

      return supportedSymbols.contains(sourceToken.symbol.toUpperCase()) &&
          supportedSymbols.contains(destinationToken.symbol.toUpperCase()) &&
          sourceToken.symbol.toUpperCase() ==
              destinationToken.symbol.toUpperCase();
    } on Exception catch (_) {
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
      final url = '$_baseUrl/v1/pool/limits';
      final queryParams = {
        'srcChainId': _getStargateChainId(sourceChainId).toString(),
        'dstChainId': _getStargateChainId(destinationChainId).toString(),
        'srcPoolId': (await _getPoolId(token, sourceChainId)).toString(),
        'dstPoolId': (await _getPoolId(token, destinationChainId)).toString(),
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response =
          await _httpClient.get(uri, headers: _headers).timeout(config.timeout);

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
        minAmount: BigInt.from(1000000), // 1 USDC (6 decimals)
        maxAmount: BigInt.parse('10000000000'), // 10,000 USDC
        dailyLimit: BigInt.parse('100000000000'), // 100,000 USDC
        remainingDailyLimit: BigInt.parse('100000000000'),
      );
    }
  }

  @override
  Future<Duration> getEstimatedTime(
    int sourceChainId,
    int destinationChainId,
    BigInt amount,
  ) async {
    // Stargate is typically faster than other bridges (5-15 minutes)
    // because it uses LayerZero for messaging
    return const Duration(minutes: 8);
  }

  @override
  Future<BridgeFeeBreakdown> getFeeBreakdown(BridgeParams params) async {
    try {
      final url = '$_baseUrl/v1/fees';

      final body = {
        'srcChainId': _getStargateChainId(params.sourceChainId),
        'dstChainId': _getStargateChainId(params.destinationChainId),
        'srcPoolId': await _getPoolId(params.fromToken, params.sourceChainId),
        'dstPoolId':
            await _getPoolId(params.toToken, params.destinationChainId),
        'amountLD': params.amount.toString(),
      };

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return BridgeFeeBreakdown.fromJson(data);
      }
    } on Exception catch (_) {
      // Fall back to estimated fees if API call fails
    }

    // Estimate fees based on typical Stargate costs
    final protocolFee =
        params.amount * BigInt.from(6) ~/ BigInt.from(10000); // 0.06%
    final gasFee = BigInt.from(30000000000000000); // ~0.03 ETH equivalent
    final liquidityFee =
        params.amount * BigInt.from(1) ~/ BigInt.from(10000); // 0.01%
    final totalFee = protocolFee + gasFee + liquidityFee;

    return BridgeFeeBreakdown(
      protocolFee: protocolFee,
      gasFee: gasFee,
      relayerFee: BigInt.zero,
      liquidityFee: liquidityFee,
      totalFee: totalFee,
      feeToken: params.fromToken.symbol,
    );
  }

  Future<int> _getPoolId(BridgeToken token, int chainId) async {
    // Simplified pool ID mapping - in practice this would be fetched from API
    final symbol = token.symbol.toUpperCase();

    switch (symbol) {
      case 'USDC':
        return 1;
      case 'USDT':
        return 2;
      case 'DAI':
        return 3;
      case 'FRAX':
        return 7;
      case 'ETH':
      case 'WETH':
        return 13;
      default:
        throw BridgeException(
          protocol: name,
          message: 'Unsupported token: ${token.symbol}',
        );
    }
  }

  BridgeQuote _parseQuoteResponse(
      Map<String, dynamic> data, BridgeParams params) {
    final outputAmount = BigInt.parse(data['amountReceivedLD'] as String);
    final minimumOutputAmount =
        calculateMinimumOutput(outputAmount, params.slippage);

    // Parse fee breakdown
    final feeData = data['fees'] as Map<String, dynamic>? ?? {};
    final protocolFee =
        BigInt.parse(feeData['protocolFeeLD'] as String? ?? '0');
    final liquidityFee =
        BigInt.parse(feeData['liquidityFeeLD'] as String? ?? '0');
    final gasFee = BigInt.parse(feeData['gasFee'] as String? ?? '0');

    final feeBreakdown = BridgeFeeBreakdown(
      protocolFee: protocolFee,
      gasFee: gasFee,
      relayerFee: BigInt.zero,
      liquidityFee: liquidityFee,
      totalFee: protocolFee + liquidityFee + gasFee,
      feeToken: params.fromToken.symbol,
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
            seconds: routeData['estimatedTimeSeconds'] as int? ?? 480,
          ),
        ),
      ],
      estimatedTime: Duration(
        seconds: routeData['estimatedTimeSeconds'] as int? ?? 480,
      ),
      totalFee: feeBreakdown.totalFee,
      confidence: (routeData['confidence'] as num?)?.toDouble() ?? 0.92,
    );

    // Parse limits
    final limitsData = data['limits'] as Map<String, dynamic>? ?? {};
    final limits = BridgeLimits(
      minAmount:
          BigInt.parse(limitsData['minAmountLD'] as String? ?? '1000000'),
      maxAmount:
          BigInt.parse(limitsData['maxAmountLD'] as String? ?? '10000000000'),
      dailyLimit:
          BigInt.parse(limitsData['dailyLimitLD'] as String? ?? '100000000000'),
      remainingDailyLimit: BigInt.parse(
          limitsData['remainingDailyLimitLD'] as String? ?? '100000000000'),
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
      validUntil:
          const Duration(minutes: 5), // Stargate quotes valid for 5 minutes
      metadata: {
        'stargateData': data,
        'poolIds': {
          'source': data['srcPoolId'],
          'destination': data['dstPoolId'],
        },
      },
    );
  }

  int _getStargateChainId(int evmChainId) {
    // Map EVM chain IDs to Stargate chain IDs (same as LayerZero)
    switch (evmChainId) {
      case 1:
        return 101; // Ethereum
      case 56:
        return 102; // BSC
      case 137:
        return 109; // Polygon
      case 42161:
        return 110; // Arbitrum
      case 10:
        return 111; // Optimism
      case 43114:
        return 106; // Avalanche
      case 250:
        return 112; // Fantom
      case 8453:
        return 184; // Base
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
