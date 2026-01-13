import 'dart:async';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

import 'bridge_quote.dart';
import 'bridge_tracker.dart';
import 'bridge_types.dart';
import 'protocols/bridge_protocol.dart';
import 'protocols/layerzero_bridge.dart';
import 'protocols/native_bridge.dart';
import 'protocols/stargate_bridge.dart';
import 'protocols/wormhole_bridge.dart';

/// Main bridge service that aggregates quotes from multiple bridge protocols
class BridgeService {
  BridgeService({
    required this.clients,
    List<BridgeProtocol>? protocols,
  })  : protocols = protocols ?? _createDefaultProtocols(),
        bridgeTracker = BridgeTracker(clients);
  final Map<int, PublicClient> clients;
  final List<BridgeProtocol> protocols;
  final BridgeTracker bridgeTracker;

  /// Get the best bridge quote from all protocols
  Future<BridgeQuote?> getBestQuote(BridgeParams params) async {
    final quotes = await getQuotes(params);
    if (quotes.isEmpty) {
      return null;
    }

    // Sort by net output amount (considering fees and confidence)
    quotes.sort((a, b) {
      // Weight by confidence and net output
      final scoreA = a.netOutputAmount.toDouble() * a.confidence;
      final scoreB = b.netOutputAmount.toDouble() * b.confidence;
      return scoreB.compareTo(scoreA);
    });

    return quotes.first;
  }

  /// Get quotes from all available protocols
  Future<List<BridgeQuote>> getQuotes(BridgeParams params) async {
    final futures = protocols
        .where((protocol) => protocol.supportsChainPair(
            params.sourceChainId, params.destinationChainId))
        .map((protocol) => _getQuoteFromProtocol(protocol, params));

    final results = await Future.wait(futures);
    return results.whereType<BridgeQuote>().toList();
  }

  /// Get quotes aggregated with analysis
  Future<BridgeQuoteAggregation> getQuotesAggregated(
      BridgeParams params) async {
    final quotes = await getQuotes(params);
    return BridgeQuoteAggregation.fromQuotes(quotes);
  }

  /// Execute a bridge with the given quote
  Future<String> executeBridge({
    required BridgeQuote quote,
    required WalletClient walletClient,
  }) async {
    try {
      // Validate that we have the correct wallet client for the source chain
      if (walletClient.chain.chainId != quote.params.sourceChainId) {
        throw BridgeExecutionException(
          'Wallet client chain ID (${walletClient.chain.chainId}) does not match source chain (${quote.params.sourceChainId})',
        );
      }

      // Check if amount is within limits
      if (!quote.isAmountValid) {
        throw BridgeExecutionException(
          'Amount ${quote.params.amount} is outside bridge limits',
        );
      }

      // Get the first step transaction (for multi-step bridges, only execute first step)
      final firstStep = quote.route.steps.first;
      if (firstStep.transaction == null) {
        throw BridgeExecutionException(
          'No transaction data available for bridge execution',
        );
      }

      final transaction = firstStep.transaction!;

      // Sign and send the transaction
      final txHash = await walletClient.sendTransactionRequest(
        TransactionRequest(
          to: transaction.to,
          data: transaction.data,
          value: transaction.value,
          gasLimit: transaction.gasLimit,
          gasPrice: transaction.gasPrice,
          maxFeePerGas: transaction.maxFeePerGas,
          maxPriorityFeePerGas: transaction.maxPriorityFeePerGas,
          chainId: transaction.chainId,
        ),
      );

      // Start tracking the bridge
      bridgeTracker.trackBridge(
        sourceTransactionHash: txHash,
        quote: quote,
        userAddress: walletClient.address,
      );

      return txHash;
    } catch (e) {
      throw BridgeExecutionException(
        'Failed to execute bridge: $e',
        originalError: e,
      );
    }
  }

  /// Get supported tokens for a chain pair
  Future<List<BridgeToken>> getSupportedTokens(
      int sourceChainId, int destinationChainId) async {
    final allTokens = <BridgeToken>[];

    for (final protocol in protocols) {
      if (protocol.supportsChainPair(sourceChainId, destinationChainId)) {
        try {
          final tokens = await protocol.getSupportedTokens(
              sourceChainId, destinationChainId);
          allTokens.addAll(tokens);
        } on Exception catch (_) {
          // Continue with other protocols if one fails
          continue;
        }
      }
    }

    // Remove duplicates based on symbol and address
    final uniqueTokens = <String, BridgeToken>{};
    for (final token in allTokens) {
      final key = '${token.symbol}_${token.address}'.toLowerCase();
      if (!uniqueTokens.containsKey(key)) {
        uniqueTokens[key] = token;
      }
    }

    return uniqueTokens.values.toList();
  }

  /// Check if a token pair is supported for bridging
  Future<bool> isTokenPairSupported(
    BridgeToken sourceToken,
    BridgeToken destinationToken,
    int sourceChainId,
    int destinationChainId,
  ) async {
    for (final protocol in protocols) {
      try {
        final supported = await protocol.isTokenPairSupported(
          sourceToken,
          destinationToken,
          sourceChainId,
          destinationChainId,
        );
        if (supported) {
          return true;
        }
      } on Exception catch (_) {
        // Continue checking other protocols
        continue;
      }
    }
    return false;
  }

