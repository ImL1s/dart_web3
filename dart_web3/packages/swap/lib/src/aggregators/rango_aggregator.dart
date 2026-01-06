import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../swap_quote.dart';
import '../swap_types.dart';
import 'aggregator_interface.dart';

/// Rango Exchange cross-chain DEX aggregator implementation
class RangoAggregator extends DexAggregator {
  RangoAggregator({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  final AggregatorConfig config;
  final http.Client _httpClient;

  @override
  String get name => 'Rango';

  @override
  List<int> get supportedChains => [
        1, // Ethereum
        56, // BSC
        137, // Polygon
        42161, // Arbitrum
        10, // Optimism
        43114, // Avalanche
        250, // Fantom
        25, // Cronos
        1285, // Moonriver
        1284, // Moonbeam
        // Rango supports many more chains including non-EVM
      ];

  @override
  bool get supportsCrossChain => true; // Rango's main feature

  String get _baseUrl => config.baseUrl ?? 'https://api.rango.exchange';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (config.apiKey != null) 'API-KEY': config.apiKey!,
        ...config.headers,
      };

  @override
  Future<SwapQuote?> getQuote(SwapParams params) async {
    if (!validateParams(params)) {
      throw AggregatorException(
        aggregator: name,
        message: 'Invalid swap parameters',
      );
    }

    try {
      // Get routing information first
      final route = await _getRoute(params);
      if (route == null) return null;

      return _buildSwapQuote(route, params);
    } catch (e) {
      if (e is AggregatorException) rethrow;
      throw AggregatorException(
        aggregator: name,
        message: 'Failed to get quote: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<List<SwapQuote>> getQuotes(
    SwapParams params, {
    List<double> slippages = const [0.001, 0.005, 0.01, 0.03],
  }) async {
    final quotes = <SwapQuote>[];

    for (final slippage in slippages) {
      try {
        final quote = await getQuote(params.copyWith(slippage: slippage));
        if (quote != null) {
          quotes.add(quote);
        }
      } on Exception catch (_) {
        // Continue with other slippages if one fails
        continue;
      }
    }

    return quotes;
  }

  @override
  Future<bool> isTokenPairSupported(
    SwapToken fromToken,
    SwapToken toToken,
  ) async {
    if (!supportedChains.contains(fromToken.chainId) ||
        !supportedChains.contains(toToken.chainId)) {
      return false;
    }

    try {
      final tokens = await getSupportedTokens(fromToken.chainId);
      final fromSupported = tokens.any(
        (t) => t.address.toLowerCase() == fromToken.address.toLowerCase(),
      );

      if (fromToken.chainId == toToken.chainId) {
        // Same chain swap
        return fromSupported &&
            tokens.any(
              (t) => t.address.toLowerCase() == toToken.address.toLowerCase(),
            );
      } else {
        // Cross-chain swap - check destination chain tokens
        final destTokens = await getSupportedTokens(toToken.chainId);
        final toSupported = destTokens.any(
          (t) => t.address.toLowerCase() == toToken.address.toLowerCase(),
        );
        return fromSupported && toSupported;
      }
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<List<SwapToken>> getSupportedTokens(int chainId) async {
    if (!supportedChains.contains(chainId)) {
      throw AggregatorException(
        aggregator: name,
        message: 'Chain $chainId not supported',
      );
    }

    try {
      final url = '$_baseUrl/basic/meta';
      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw AggregatorException(
          aggregator: name,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tokens = data['tokens'] as List<dynamic>? ?? [];

      return tokens
          .where(
        (token) =>
            (token as Map<String, dynamic>)['chainId'] == chainId.toString(),
      )
          .map((token) {
        final tokenData = token as Map<String, dynamic>;
        return SwapToken(
          address: tokenData['address'] as String,
          symbol: tokenData['symbol'] as String,
          name: tokenData['name'] as String? ?? tokenData['symbol'] as String,
          decimals: tokenData['decimals'] as int,
          chainId: chainId,
          logoUri: tokenData['image'] as String?,
        );
      }).toList();
    } catch (e) {
      if (e is AggregatorException) rethrow;
      throw AggregatorException(
        aggregator: name,
        message: 'Failed to get supported tokens: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<BigInt> getGasPrice(int chainId) async {
    // Rango doesn't provide gas price endpoint, use defaults
    switch (chainId) {
      case 1: // Ethereum
        return BigInt.from(20000000000); // 20 gwei
      case 137: // Polygon
        return BigInt.from(30000000000); // 30 gwei
      case 56: // BSC
        return BigInt.from(5000000000); // 5 gwei
      default:
        return BigInt.from(20000000000); // 20 gwei default
    }
  }

  Future<Map<String, dynamic>?> _getRoute(SwapParams params) async {
    final url = '$_baseUrl/basic/swap';

    final body = {
      'from': {
        'blockchain': _getBlockchainName(params.fromToken.chainId),
        'symbol': params.fromToken.symbol,
        'address': params.fromToken.address,
      },
      'to': {
        'blockchain': _getBlockchainName(params.toToken.chainId),
        'symbol': params.toToken.symbol,
        'address': params.toToken.address,
      },
      'amount': params.amount.toString(),
      'fromAddress': params.fromAddress,
      'toAddress': params.toAddress ?? params.fromAddress,
      'slippage': params.slippage,
      'disableEstimate': false,
    };

    final response = await _httpClient
        .post(
          Uri.parse(url),
          headers: _headers,
          body: json.encode(body),
        )
        .timeout(config.timeout);

    if (response.statusCode != 200) {
      throw AggregatorException(
        aggregator: name,
        message: 'HTTP ${response.statusCode}: ${response.body}',
        code: response.statusCode.toString(),
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    if (data['error'] != null) {
      throw AggregatorException(
        aggregator: name,
        message: data['error'] as String,
      );
    }

    return data;
  }

  SwapQuote _buildSwapQuote(Map<String, dynamic> routeData, SwapParams params) {
    final route = routeData['route'] as Map<String, dynamic>? ?? {};
    final outputAmount = BigInt.parse(route['outputAmount'] as String? ?? '0');
    final minimumOutputAmount =
        calculateMinimumOutput(outputAmount, params.slippage);

    // Parse route information
    final swapRoute = _parseRoute(route, params);

    // Parse transaction data
    final tx = routeData['tx'] as Map<String, dynamic>? ?? {};
    final transaction = SwapTransaction(
      to: tx['to'] as String? ?? '',
      data: _hexToBytes(tx['data'] as String? ?? '0x'),
      value: BigInt.parse(tx['value'] as String? ?? '0'),
      gasLimit: BigInt.parse(tx['gasLimit'] as String? ?? '300000'),
      gasPrice: BigInt.parse(tx['gasPrice'] as String? ?? '0'),
    );

    final estimatedGas =
        BigInt.parse(route['estimatedGas'] as String? ?? '300000');
    final gasPrice = BigInt.parse(tx['gasPrice'] as String? ?? '0');

    // Check if this is cross-chain
    CrossChainSwapInfo? crossChainInfo;
    if (params.fromToken.chainId != params.toToken.chainId) {
      crossChainInfo = CrossChainSwapInfo(
        sourceChainId: params.fromToken.chainId,
        destinationChainId: params.toToken.chainId,
        bridgeProtocol: route['bridgeUsed'] as String? ?? 'Rango',
        estimatedTime: Duration(
          seconds: (route['estimatedTimeInSeconds'] as num?)?.toInt() ?? 300,
        ),
        bridgeFee: BigInt.parse(route['bridgeFee'] as String? ?? '0'),
      );
    }

    return SwapQuote(
      aggregator: name,
      params: params,
      outputAmount: outputAmount,
      minimumOutputAmount: minimumOutputAmount,
      route: swapRoute,
      transaction: transaction,
      estimatedGas: estimatedGas,
      gasCost: estimatedGas * gasPrice,
      priceImpact: (route['priceImpact'] as num?)?.toDouble() ?? 0.0,
      validUntil:
          const Duration(minutes: 15), // Rango quotes valid for ~15 minutes
      crossChainInfo: crossChainInfo,
      metadata: {
        'route': route,
        'requestId': routeData['requestId'],
      },
    );
  }

  SwapRoute _parseRoute(Map<String, dynamic> route, SwapParams params) {
    final path = <SwapToken>[params.fromToken];
    final exchanges = <String>[];
    final portions = <double>[];

    final swaps = route['swaps'] as List<dynamic>? ?? [];

    for (final swap in swaps) {
      if (swap is Map<String, dynamic>) {
        final swapperName = swap['swapperId'] as String? ?? 'Unknown';
        final swapperType = swap['swapperType'] as String? ?? '';

        exchanges.add('$swapperName ($swapperType)');
        portions.add(1.0 / swaps.length); // Equal portions for simplicity
      }
    }

    path.add(params.toToken);

    return SwapRoute(
      path: path,
      exchanges: exchanges,
      portions: portions,
      gasEstimate: BigInt.parse(route['estimatedGas'] as String? ?? '300000'),
    );
  }

  String _getBlockchainName(int chainId) {
    switch (chainId) {
      case 1:
        return 'ETH';
      case 56:
        return 'BSC';
      case 137:
        return 'POLYGON';
      case 42161:
        return 'ARBITRUM';
      case 10:
        return 'OPTIMISM';
      case 43114:
        return 'AVAX_CCHAIN';
      case 250:
        return 'FANTOM';
      case 25:
        return 'CRONOS';
      case 1285:
        return 'MOONRIVER';
      case 1284:
        return 'MOONBEAM';
      default:
        throw AggregatorException(
          aggregator: name,
          message: 'Unsupported chain ID: $chainId',
        );
    }
  }

  Uint8List _hexToBytes(String hex) {
    var hexStr = hex;
    if (hexStr.startsWith('0x')) {
      hexStr = hexStr.substring(2);
    }
    if (hexStr.isEmpty) return Uint8List(0);

    final bytes = <int>[];
    for (var i = 0; i < hexStr.length; i += 2) {
      final hexByte = hexStr.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  void dispose() {
    _httpClient.close();
  }
}
