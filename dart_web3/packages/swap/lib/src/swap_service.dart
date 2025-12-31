import 'dart:async';
import 'dart:math' as math;
import 'package:dart_web3_client/dart_web3_client.dart';

import 'aggregators/aggregator_interface.dart';
import 'aggregators/oneinch_aggregator.dart';
import 'aggregators/zerox_aggregator.dart';
import 'aggregators/paraswap_aggregator.dart';
import 'aggregators/rango_aggregator.dart';
import 'swap_quote.dart';
import 'swap_types.dart';
import 'token_approval.dart';
import 'mev_protection.dart';
import 'slippage_calculator.dart';
import 'swap_tracker.dart';

/// Main swap service that aggregates quotes from multiple DEX aggregators
class SwapService {
  final WalletClient walletClient;
  final List<DexAggregator> aggregators;
  final TokenApprovalManager approvalManager;
  final MevProtectionService? mevProtectionService;
  final SwapTracker swapTracker;
  
  SwapService({
    required this.walletClient,
    List<DexAggregator>? aggregators,
    MevProtectionService? mevProtectionService,
  }) : aggregators = aggregators ?? _createDefaultAggregators(),
       approvalManager = TokenApprovalManager(walletClient),
       mevProtectionService = mevProtectionService,
       swapTracker = SwapTracker(walletClient);

  /// Get the best swap quote from all aggregators
  Future<SwapQuote?> getBestQuote(SwapParams params) async {
    final quotes = await getQuotes(params);
    if (quotes.isEmpty) return null;

    // Sort by net output amount (considering gas costs)
    quotes.sort((a, b) => b.netOutputAmount.compareTo(a.netOutputAmount));
    return quotes.first;
  }

  /// Get quotes from all available aggregators
  Future<List<SwapQuote>> getQuotes(SwapParams params) async {
    final futures = aggregators
        .where((aggregator) => aggregator.validateParams(params))
        .map((aggregator) => _getQuoteFromAggregator(aggregator, params));

    final results = await Future.wait(futures);
    return results.whereType<SwapQuote>().toList();
  }

  /// Get quotes with dynamic slippage calculation
  Future<List<SwapQuote>> getQuotesWithDynamicSlippage(SwapParams params) async {
    // First get quotes with base slippage
    final baseQuotes = await getQuotes(params);
    if (baseQuotes.isEmpty) return [];

    // Calculate dynamic slippage
    final dynamicSlippage = SlippageCalculator.calculateDynamicSlippage(
      fromToken: params.fromToken,
      toToken: params.toToken,
      amount: params.amount,
      quotes: baseQuotes,
    );

    // Get new quotes with dynamic slippage if it's significantly different
    if ((dynamicSlippage - params.slippage).abs() > 0.001) {
      final dynamicParams = params.copyWith(slippage: dynamicSlippage);
      return await getQuotes(dynamicParams);
    }

    return baseQuotes;
  }

  /// Execute a swap with the given quote
  Future<String> executeSwap({
    required SwapQuote quote,
    bool autoApprove = true,
    MevProtectionType? mevProtection,
  }) async {
    try {
      // Check and handle token approval if needed
      if (autoApprove) {
        await _handleTokenApproval(quote);
      }

      // Sign the transaction
      final signedTx = await walletClient.signTransaction(
        TransactionRequest(
          to: quote.transaction.to,
          data: quote.transaction.data,
          value: quote.transaction.value,
          gasLimit: quote.transaction.gasLimit,
          gasPrice: quote.transaction.gasPrice,
          maxFeePerGas: quote.transaction.maxFeePerGas,
          maxPriorityFeePerGas: quote.transaction.maxPriorityFeePerGas,
          chainId: quote.params.fromToken.chainId,
          type: TransactionType.eip1559,
        ),
      );

      String txHash;

      // Submit with MEV protection if requested
      if (mevProtection != null && 
          mevProtection != MevProtectionType.none && 
          mevProtectionService != null) {
        final result = await mevProtectionService!.submitProtectedTransaction(
          signedTransaction: signedTx,
          protectionType: mevProtection,
        );
        txHash = result.transactionHash;
      } else {
        // Submit normally
        txHash = await walletClient.sendRawTransaction(signedTx);
      }

      // Start tracking the swap
      swapTracker.trackSwap(
        transactionHash: txHash,
        quote: quote,
        userAddress: walletClient.address.address,
      );

      return txHash;
    } catch (e) {
      throw SwapExecutionException(
        'Failed to execute swap: $e',
        originalError: e,
      );
    }
  }

