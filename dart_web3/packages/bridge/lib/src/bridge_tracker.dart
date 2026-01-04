import 'dart:async';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

import 'bridge_quote.dart';
import 'bridge_types.dart';

/// Bridge transaction tracker
class BridgeTracker {

  BridgeTracker(this._clients);
  final Map<int, PublicClient> _clients;
  final Map<String, BridgeTrackingInfo> _trackingMap = {};
  final StreamController<BridgeStatusUpdate> _statusController = StreamController.broadcast();

  /// Stream of bridge status updates
  Stream<BridgeStatusUpdate> get statusUpdates => _statusController.stream;

  /// Start tracking a bridge transaction
  void trackBridge({
    required String sourceTransactionHash,
    required BridgeQuote quote,
    String? userAddress,
    Map<String, dynamic>? metadata,
  }) {
    final trackingInfo = BridgeTrackingInfo(
      sourceTransactionHash: sourceTransactionHash,
      quote: quote,
      userAddress: userAddress,
      startTime: DateTime.now(),
      status: BridgeStatus.pending,
      metadata: metadata,
    );

    _trackingMap[sourceTransactionHash] = trackingInfo;
    
    // Start monitoring the bridge
    _monitorBridge(sourceTransactionHash);
    
    // Emit initial status
    _emitStatusUpdate(trackingInfo);
  }

  /// Get current status of a tracked bridge
  BridgeTrackingInfo? getBridgeStatus(String sourceTransactionHash) {
    return _trackingMap[sourceTransactionHash];
  }

  /// Get all tracked bridges
  List<BridgeTrackingInfo> getAllTrackedBridges() {
    return _trackingMap.values.toList();
  }

  /// Stop tracking a bridge
  void stopTracking(String sourceTransactionHash) {
    _trackingMap.remove(sourceTransactionHash);
  }

  /// Clear all tracking data
  void clearAll() {
    _trackingMap.clear();
  }

  Future<void> _monitorBridge(String sourceTransactionHash) async {
    final trackingInfo = _trackingMap[sourceTransactionHash];
    if (trackingInfo == null) return;

    try {
      // Step 1: Wait for source transaction confirmation
      await _waitForSourceConfirmation(sourceTransactionHash);
      
      // Step 2: Monitor bridge processing
      await _monitorBridgeProcessing(sourceTransactionHash);
      
      // Step 3: Wait for destination transaction
      await _waitForDestinationTransaction(sourceTransactionHash);
      
    } on Exception catch (e) {
      // Handle monitoring error
      final errorInfo = trackingInfo.copyWith(
        status: BridgeStatus.failed,
        error: 'Monitoring error: $e',
        endTime: DateTime.now(),
      );
      _trackingMap[sourceTransactionHash] = errorInfo;
      _emitStatusUpdate(errorInfo);
    }
  }

  Future<void> _waitForSourceConfirmation(String sourceTransactionHash) async {
    final trackingInfo = _trackingMap[sourceTransactionHash];
    if (trackingInfo == null) return;

    final sourceClient = _clients[trackingInfo.quote.params.sourceChainId];
    if (sourceClient == null) {
      throw Exception('No client for source chain ${trackingInfo.quote.params.sourceChainId}');
    }

    // Poll for source transaction receipt
    TransactionReceipt? receipt;
    var attempts = 0;
    const maxAttempts = 60; // 5 minutes with 5-second intervals
    
    while (receipt == null && attempts < maxAttempts) {
      await Future<void>.delayed(const Duration(seconds: 5));
      
      try {
        final receiptData = await sourceClient.getTransactionReceipt(sourceTransactionHash);
        if (receiptData != null) {
          receipt = receiptData;
        }
      } on Exception catch (_) {
        // Transaction not yet mined, continue polling
      }
      
      attempts++;
    }

    if (receipt != null && receipt.status == 1) {
      // Source transaction confirmed
      final confirmedInfo = trackingInfo.copyWith(
        status: BridgeStatus.sourceConfirmed,
        sourceReceipt: receipt,
      );
      _trackingMap[sourceTransactionHash] = confirmedInfo;
      _emitStatusUpdate(confirmedInfo);
    } else {
      // Source transaction failed or timed out
      final failedInfo = trackingInfo.copyWith(
        status: BridgeStatus.failed,
        error: receipt?.status == 0 ? 'Source transaction failed' : 'Source transaction timeout',
        endTime: DateTime.now(),
      );
      _trackingMap[sourceTransactionHash] = failedInfo;
      _emitStatusUpdate(failedInfo);
      return;
    }
  }

