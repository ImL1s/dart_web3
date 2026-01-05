import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../swap_quote.dart';
import '../swap_types.dart';
import 'aggregator_interface.dart';

/// ParaSwap DEX aggregator implementation
class ParaSwapAggregator extends DexAggregator {
  ParaSwapAggregator({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  final AggregatorConfig config;
  final http.Client _httpClient;

  @override
  String get name => 'ParaSwap';

  @override
  List<int> get supportedChains => [
        1, // Ethereum
        56, // BSC
        137, // Polygon
        42161, // Arbitrum
        10, // Optimism
        43114, // Avalanche
        250, // Fantom
      ];

  @override
  bool get supportsCrossChain => false;

  String get _baseUrl => config.baseUrl ?? 'https://apiv5.paraswap.io';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (config.apiKey != null) 'X-API-KEY': config.apiKey!,
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
      // First get price quote
      final priceRoute = await _getPriceRoute(params);
      if (priceRoute == null) return null;

      // Then get transaction data
      final transaction = await _getTransaction(priceRoute, params);
      if (transaction == null) return null;

      return await _buildSwapQuote(priceRoute, transaction, params);
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
    if (fromToken.chainId != toToken.chainId) return false;
    if (!supportedChains.contains(fromToken.chainId)) return false;

    try {
      final tokens = await getSupportedTokens(fromToken.chainId);
      final fromSupported = tokens.any(
        (t) => t.address.toLowerCase() == fromToken.address.toLowerCase(),
      );
      final toSupported = tokens
          .any((t) => t.address.toLowerCase() == toToken.address.toLowerCase());
      return fromSupported && toSupported;
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
      final url = '$_baseUrl/tokens/$chainId';
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
      final tokens = data['tokens'] as List<dynamic>;

      return tokens.map((token) {
        final tokenData = token as Map<String, dynamic>;
        return SwapToken(
          address: tokenData['address'] as String,
          symbol: tokenData['symbol'] as String,
          name: tokenData['name'] as String? ?? tokenData['symbol'] as String,
          decimals: tokenData['decimals'] as int,
          chainId: chainId,
          logoUri: tokenData['img'] as String?,
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
    // ParaSwap doesn't provide gas price endpoint, use defaults
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

  Future<Map<String, dynamic>?> _getPriceRoute(SwapParams params) async {
    final chainId = params.fromToken.chainId;
    final url = '$_baseUrl/prices';

    final queryParams = {
      'srcToken': params.fromToken.address,
      'destToken': params.toToken.address,
      'amount': params.amount.toString(),
      'srcDecimals': params.fromToken.decimals.toString(),
      'destDecimals': params.toToken.decimals.toString(),
      'network': chainId.toString(),
      'side': 'SELL',
      'excludeDEXS': '', // Can be used to exclude specific DEXs
    };

    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    final response =
        await _httpClient.get(uri, headers: _headers).timeout(config.timeout);

    if (response.statusCode != 200) {
      throw AggregatorException(
        aggregator: name,
        message: 'HTTP ${response.statusCode}: ${response.body}',
        code: response.statusCode.toString(),
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['priceRoute'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> _getTransaction(
    Map<String, dynamic> priceRoute,
    SwapParams params,
  ) async {
    final url = '$_baseUrl/transactions/${params.fromToken.chainId}';

    final body = {
      'srcToken': params.fromToken.address,
      'destToken': params.toToken.address,
      'srcAmount': params.amount.toString(),
      'destAmount': priceRoute['destAmount'] as String,
      'priceRoute': priceRoute,
      'userAddress': params.fromAddress,
      'slippage':
          (params.slippage * 10000).round(), // ParaSwap uses basis points
      'deadline': params.deadline?.inSeconds ??
          (DateTime.now()
                  .add(const Duration(minutes: 20))
                  .millisecondsSinceEpoch ~/
              1000),
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

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<SwapQuote> _buildSwapQuote(
    Map<String, dynamic> priceRoute,
    Map<String, dynamic> transactionData,
    SwapParams params,
  ) async {
    final outputAmount = BigInt.parse(priceRoute['destAmount'] as String);
    final minimumOutputAmount =
        calculateMinimumOutput(outputAmount, params.slippage);

    // Parse route information
    final route = _parseRoute(priceRoute, params);

    // Parse transaction data
    final transaction = SwapTransaction(
      to: transactionData['to'] as String,
      data: _hexToBytes(transactionData['data'] as String),
      value: BigInt.parse(transactionData['value'] as String),
      gasLimit: BigInt.parse(transactionData['gasLimit'] as String),
      gasPrice: BigInt.parse(transactionData['gasPrice'] as String? ?? '0'),
    );

    final estimatedGas =
        BigInt.parse(priceRoute['gasCost'] as String? ?? '200000');
    final gasPrice = await getGasPrice(params.fromToken.chainId);

    return SwapQuote(
      aggregator: name,
      params: params,
      outputAmount: outputAmount,
      minimumOutputAmount: minimumOutputAmount,
      route: route,
      transaction: transaction,
      estimatedGas: estimatedGas,
      gasCost: estimatedGas * gasPrice,
      priceImpact: (priceRoute['priceImpact'] as num?)?.toDouble() ?? 0.0,
      validUntil:
          const Duration(minutes: 10), // ParaSwap quotes valid for ~10 minutes
      metadata: {
        'priceRoute': priceRoute,
        'bestRoute': priceRoute['bestRoute'],
      },
    );
  }

  SwapRoute _parseRoute(Map<String, dynamic> priceRoute, SwapParams params) {
    final path = <SwapToken>[params.fromToken];
    final exchanges = <String>[];
    final portions = <double>[];

    final bestRoute = priceRoute['bestRoute'] as List<dynamic>? ?? [];

    for (final route in bestRoute) {
      if (route is Map<String, dynamic>) {
        final swaps = route['swaps'] as List<dynamic>? ?? [];

        for (final swap in swaps) {
          if (swap is Map<String, dynamic>) {
            final swapExchanges = swap['swapExchanges'] as List<dynamic>? ?? [];

            for (final exchange in swapExchanges) {
              if (exchange is Map<String, dynamic>) {
                final exchangeName =
                    exchange['exchange'] as String? ?? 'Unknown';
                final percent =
                    (exchange['percent'] as num?)?.toDouble() ?? 0.0;

                exchanges.add(exchangeName);
                portions.add(percent / 100.0);
              }
            }
          }
        }
      }
    }

    path.add(params.toToken);

    return SwapRoute(
      path: path,
      exchanges: exchanges,
      portions: portions,
      gasEstimate: BigInt.parse(priceRoute['gasCost'] as String? ?? '200000'),
    );
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
