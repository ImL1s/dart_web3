import 'dart:convert';
import 'package:http/http.dart' as http;

import 'swap_types.dart';

/// MEV protection service for swap transactions
class MevProtectionService {
  MevProtectionService({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  final MevProtectionConfig config;
  final http.Client _httpClient;

  /// Submit transaction with MEV protection
  Future<MevProtectionResult> submitProtectedTransaction({
    required String signedTransaction,
    required MevProtectionType protectionType,
    Map<String, dynamic>? options,
  }) async {
    switch (protectionType) {
      case MevProtectionType.flashbots:
        return _submitToFlashbots(signedTransaction, options);
      case MevProtectionType.mevBlocker:
        return _submitToMevBlocker(signedTransaction, options);
      case MevProtectionType.eden:
        return _submitToEden(signedTransaction, options);
      case MevProtectionType.none:
        throw MevProtectionException(
          'No MEV protection specified',
        );
    }
  }

  /// Check if MEV protection is available for a chain
  bool isProtectionAvailable(int chainId, MevProtectionType protectionType) {
    switch (protectionType) {
      case MevProtectionType.flashbots:
        return [1, 5, 11155111].contains(chainId); // Mainnet, Goerli, Sepolia
      case MevProtectionType.mevBlocker:
        return [1].contains(chainId); // Mainnet only
      case MevProtectionType.eden:
        return [1].contains(chainId); // Mainnet only
      case MevProtectionType.none:
        return false;
    }
  }

  /// Get recommended MEV protection for a swap
  MevProtectionType getRecommendedProtection({
    required int chainId,
    required BigInt swapAmount,
    required double priceImpact,
  }) {
    // No protection needed for small swaps or low impact
    if (swapAmount < BigInt.from(1000000000000000000) || priceImpact < 0.001) {
      return MevProtectionType.none;
    }

    // Use Flashbots for supported chains
    if (isProtectionAvailable(chainId, MevProtectionType.flashbots)) {
      return MevProtectionType.flashbots;
    }

    // Fall back to MEV Blocker if available
    if (isProtectionAvailable(chainId, MevProtectionType.mevBlocker)) {
      return MevProtectionType.mevBlocker;
    }

    return MevProtectionType.none;
  }

  /// Estimate MEV protection cost
  Future<BigInt> estimateProtectionCost({
    required MevProtectionType protectionType,
    required int chainId,
    required BigInt gasLimit,
  }) async {
    switch (protectionType) {
      case MevProtectionType.flashbots:
        // Flashbots Protect is free
        return BigInt.zero;
      case MevProtectionType.mevBlocker:
        // MEV Blocker is free
        return BigInt.zero;
      case MevProtectionType.eden:
        // Eden Network may have fees
        return BigInt.zero; // Simplified
      case MevProtectionType.none:
        return BigInt.zero;
    }
  }

  Future<MevProtectionResult> _submitToFlashbots(
    String signedTransaction,
    Map<String, dynamic>? options,
  ) async {
    try {
      const url = 'https://protect.flashbots.net';

      final body = {
        'jsonrpc': '2.0',
        'method': 'eth_sendRawTransaction',
        'params': [signedTransaction],
        'id': 1,
      };

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'X-Flashbots-Origin': config.origin ?? 'web3_universal_swap',
            },
            body: json.encode(body),
          )
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw MevProtectionException(
          'Flashbots submission failed: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        throw MevProtectionException(
          'Flashbots error: ${data['error']['message']}',
        );
      }

      final txHash = data['result'] as String;

      return MevProtectionResult(
        transactionHash: txHash,
        protectionType: MevProtectionType.flashbots,
        status: MevProtectionStatus.submitted,
        protectionId: txHash,
        estimatedSavings:
            BigInt.zero, // Flashbots doesn't provide this directly
      );
    } catch (e) {
      if (e is MevProtectionException) rethrow;
      throw MevProtectionException(
        'Failed to submit to Flashbots: $e',
        originalError: e,
      );
    }
  }

  Future<MevProtectionResult> _submitToMevBlocker(
    String signedTransaction,
    Map<String, dynamic>? options,
  ) async {
    try {
      const url = 'https://rpc.mevblocker.io';

      final body = {
        'jsonrpc': '2.0',
        'method': 'eth_sendRawTransaction',
        'params': [signedTransaction],
        'id': 1,
      };

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw MevProtectionException(
          'MEV Blocker submission failed: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        throw MevProtectionException(
          'MEV Blocker error: ${data['error']['message']}',
        );
      }

      final txHash = data['result'] as String;

      return MevProtectionResult(
        transactionHash: txHash,
        protectionType: MevProtectionType.mevBlocker,
        status: MevProtectionStatus.submitted,
        protectionId: txHash,
        estimatedSavings: BigInt.zero,
      );
    } catch (e) {
      if (e is MevProtectionException) rethrow;
      throw MevProtectionException(
        'Failed to submit to MEV Blocker: $e',
        originalError: e,
      );
    }
  }

  Future<MevProtectionResult> _submitToEden(
    String signedTransaction,
    Map<String, dynamic>? options,
  ) async {
    try {
      const url = 'https://api.edennetwork.io/v1/rpc';

      final body = {
        'jsonrpc': '2.0',
        'method': 'eth_sendRawTransaction',
        'params': [signedTransaction],
        'id': 1,
      };

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (config.apiKey != null)
                'Authorization': 'Bearer ${config.apiKey}',
            },
            body: json.encode(body),
          )
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw MevProtectionException(
          'Eden Network submission failed: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        throw MevProtectionException(
          'Eden Network error: ${data['error']['message']}',
        );
      }

      final txHash = data['result'] as String;

      return MevProtectionResult(
        transactionHash: txHash,
        protectionType: MevProtectionType.eden,
        status: MevProtectionStatus.submitted,
        protectionId: txHash,
        estimatedSavings: BigInt.zero,
      );
    } catch (e) {
      if (e is MevProtectionException) rethrow;
      throw MevProtectionException(
        'Failed to submit to Eden Network: $e',
        originalError: e,
      );
    }
  }

  /// Check protection status
  Future<MevProtectionStatus> checkProtectionStatus({
    required String protectionId,
    required MevProtectionType protectionType,
  }) async {
    // This would typically involve checking the transaction status
    // and any protection-specific APIs

    // For now, return a simplified status
    return MevProtectionStatus.confirmed;
  }

  void dispose() {
    _httpClient.close();
  }
}

