import 'dart:async';
import 'dart:convert';
import 'package:dart_web3_client/dart_web3_client.dart';

import 'swap_types.dart';
import 'swap_quote.dart';

/// Swap transaction tracker
class SwapTracker {
  final PublicClient publicClient;
  final Map<String, SwapTrackingInfo> _trackingMap = {};
  final StreamController<SwapStatusUpdate> _statusController = StreamController.broadcast();

  SwapTracker(this.publicClient);

  /// Stream of swap status updates
  Stream<SwapStatusUpdate> get statusUpdates => _statusController.stream;

  /// Start tracking a swap transaction
  void trackSwap({
    required String transactionHash,
    required SwapQuote quote,
    String? userAddress,
    Map<String, dynamic>? metadata,
  }) {
    final trackingInfo = SwapTrackingInfo(
      transactionHash: transactionHash,
      quote: quote,
      userAddress: userAddress,
      startTime: DateTime.now(),
      status: SwapStatus.pending,
      metadata: metadata,
    );

    _trackingMap[transactionHash] = trackingInfo;
    
    // Start monitoring the transaction
    _monitorTransaction(transactionHash);
    
    // Emit initial status
    _emitStatusUpdate(trackingInfo);
  }

  /// Get current status of a tracked swap
  SwapTrackingInfo? getSwapStatus(String transactionHash) {
    return _trackingMap[transactionHash];
  }

  /// Get all tracked swaps
  List<SwapTrackingInfo> getAllTrackedSwaps() {
    return _trackingMap.values.toList();
  }

  /// Stop tracking a swap
  void stopTracking(String transactionHash) {
    _trackingMap.remove(transactionHash);
  }

  /// Clear all tracking data
  void clearAll() {
    _trackingMap.clear();
  }

  Future<void> _monitorTransaction(String transactionHash) async {
    final trackingInfo = _trackingMap[transactionHash];
    if (trackingInfo == null) return;

    try {
      // Poll for transaction receipt
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts = 60; // 5 minutes with 5-second intervals
      
      while (receipt == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 5));
        
        try {
          final receiptData = await publicClient.getTransactionReceipt(transactionHash);
          if (receiptData != null) {
            receipt = TransactionReceipt.fromJson(receiptData);
          }
        } catch (e) {
          // Transaction not yet mined, continue polling
        }
        
        attempts++;
        
        // Update tracking info with attempt count
        final updatedInfo = trackingInfo.copyWith(
          attempts: attempts,
          lastChecked: DateTime.now(),
        );
        _trackingMap[transactionHash] = updatedInfo;
      }