  /// Get bridge history for an address
  List<BridgeTrackingInfo> getBridgeHistory([String? address]) {
    final allBridges = bridgeTracker.getAllTrackedBridges();

    if (address == null) return allBridges;

    return allBridges
        .where((bridge) =>
            bridge.userAddress?.toLowerCase() == address.toLowerCase())
        .toList();
  }

  /// Get supported chain pairs
  List<ChainPair> getSupportedChainPairs() {
    final pairs = <ChainPair>[];
    final addedPairs = <String>{};

    for (final protocol in protocols) {
      for (final sourceChain in protocol.supportedSourceChains) {
        for (final destChain in protocol.supportedDestinationChains) {
          if (sourceChain != destChain) {
            final pairKey = '${sourceChain}_$destChain';
            if (!addedPairs.contains(pairKey)) {
              pairs.add(
                ChainPair(
                  sourceChainId: sourceChain,
                  destinationChainId: destChain,
                  supportedProtocols: [protocol.name],
                ),
              );
              addedPairs.add(pairKey);
            } else {
              // Add protocol to existing pair
              final existingPair = pairs.firstWhere(
                (p) =>
                    p.sourceChainId == sourceChain &&
                    p.destinationChainId == destChain,
              );
              existingPair.supportedProtocols.add(protocol.name);
            }
          }
        }
      }
    }

    return pairs;
  }

  /// Get estimated bridge time for a route
  Future<Duration> getEstimatedTime(
    int sourceChainId,
    int destinationChainId,
    BigInt amount,
  ) async {
    final times = <Duration>[];

    for (final protocol in protocols) {
      if (protocol.supportsChainPair(sourceChainId, destinationChainId)) {
        try {
          final time = await protocol.getEstimatedTime(
              sourceChainId, destinationChainId, amount);
          times.add(time);
        } on Exception catch (_) {
          // Continue with other protocols
          continue;
        }
      }
    }

    if (times.isEmpty) {
      return const Duration(hours: 1); // Default estimate
    }

    // Return average time
    final totalSeconds =
        times.fold<int>(0, (sum, time) => sum + time.inSeconds);
    return Duration(seconds: totalSeconds ~/ times.length);
  }

  /// Get bridge limits for a specific route
  Future<BridgeLimits?> getBridgeLimits(
    BridgeToken token,
    int sourceChainId,
    int destinationChainId,
  ) async {
    for (final protocol in protocols) {
      if (protocol.supportsChainPair(sourceChainId, destinationChainId)) {
        try {
          final limits = await protocol.getBridgeLimits(
              token, sourceChainId, destinationChainId);
          return limits;
        } on Exception catch (_) {
          // Continue with other protocols
          continue;
        }
      }
    }

    return null;
  }

  /// Find optimal route for a bridge
  Future<BridgeRoute?> findOptimalRoute(BridgeParams params) async {
    final quotes = await getQuotes(params);
    if (quotes.isEmpty) return null;

    // Find the quote with the best balance of output, time, and confidence
    BridgeQuote? bestQuote;
    var bestScore = 0.0;

    for (final quote in quotes) {
      // Calculate a composite score
      final outputScore =
          quote.netOutputAmount.toDouble() / params.amount.toDouble();
      final timeScore = 1.0 / (quote.estimatedTime.inMinutes + 1);
      final confidenceScore = quote.confidence;

      // Weighted average (output: 50%, confidence: 30%, time: 20%)
      final score =
          (outputScore * 0.5) + (confidenceScore * 0.3) + (timeScore * 0.2);

      if (score > bestScore) {
        bestScore = score;
        bestQuote = quote;
      }
    }

    return bestQuote?.route;
  }

  Future<BridgeQuote?> _getQuoteFromProtocol(
    BridgeProtocol protocol,
    BridgeParams params,
  ) async {
    try {
      return await protocol.getQuote(params);
    } on Exception catch (_) {
      // Log error but don't throw - we want to continue with other protocols
      return null;
    }
  }

  static List<BridgeProtocol> _createDefaultProtocols() {
    return [
      LayerZeroBridge(
        config: const BridgeProtocolConfig(),
      ),
      WormholeBridge(
        config: const BridgeProtocolConfig(),
      ),
      StargateBridge(
        config: const BridgeProtocolConfig(),
      ),
      NativeBridge(
        config: const BridgeProtocolConfig(),
      ),
    ];
  }

  void dispose() {
    bridgeTracker.dispose();

    for (final protocol in protocols) {
      if (protocol is LayerZeroBridge) {
        protocol.dispose();
      } else if (protocol is WormholeBridge) {
        protocol.dispose();
      } else if (protocol is StargateBridge) {
        protocol.dispose();
      } else if (protocol is NativeBridge) {
        protocol.dispose();
      }
    }
  }
}

/// Chain pair information
class ChainPair {
  ChainPair({
    required this.sourceChainId,
    required this.destinationChainId,
    required this.supportedProtocols,
  });
  final int sourceChainId;
  final int destinationChainId;
  final List<String> supportedProtocols;

  @override
  String toString() {
    return 'ChainPair($sourceChainId -> $destinationChainId, protocols: ${supportedProtocols.join(', ')})';
  }
}

/// Exception thrown when bridge execution fails
class BridgeExecutionException implements Exception {
  const BridgeExecutionException(this.message, {this.originalError});
  final String message;
  final dynamic originalError;

  @override
  String toString() => 'BridgeExecutionException: $message';
}