/// MEV protection configuration
class MevProtectionConfig {
  const MevProtectionConfig({
    this.apiKey,
    this.origin,
    this.timeout = const Duration(seconds: 30),
    this.headers = const {},
  });
  final String? apiKey;
  final String? origin;
  final Duration timeout;
  final Map<String, String> headers;
}

/// MEV protection result
class MevProtectionResult {
  const MevProtectionResult({
    required this.transactionHash,
    required this.protectionType,
    required this.status,
    required this.protectionId,
    required this.estimatedSavings,
    this.metadata,
  });

  factory MevProtectionResult.fromJson(Map<String, dynamic> json) {
    return MevProtectionResult(
      transactionHash: json['transactionHash'] as String,
      protectionType: MevProtectionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['protectionType'],
      ),
      status: MevProtectionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      protectionId: json['protectionId'] as String,
      estimatedSavings: BigInt.parse(json['estimatedSavings'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String transactionHash;
  final MevProtectionType protectionType;
  final MevProtectionStatus status;
  final String protectionId;
  final BigInt estimatedSavings;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'protectionType': protectionType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'protectionId': protectionId,
      'estimatedSavings': estimatedSavings.toString(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// MEV protection status
enum MevProtectionStatus {
  submitted,
  pending,
  confirmed,
  failed,
  cancelled,
}

/// Exception thrown when MEV protection operations fail
class MevProtectionException implements Exception {
  const MevProtectionException(this.message, {this.originalError});
  final String message;
  final dynamic originalError;

  @override
  String toString() => 'MevProtectionException: $message';
}