  Future<void> _monitorBridgeProcessing(String sourceTransactionHash) async {
    final trackingInfo = _trackingMap[sourceTransactionHash];
    if (trackingInfo == null) return;

    // Update status to bridging
    final bridgingInfo = trackingInfo.copyWith(
      status: BridgeStatus.bridging,
    );
    _trackingMap[sourceTransactionHash] = bridgingInfo;
    _emitStatusUpdate(bridgingInfo);

    // Wait for the estimated bridge time
    await Future<void>.delayed(Duration(milliseconds: (trackingInfo.quote.estimatedTime.inMilliseconds * 0.8).toInt())); // Wait for 80% of estimated time

    // Check if we can find the destination transaction
    await _checkForDestinationTransaction(sourceTransactionHash);
  }

  Future<void> _waitForDestinationTransaction(String sourceTransactionHash) async {
    final trackingInfo = _trackingMap[sourceTransactionHash];
    if (trackingInfo == null) return;

    // Update status to destination pending
    final pendingInfo = trackingInfo.copyWith(
      status: BridgeStatus.destinationPending,
    );
    _trackingMap[sourceTransactionHash] = pendingInfo;
    _emitStatusUpdate(pendingInfo);

    // Continue checking for destination transaction
    var attempts = 0;
    const maxAttempts = 240; // 20 minutes with 5-second intervals
    
    while (attempts < maxAttempts) {
      await Future<void>.delayed(const Duration(seconds: 5));
      
      final found = await _checkForDestinationTransaction(sourceTransactionHash);
      if (found) return;
      
      attempts++;
    }

    // Timeout waiting for destination transaction
    final timeoutInfo = trackingInfo.copyWith(
      status: BridgeStatus.failed,
      error: 'Timeout waiting for destination transaction',
      endTime: DateTime.now(),
    );
    _trackingMap[sourceTransactionHash] = timeoutInfo;
    _emitStatusUpdate(timeoutInfo);
  }

  Future<bool> _checkForDestinationTransaction(String sourceTransactionHash) async {
    final trackingInfo = _trackingMap[sourceTransactionHash];
    if (trackingInfo == null) return false;

    final destinationClient = _clients[trackingInfo.quote.params.destinationChainId];
    if (destinationClient == null) return false;

    try {
      // This is a simplified implementation
      // In practice, you would need to:
      // 1. Parse the source transaction logs to get bridge-specific identifiers
      // 2. Query the destination chain for transactions with those identifiers
      // 3. Different bridges have different ways to track cross-chain transactions
      
      // For now, we'll simulate finding the destination transaction
      // after a certain time has passed
      final elapsed = DateTime.now().difference(trackingInfo.startTime);
      if (elapsed > trackingInfo.quote.estimatedTime) {
        // Simulate successful completion
        final completedInfo = trackingInfo.copyWith(
          status: BridgeStatus.completed,
          destinationTransactionHash: '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
          endTime: DateTime.now(),
        );
        _trackingMap[sourceTransactionHash] = completedInfo;
        _emitStatusUpdate(completedInfo);
        return true;
      }
    } on Exception catch (_) {
      // Error checking destination transaction
    }

    return false;
  }

