import 'dart:async';
import 'package:dart_web3_provider/dart_web3_provider.dart';
import 'flashbots_types.dart';

/// Service for MEV protection and Flashbots
class MevService { // Flashbots requires authentication header

  MevService(this._provider);
  final RpcProvider _provider;

  /// Send a bundle to Flashbots relay
  Future<String> sendBundle(FlashbotsBundle bundle) async {
    final params = [bundle.toJson()];
    
    // In a real implementation, we would sign the payload with _authSigner
    // and add it to the headers (X-Flashbots-Signature).
    // The current RpcProvider might need extension to support per-request headers.
    
    // For now, we assume the provider is configured for the relay or handles headers.
    final result = await _provider.call<Map<String, dynamic>>(
      'eth_sendBundle',
      params,
    );
    
    return result['bundleHash'] as String;
  }

  /// Simulate a bundle
  Future<Map<String, dynamic>> callBundle(FlashbotsBundle bundle) async {
    final params = [
      bundle.toJson(),
      'latest', // State block tag
    ];

    return _provider.call<Map<String, dynamic>>(
      'eth_callBundle',
      params,
    );
  }
}