  /// Simulate a swap to check for potential issues
  Future<SwapSimulationResult> simulateSwap(SwapQuote quote) async {
    try {
      final result = await walletClient.call(
        CallRequest(
          from: walletClient.address.address,
          to: quote.transaction.to,
          data: quote.transaction.data,
          value: quote.transaction.value,
          gasLimit: quote.transaction.gasLimit,
        ),
      );

      return SwapSimulationResult(
        success: true,
        gasUsed: quote.estimatedGas,
        returnData: result,
      );
    } catch (e) {
      return SwapSimulationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get supported tokens for a chain
  Future<List<SwapToken>> getSupportedTokens(int chainId) async {
    final allTokens = <SwapToken>[];
    
    for (final aggregator in aggregators) {
      if (aggregator.supportedChains.contains(chainId)) {
        try {
          final tokens = await aggregator.getSupportedTokens(chainId);
          allTokens.addAll(tokens);
        } catch (e) {
          // Continue with other aggregators if one fails
          continue;
        }
      }
    }

    // Remove duplicates based on address
    final uniqueTokens = <String, SwapToken>{};
    for (final token in allTokens) {
      final key = token.address.toLowerCase();
      if (!uniqueTokens.containsKey(key)) {
        uniqueTokens[key] = token;
      }
    }

    return uniqueTokens.values.toList();
  }

  /// Check if a token pair is supported
  Future<bool> isTokenPairSupported(SwapToken fromToken, SwapToken toToken) async {
    for (final aggregator in aggregators) {
      try {
        final supported = await aggregator.isTokenPairSupported(fromToken, toToken);
        if (supported) return true;
      } catch (e) {
        // Continue checking other aggregators
        continue;
      }
    }
    return false;
  }

  /// Get swap history for an address
  List<SwapTrackingInfo> getSwapHistory([String? address]) {
    final allSwaps = swapTracker.getAllTrackedSwaps();
    
    if (address == null) return allSwaps;
    
    return allSwaps
        .where((swap) => swap.userAddress?.toLowerCase() == address.toLowerCase())
        .toList();
  }

  /// Get recommended slippage for a swap
  double getRecommendedSlippage({
    required SwapToken fromToken,
    required SwapToken toToken,
    required BigInt amount,
    List<SwapQuote>? quotes,
  }) {
    if (quotes != null && quotes.isNotEmpty) {
      return SlippageCalculator.calculateDynamicSlippage(
        fromToken: fromToken,
        toToken: toToken,
        amount: amount,
        quotes: quotes,
      );
    }

    // Fall back to static calculation
    final tiers = SlippageCalculator.getSlippageTiers(
      fromToken: fromToken,
      toToken: toToken,
      amount: amount,
    );
    
    return tiers.firstWhere((tier) => tier.recommended).slippage;
  }

  Future<SwapQuote?> _getQuoteFromAggregator(
    DexAggregator aggregator,
    SwapParams params,
  ) async {
    try {
      return await aggregator.getQuote(params);
    } catch (e) {
      // Log error but don't throw - we want to continue with other aggregators
      return null;
    }
  }

  Future<void> _handleTokenApproval(SwapQuote quote) async {
    final needsApproval = await approvalManager.isApprovalNeeded(
      token: quote.params.fromToken,
      spender: quote.transaction.to,
      amount: quote.params.amount,
    );

    if (needsApproval) {
      // Try permit first (gasless approval)
      final permitSignature = await approvalManager.approveWithPermit(
        token: quote.params.fromToken,
        spender: quote.transaction.to,
        amount: quote.params.amount,
        deadline: const Duration(hours: 1),
      );

      if (permitSignature == null) {
        // Fall back to regular approval
        final approvalTxHash = await approvalManager.approveToken(
          token: quote.params.fromToken,
          spender: quote.transaction.to,
          amount: quote.params.amount,
          useMaxApproval: true, // Use max approval to avoid future approvals
        );

        // Wait for approval transaction to be mined
        await _waitForTransaction(approvalTxHash);
      }
    }
  }

  Future<void> _waitForTransaction(String txHash) async {
    int attempts = 0;
    const maxAttempts = 60; // 5 minutes

    while (attempts < maxAttempts) {
      try {
        final receipt = await walletClient.getTransactionReceipt(txHash);
        if (receipt != null) {
          return; // Transaction mined
        }
      } catch (e) {
        // Continue waiting
      }

      await Future.delayed(const Duration(seconds: 5));
      attempts++;
    }

    throw SwapExecutionException('Approval transaction timeout');
  }

  static List<DexAggregator> _createDefaultAggregators() {
    return [
      OneInchAggregator(
        config: const AggregatorConfig(),
      ),
      ZeroXAggregator(
        config: const AggregatorConfig(),
      ),
      ParaSwapAggregator(
        config: const AggregatorConfig(),
      ),
      RangoAggregator(
        config: const AggregatorConfig(),
      ),
    ];
  }

  void dispose() {
    approvalManager.dispose();
    swapTracker.dispose();
    mevProtectionService?.dispose();
    
    for (final aggregator in aggregators) {
      if (aggregator is OneInchAggregator) {
        aggregator.dispose();
      } else if (aggregator is ZeroXAggregator) {
        aggregator.dispose();
      } else if (aggregator is ParaSwapAggregator) {
        aggregator.dispose();
      } else if (aggregator is RangoAggregator) {
        aggregator.dispose();
      }
    }
  }
}

/// Swap simulation result
class SwapSimulationResult {
  final bool success;
  final BigInt? gasUsed;
  final List<int>? returnData;
  final String? error;

  const SwapSimulationResult({
    required this.success,
    this.gasUsed,
    this.returnData,
    this.error,
  });
}

/// Exception thrown when swap execution fails
class SwapExecutionException implements Exception {
  final String message;
  final dynamic originalError;

  const SwapExecutionException(this.message, {this.originalError});

  @override
  String toString() => 'SwapExecutionException: $message';
}