      if (receipt != null) {
        await _handleTransactionReceipt(transactionHash, receipt);
      } else {
        // Transaction timed out
        final failedInfo = trackingInfo.copyWith(
          status: SwapStatus.failed,
          error: 'Transaction confirmation timeout',
          endTime: DateTime.now(),
        );
        _trackingMap[transactionHash] = failedInfo;
        _emitStatusUpdate(failedInfo);
      }
    } catch (e) {
      // Handle monitoring error
      final errorInfo = trackingInfo.copyWith(
        status: SwapStatus.failed,
        error: 'Monitoring error: $e',
        endTime: DateTime.now(),
      );
      _trackingMap[transactionHash] = errorInfo;
      _emitStatusUpdate(errorInfo);
    }
  }

  Future<void> _handleTransactionReceipt(
    String transactionHash,
    TransactionReceipt receipt,
  ) async {
    final trackingInfo = _trackingMap[transactionHash];
    if (trackingInfo == null) return;

    try {
      final success = receipt.status == 1;
      final gasUsed = receipt.gasUsed;
      final effectiveGasPrice = receipt.effectiveGasPrice ?? BigInt.zero;
      final actualGasCost = gasUsed * effectiveGasPrice;

      SwapTrackingInfo updatedInfo;

      if (success) {
        // Analyze the swap results
        final swapResult = await _analyzeSwapResult(receipt, trackingInfo.quote);
        
        updatedInfo = trackingInfo.copyWith(
          status: SwapStatus.confirmed,
          receipt: receipt,
          actualGasCost: actualGasCost,
          swapResult: swapResult,
          endTime: DateTime.now(),
        );
      } else {
        // Transaction failed
        final revertReason = await _getRevertReason(transactionHash);
        
        updatedInfo = trackingInfo.copyWith(
          status: SwapStatus.failed,
          receipt: receipt,
          actualGasCost: actualGasCost,
          error: revertReason ?? 'Transaction reverted',
          endTime: DateTime.now(),
        );
      }

      _trackingMap[transactionHash] = updatedInfo;
      _emitStatusUpdate(updatedInfo);
    } catch (e) {
      final errorInfo = trackingInfo.copyWith(
        status: SwapStatus.failed,
        error: 'Receipt analysis error: $e',
        endTime: DateTime.now(),
      );
      _trackingMap[transactionHash] = errorInfo;
      _emitStatusUpdate(errorInfo);
    }
  }

  Future<SwapResult?> _analyzeSwapResult(
    TransactionReceipt receipt,
    SwapQuote quote,
  ) async {
    try {
      // Analyze logs to extract actual swap amounts
      // This is a simplified implementation - in practice you'd decode specific DEX logs
      
      BigInt? actualOutputAmount;
      double? actualPriceImpact;
      
      // Look for Transfer events to determine actual amounts
      for (final log in receipt.logs) {
        // This would involve decoding Transfer events and matching them to the swap
        // For now, we'll use the quote's expected output as a placeholder
      }

      return SwapResult(
        actualOutputAmount: actualOutputAmount ?? quote.outputAmount,
        expectedOutputAmount: quote.outputAmount,
        actualPriceImpact: actualPriceImpact ?? quote.priceImpact,
        expectedPriceImpact: quote.priceImpact,
        slippageUsed: quote.params.slippage,
        gasUsed: receipt.gasUsed,
        gasCost: receipt.gasUsed * (receipt.effectiveGasPrice ?? BigInt.zero),
      );
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getRevertReason(String transactionHash) async {
    try {
      // Try to get revert reason using debug_traceTransaction or similar
      // This is a simplified implementation
      return null;
    } catch (e) {
      return null;
    }
  }

  void _emitStatusUpdate(SwapTrackingInfo trackingInfo) {
    final update = SwapStatusUpdate(
      transactionHash: trackingInfo.transactionHash,
      status: trackingInfo.status,
      trackingInfo: trackingInfo,
      timestamp: DateTime.now(),
    );
    
    _statusController.add(update);
  }

  void dispose() {
    _statusController.close();
    _trackingMap.clear();
  }
}

/// Swap tracking information
class SwapTrackingInfo {
  final String transactionHash;
  final SwapQuote quote;
  final String? userAddress;
  final DateTime startTime;
  final DateTime? endTime;
  final SwapStatus status;
  final TransactionReceipt? receipt;
  final BigInt? actualGasCost;
  final SwapResult? swapResult;
  final String? error;
  final int attempts;
  final DateTime? lastChecked;
  final Map<String, dynamic>? metadata;

  const SwapTrackingInfo({
    required this.transactionHash,
    required this.quote,
    this.userAddress,
    required this.startTime,
    this.endTime,
    required this.status,
    this.receipt,
    this.actualGasCost,
    this.swapResult,
    this.error,
    this.attempts = 0,
    this.lastChecked,
    this.metadata,
  });

  /// Duration since swap started
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Whether the swap is still pending
  bool get isPending => status == SwapStatus.pending;

  /// Whether the swap completed successfully
  bool get isSuccessful => status == SwapStatus.confirmed;

  /// Whether the swap failed
  bool get isFailed => status == SwapStatus.failed;

  SwapTrackingInfo copyWith({
    String? transactionHash,
    SwapQuote? quote,
    String? userAddress,
    DateTime? startTime,
    DateTime? endTime,
    SwapStatus? status,
    TransactionReceipt? receipt,
    BigInt? actualGasCost,
    SwapResult? swapResult,
    String? error,
    int? attempts,
    DateTime? lastChecked,
    Map<String, dynamic>? metadata,
  }) {
    return SwapTrackingInfo(
      transactionHash: transactionHash ?? this.transactionHash,
      quote: quote ?? this.quote,
      userAddress: userAddress ?? this.userAddress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      receipt: receipt ?? this.receipt,
      actualGasCost: actualGasCost ?? this.actualGasCost,
      swapResult: swapResult ?? this.swapResult,
      error: error ?? this.error,
      attempts: attempts ?? this.attempts,
      lastChecked: lastChecked ?? this.lastChecked,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'quote': quote.toJson(),
      if (userAddress != null) 'userAddress': userAddress,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'status': status.toString().split('.').last,
      if (receipt != null) 'receipt': receipt!.toJson(),
      if (actualGasCost != null) 'actualGasCost': actualGasCost.toString(),
      if (swapResult != null) 'swapResult': swapResult!.toJson(),
      if (error != null) 'error': error,
      'attempts': attempts,
      if (lastChecked != null) 'lastChecked': lastChecked!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Swap result analysis
class SwapResult {
  final BigInt actualOutputAmount;
  final BigInt expectedOutputAmount;
  final double actualPriceImpact;
  final double expectedPriceImpact;
  final double slippageUsed;
  final BigInt gasUsed;
  final BigInt gasCost;

  const SwapResult({
    required this.actualOutputAmount,
    required this.expectedOutputAmount,
    required this.actualPriceImpact,
    required this.expectedPriceImpact,
    required this.slippageUsed,
    required this.gasUsed,
    required this.gasCost,
  });

  /// Difference between actual and expected output
  BigInt get outputDifference => actualOutputAmount - expectedOutputAmount;

  /// Percentage difference in output
  double get outputDifferencePercentage {
    if (expectedOutputAmount == BigInt.zero) return 0.0;
    return (outputDifference.toDouble() / expectedOutputAmount.toDouble()) * 100;
  }

  /// Whether the swap performed better than expected
  bool get performedBetter => outputDifference > BigInt.zero;

  /// Actual slippage experienced
  double get actualSlippage {
    if (expectedOutputAmount == BigInt.zero) return 0.0;
    return 1.0 - (actualOutputAmount.toDouble() / expectedOutputAmount.toDouble());
  }

  Map<String, dynamic> toJson() {
    return {
      'actualOutputAmount': actualOutputAmount.toString(),
      'expectedOutputAmount': expectedOutputAmount.toString(),
      'actualPriceImpact': actualPriceImpact,
      'expectedPriceImpact': expectedPriceImpact,
      'slippageUsed': slippageUsed,
      'gasUsed': gasUsed.toString(),
      'gasCost': gasCost.toString(),
    };
  }
}

/// Swap status update event
class SwapStatusUpdate {
  final String transactionHash;
  final SwapStatus status;
  final SwapTrackingInfo trackingInfo;
  final DateTime timestamp;

  const SwapStatusUpdate({
    required this.transactionHash,
    required this.status,
    required this.trackingInfo,
    required this.timestamp,
  });
}

/// Transaction receipt (simplified)
class TransactionReceipt {
  final String transactionHash;
  final int status;
  final BigInt gasUsed;
  final BigInt? effectiveGasPrice;
  final List<Log> logs;

  const TransactionReceipt({
    required this.transactionHash,
    required this.status,
    required this.gasUsed,
    this.effectiveGasPrice,
    required this.logs,
  });

  factory TransactionReceipt.fromJson(Map<String, dynamic> json) {
    return TransactionReceipt(
      transactionHash: json['transactionHash'] as String,
      status: int.parse(json['status'] as String, radix: 16),
      gasUsed: BigInt.parse(json['gasUsed'] as String, radix: 16),
      effectiveGasPrice: json['effectiveGasPrice'] != null
          ? BigInt.parse(json['effectiveGasPrice'] as String, radix: 16)
          : null,
      logs: (json['logs'] as List<dynamic>)
          .map((log) => Log.fromJson(log as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'status': '0x${status.toRadixString(16)}',
      'gasUsed': '0x${gasUsed.toRadixString(16)}',
      if (effectiveGasPrice != null)
        'effectiveGasPrice': '0x${effectiveGasPrice!.toRadixString(16)}',
      'logs': logs.map((log) => log.toJson()).toList(),
    };
  }
}

/// Log entry (simplified)
class Log {
  final String address;
  final List<String> topics;
  final String data;

  const Log({
    required this.address,
    required this.topics,
    required this.data,
  });

  factory Log.fromJson(Map<String, dynamic> json) {
    return Log(
      address: json['address'] as String,
      topics: (json['topics'] as List<dynamic>).cast<String>(),
      data: json['data'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'topics': topics,
      'data': data,
    };
  }
}