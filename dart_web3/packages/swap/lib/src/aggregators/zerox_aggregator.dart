import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../swap_quote.dart';
import '../swap_types.dart';
import 'aggregator_interface.dart';

/// 0x Protocol DEX aggregator implementation
class ZeroXAggregator extends DexAggregator {
  ZeroXAggregator({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  final AggregatorConfig config;
  final http.Client _httpClient;

  @override
  String get name => '0x';

  @override
  List<int> get supportedChains => [
        1, // Ethereum
        56, // BSC
        137, // Polygon
        42161, // Arbitrum
        10, // Optimism
        43114, // Avalanche
        8453, // Base
      ];

  @override
  bool get supportsCrossChain => false;

  String get _baseUrl => config.baseUrl ?? 'https://api.0x.org';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (config.apiKey != null) '0x-api-key': config.apiKey!,
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
      final chainId = params.fromToken.chainId;
      final networkPath = _getNetworkPath(chainId);
      final url = '$_baseUrl$networkPath/swap/v1/quote';

      final queryParams = {
        'sellToken': params.fromToken.address,
        'buyToken': params.toToken.address,
        'sellAmount': params.amount.toString(),
        'takerAddress': params.fromAddress,
        'slippagePercentage': params.slippage.toString(),
        'skipValidation': 'false',
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
      return _parseQuoteResponse(data, params);
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
      SwapToken fromToken, SwapToken toToken) async {
    if (fromToken.chainId != toToken.chainId) return false;
    if (!supportedChains.contains(fromToken.chainId)) return false;

    try {
      // 0x supports most ERC-20 tokens, so we'll do a basic check
      final networkPath = _getNetworkPath(fromToken.chainId);
      final url = '$_baseUrl$networkPath/swap/v1/sources';

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(config.timeout);

      return response.statusCode == 200;
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
      final networkPath = _getNetworkPath(chainId);
      final url = '$_baseUrl$networkPath/swap/v1/tokens';

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
      final records = data['records'] as List<dynamic>? ?? [];

      return records.map((record) {
        final tokenData = record as Map<String, dynamic>;
        return SwapToken(
          address: tokenData['address'] as String,
          symbol: tokenData['symbol'] as String,
          name: tokenData['name'] as String,
          decimals: tokenData['decimals'] as int,
          chainId: chainId,
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
    try {
      final networkPath = _getNetworkPath(chainId);
      final url = '$_baseUrl$networkPath/gas/price';

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return BigInt.parse(data['gasPrice'] as String);
      }
    } on Exception catch (_) {
      // Fall back to default if gas price endpoint fails
    }

    // Default gas prices by chain
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

  String _getNetworkPath(int chainId) {
    switch (chainId) {
      case 1:
        return ''; // Mainnet is the default
      case 56:
        return '/bsc';
      case 137:
        return '/polygon';
      case 42161:
        return '/arbitrum';
      case 10:
        return '/optimism';
      case 43114:
        return '/avalanche';
      case 8453:
        return '/base';
      default:
        throw AggregatorException(
          aggregator: name,
          message: 'Unsupported chain ID: $chainId',
        );
    }
  }

  SwapQuote _parseQuoteResponse(Map<String, dynamic> data, SwapParams params) {
    final outputAmount = BigInt.parse(data['buyAmount'] as String);
    final minimumOutputAmount = BigInt.parse(
      data['guaranteedBuyAmount'] as String? ??
          calculateMinimumOutput(outputAmount, params.slippage).toString(),
    );

    // Parse sources (route information)
    final sources = data['sources'] as List<dynamic>? ?? [];
    final route = _parseRoute(sources, params);

    // Parse transaction data
    final transaction = SwapTransaction(
      to: data['to'] as String,
      data: _hexToBytes(data['data'] as String),
      value: BigInt.parse(data['value'] as String),
      gasLimit: BigInt.parse(data['gas'] as String),
      gasPrice: BigInt.parse(data['gasPrice'] as String),
    );

    final estimatedGas =
        BigInt.parse(data['estimatedGas'] as String? ?? data['gas'] as String);
    final gasPrice = BigInt.parse(data['gasPrice'] as String);

    return SwapQuote(
      aggregator: name,
      params: params,
      outputAmount: outputAmount,
      minimumOutputAmount: minimumOutputAmount,
      route: route,
      transaction: transaction,
      estimatedGas: estimatedGas,
      gasCost: estimatedGas * gasPrice,
      priceImpact: (data['estimatedPriceImpact'] as num?)?.toDouble() ?? 0.0,
      validUntil:
          const Duration(minutes: 3), // 0x quotes are valid for ~3 minutes
      metadata: {
        'sources': sources,
        'sellTokenToEthRate': data['sellTokenToEthRate'],
        'buyTokenToEthRate': data['buyTokenToEthRate'],
      },
    );
  }

  SwapRoute _parseRoute(List<dynamic> sources, SwapParams params) {
    final path = <SwapToken>[params.fromToken];
    final exchanges = <String>[];
    final portions = <double>[];

    for (final source in sources) {
      if (source is Map<String, dynamic>) {
        final name = source['name'] as String? ?? 'Unknown';
        final proportion = (source['proportion'] as num?)?.toDouble() ?? 0.0;

        if (proportion > 0) {
          exchanges.add(name);
          portions.add(proportion);
        }
      }
    }

    path.add(params.toToken);

    return SwapRoute(
      path: path,
      exchanges: exchanges,
      portions: portions,
      gasEstimate: BigInt.from(150000), // Default estimate
    );
  }

  Uint8List _hexToBytes(String hex) {
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    if (hex.isEmpty) return Uint8List(0);

    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  void dispose() {
    _httpClient.close();
  }
}
