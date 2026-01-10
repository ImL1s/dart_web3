import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3_universal_swap/web3_universal_swap.dart';

/// Service to handle Token Swapping logic via 1inch
class SwapService {
  final _storage = const FlutterSecureStorage();
  String? _apiKey;
  OneInchAggregator? _aggregator;

  /// Check if API key is configured
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Load API key from secure storage
  Future<void> loadApiKey() async {
    _apiKey = await _storage.read(key: 'oneinch_api_key');
    if (isConfigured) {
      _aggregator = OneInchAggregator(config: AggregatorConfig(apiKey: _apiKey));
    }
  }

  /// Save API key to secure storage
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: 'oneinch_api_key', value: key);
    _apiKey = key;
    _aggregator = OneInchAggregator(config: AggregatorConfig(apiKey: key));
  }
  
  /// Get supported tokens for a chain
  Future<List<SwapToken>> getTokens(int chainId) async {
      if (!isConfigured) return [];
      try {
          return await _aggregator!.getSupportedTokens(chainId);
      } catch (e) {
          // If 1inch fails or not supported, return empty
          return [];
      }
  }

  /// Get a quote for a swap
  Future<SwapQuote?> getQuote({
    required SwapToken fromToken,
    required SwapToken toToken,
    required BigInt amount,
    required String fromAddress,
    double slippage = 0.005,
  }) async {
    if (!isConfigured) throw Exception("1inch API Key not set. Please configure in Settings.");
    
    final params = SwapParams(
      fromToken: fromToken,
      toToken: toToken,
      amount: amount,
      fromAddress: fromAddress,
      slippage: slippage,
    );
    
    return await _aggregator!.getQuote(params);
  }
}
