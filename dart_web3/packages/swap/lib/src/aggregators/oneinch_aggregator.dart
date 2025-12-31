import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../swap_quote.dart';
import '../swap_types.dart';
import 'aggregator_interface.dart';

/// 1inch DEX aggregator implementation
class OneInchAggregator implements DexAggregator {
  final AggregatorConfig config;
  final http.Client _httpClient;

  OneInchAggregator({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  String get name => '1inch';

  @override
  List<int> get supportedChains => [
    1,    // Ethereum
    56,   // BSC
    137,  // Polygon
    42161, // Arbitrum
    10,   // Optimism
    43114, // Avalanche
    250,  // Fantom
  ];

  @override
  bool get supportsCrossChain => false;

  String get _baseUrl => config.baseUrl ?? 'https://api.1inch.dev';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (config.apiKey != null) 'Authorization': 'Bearer ${config.apiKey}',
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
      final url = '$_baseUrl/swap/v6.0/$chainId/quote';
      
      final queryParams = {
        'src': params.fromToken.address,
        'dst': params.toToken.address,
        'amount': params.amount.toString(),
        'from': params.fromAddress,
        'slippage': (params.slippage * 100).toString(),
        'disableEstimate': 'false',
        'allowPartialFill': 'true',
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await _httpClient.get(uri, headers: _headers)
          .timeout(config.timeout);

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
      } catch (e) {
        // Continue with other slippages if one fails
        continue;
      }
    }
    
    return quotes;
  }

  @override
  Future<bool> isTokenPairSupported(SwapToken fromToken, SwapToken toToken) async {
    if (fromToken.chainId != toToken.chainId) return false;
    if (!supportedChains.contains(fromToken.chainId)) return false;
    
    try {
      final tokens = await getSupportedTokens(fromToken.chainId);
      final fromSupported = tokens.any((t) => t.address.toLowerCase() == fromToken.address.toLowerCase());
      final toSupported = tokens.any((t) => t.address.toLowerCase() == toToken.address.toLowerCase());
      return fromSupported && toSupported;
    } catch (e) {
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
      final url = '$_baseUrl/swap/v6.0/$chainId/tokens';
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(config.timeout);

      if (response.statusCode != 200) {
        throw AggregatorException(
          aggregator: name,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      
      return tokens.entries.map((entry) {
        final tokenData = entry.value as Map<String, dynamic>;
        return SwapToken(
          address: entry.key,
          symbol: tokenData['symbol'] as String,
          name: tokenData['name'] as String,
          decimals: tokenData['decimals'] as int,
          chainId: chainId,
          logoUri: tokenData['logoURI'] as String?,
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
    // 1inch doesn't provide gas price endpoint, use a default estimation
    // In a real implementation, you might call a separate gas price service
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

  SwapQuote _parseQuoteResponse(Map<String, dynamic> data, SwapParams params) {
    final outputAmount = BigInt.parse(data['dstAmount'] as String);
    final minimumOutputAmount = calculateMinimumOutput(outputAmount, params.slippage);
    
    // Parse protocols (route information)
    final protocols = data['protocols'] as List<dynamic>? ?? [];
    final route = _parseRoute(protocols, params);
    
    // Parse transaction data
    final txData = data['tx'] as Map<String, dynamic>? ?? {};
    final transaction = SwapTransaction(
      to: txData['to'] as String? ?? '',
      data: _hexToBytes(txData['data'] as String? ?? '0x'),
      value: BigInt.parse(txData['value'] as String? ?? '0'),
      gasLimit: BigInt.parse(data['estimatedGas'] as String? ?? '200000'),
      gasPrice: BigInt.parse(txData['gasPrice'] as String? ?? '0'),
    );

    return SwapQuote(
      aggregator: name,
      params: params,
      outputAmount: outputAmount,
      minimumOutputAmount: minimumOutputAmount,
      route: route,
      transaction: transaction,
      estimatedGas: BigInt.parse(data['estimatedGas'] as String? ?? '200000'),
      gasCost: BigInt.parse(data['estimatedGas'] as String? ?? '200000') * 
               BigInt.parse(txData['gasPrice'] as String? ?? '0'),
      priceImpact: (data['priceImpact'] as num?)?.toDouble() ?? 0.0,
      validUntil: const Duration(minutes: 5), // 1inch quotes are valid for ~5 minutes
      metadata: {
        'protocols': protocols,
        'guaranteedAmount': data['guaranteedAmount'],
      },
    );
  }

  SwapRoute _parseRoute(List<dynamic> protocols, SwapParams params) {
    final path = <SwapToken>[params.fromToken];
    final exchanges = <String>[];
    final portions = <double>[];
    
    for (final protocol in protocols) {
      if (protocol is List) {
        for (final step in protocol) {
          if (step is List) {
            for (final substep in step) {
              if (substep is Map<String, dynamic>) {
                final name = substep['name'] as String? ?? 'Unknown';
                final part = (substep['part'] as num?)?.toDouble() ?? 0.0;
                exchanges.add(name);
                portions.add(part / 100.0); // Convert percentage to decimal
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
      gasEstimate: BigInt.from(200000), // Default estimate
    );
  }

  Uint8List _hexToBytes(String hex) {
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    if (hex.isEmpty) return Uint8List(0);
    
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  void dispose() {
    _httpClient.close();
  }
}