  void _emitStatusUpdate(BridgeTrackingInfo trackingInfo) {
    final update = BridgeStatusUpdate(
      sourceTransactionHash: trackingInfo.sourceTransactionHash,
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

/// Bridge tracking information
class BridgeTrackingInfo {

  const BridgeTrackingInfo({
    required this.sourceTransactionHash,
    required this.quote, required this.startTime, required this.status, this.destinationTransactionHash,
    this.userAddress,
    this.endTime,
    this.sourceReceipt,
    this.destinationReceipt,
    this.error,
    this.metadata,
  });
  final String sourceTransactionHash;
  final String? destinationTransactionHash;
  final BridgeQuote quote;
  final String? userAddress;
  final DateTime startTime;
  final DateTime? endTime;
  final BridgeStatus status;
  final TransactionReceipt? sourceReceipt;
  final TransactionReceipt? destinationReceipt;
  final String? error;
  final Map<String, dynamic>? metadata;

  /// Duration since bridge started
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Whether the bridge is still in progress
  bool get isInProgress => [
    BridgeStatus.pending,
    BridgeStatus.sourceConfirmed,
    BridgeStatus.bridging,
    BridgeStatus.destinationPending,
  ].contains(status);

  /// Whether the bridge completed successfully
  bool get isCompleted => status == BridgeStatus.completed;

  /// Whether the bridge failed
  bool get isFailed => status == BridgeStatus.failed;

  /// Progress percentage (0.0 to 1.0)
  double get progress {
    switch (status) {
      case BridgeStatus.pending:
        return 0;
      case BridgeStatus.sourceConfirmed:
        return 0.2;
      case BridgeStatus.bridging:
        return 0.5;
      case BridgeStatus.destinationPending:
        return 0.8;
      case BridgeStatus.completed:
        return 1;
      case BridgeStatus.failed:
      case BridgeStatus.refunded:
        return 0;
    }
  }

  /// Human-readable status description
  String get statusDescription {
    switch (status) {
      case BridgeStatus.pending:
        return 'Waiting for source transaction confirmation';
      case BridgeStatus.sourceConfirmed:
        return 'Source transaction confirmed, initiating bridge';
      case BridgeStatus.bridging:
        return 'Bridge in progress';
      case BridgeStatus.destinationPending:
        return 'Waiting for destination transaction';
      case BridgeStatus.completed:
        return 'Bridge completed successfully';
      case BridgeStatus.failed:
        return 'Bridge failed';
      case BridgeStatus.refunded:
        return 'Bridge refunded';
    }
  }

  BridgeTrackingInfo copyWith({
    String? sourceTransactionHash,
    String? destinationTransactionHash,
    BridgeQuote? quote,
    String? userAddress,
    DateTime? startTime,
    DateTime? endTime,
    BridgeStatus? status,
    TransactionReceipt? sourceReceipt,
    TransactionReceipt? destinationReceipt,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return BridgeTrackingInfo(
      sourceTransactionHash: sourceTransactionHash ?? this.sourceTransactionHash,
      destinationTransactionHash: destinationTransactionHash ?? this.destinationTransactionHash,
      quote: quote ?? this.quote,
      userAddress: userAddress ?? this.userAddress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      sourceReceipt: sourceReceipt ?? this.sourceReceipt,
      destinationReceipt: destinationReceipt ?? this.destinationReceipt,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceTransactionHash': sourceTransactionHash,
      if (destinationTransactionHash != null) 
        'destinationTransactionHash': destinationTransactionHash,
      'quote': quote.toJson(),
      if (userAddress != null) 'userAddress': userAddress,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'status': status.toString().split('.').last,
      if (sourceReceipt != null) 'sourceReceipt': _receiptToJson(sourceReceipt!),
      if (destinationReceipt != null) 'destinationReceipt': _receiptToJson(destinationReceipt!),
      if (error != null) 'error': error,
      if (metadata != null) 'metadata': metadata,
    };
  }

  Map<String, dynamic> _receiptToJson(TransactionReceipt receipt) {
    // Manually map fields since TransactionReceipt doesn't have toJson
    return {
      'transactionHash': receipt.transactionHash,
      'status': '0x${receipt.status.toRadixString(16)}',
      'gasUsed': '0x${receipt.gasUsed.toRadixString(16)}',
      if (receipt.effectiveGasPrice != null)
        'effectiveGasPrice': '0x${receipt.effectiveGasPrice!.toRadixString(16)}',
      'logs': receipt.logs.map((log) => {
            'address': log.address,
            'topics': log.topics,
            'data': HexUtils.encode(log.data),
          },).toList(),
    };
  }
}

/// Bridge status update event
class BridgeStatusUpdate {

  const BridgeStatusUpdate({
    required this.sourceTransactionHash,
    required this.status,
    required this.trackingInfo,
    required this.timestamp,
  });
  final String sourceTransactionHash;
  final BridgeStatus status;
  final BridgeTrackingInfo trackingInfo;
  final DateTime timestamp;
}

