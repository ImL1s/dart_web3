import 'dart:async';

import 'package:dart_web3_client/dart_web3_client.dart';

import 'event_filter.dart';
import 'event_subscriber.dart';

/// Handles blockchain reorganizations and manages event consistency.
class ReorgHandler {
  /// The event subscriber.
  final EventSubscriber subscriber;

  /// Cache of processed logs by block hash.
  final Map<String, List<Log>> _logCache = {};

  /// Cache of block hashes by block number.
  final Map<BigInt, String> _blockHashCache = {};

  /// Maximum number of blocks to keep in cache.
  final int maxCacheSize;

  /// Number of confirmations required before considering a log final.
  final int confirmationDepth;

  ReorgHandler(
    this.subscriber, {
    this.maxCacheSize = 1000,
    this.confirmationDepth = 12,
  });

  /// Processes logs and handles potential reorganizations.
  /// 
  /// Returns a stream of logs that filters out removed logs and
  /// emits reorg events when chain reorganizations are detected.
  Stream<ReorgEvent> processLogs(EventFilter filter) async* {
    await for (final log in subscriber.subscribe(filter)) {
      final reorgEvent = await _processLog(log);
      if (reorgEvent != null) {
        yield reorgEvent;
      }
    }
  }

  /// Processes a single log and detects reorganizations.
  Future<ReorgEvent?> _processLog(Log log) async {
    // Check if this is a removed log (reorg indicator)
    if (log.removed) {
      return ReorgEvent.removed(log);
    }

    // Check for block hash consistency
    final cachedHash = _blockHashCache[log.blockNumber];
    if (cachedHash != null && cachedHash != log.blockHash) {
      // Block hash mismatch - potential reorg
      final reorgLogs = await _handleReorganization(log.blockNumber, log.blockHash);
      return ReorgEvent.reorganization(log.blockNumber, reorgLogs, [log]);
    }

    // Update caches
    _updateCaches(log);

    // Check if log has enough confirmations
    final currentBlock = await subscriber.publicClient.getBlockNumber();
    final confirmations = (currentBlock - log.blockNumber).toInt();

    if (confirmations >= confirmationDepth) {
      return ReorgEvent.confirmed(log);
    } else {
      return ReorgEvent.pending(log, confirmations);
    }
  }

  /// Handles a detected reorganization.
  Future<List<Log>> _handleReorganization(BigInt blockNumber, String newBlockHash) async {
    final removedLogs = <Log>[];

    // Find all cached logs from the reorganized block onwards
    final blocksToRemove = _blockHashCache.keys
        .where((block) => block >= blockNumber)
        .toList();

    for (final block in blocksToRemove) {
      final oldHash = _blockHashCache[block]!;
      final cachedLogs = _logCache[oldHash] ?? [];
      
      // Mark logs as removed
      for (final log in cachedLogs) {
        removedLogs.add(Log(
          address: log.address,
          topics: log.topics,
          data: log.data,
          blockHash: log.blockHash,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          transactionIndex: log.transactionIndex,
          logIndex: log.logIndex,
          removed: true, // Mark as removed due to reorg
        ));
      }

      // Remove from caches
      _logCache.remove(oldHash);
      _blockHashCache.remove(block);
    }

    // Update with new block hash
    _blockHashCache[blockNumber] = newBlockHash;

    return removedLogs;
  }

  /// Updates the internal caches with a new log.
  void _updateCaches(Log log) {
    // Update block hash cache
    _blockHashCache[log.blockNumber] = log.blockHash;

    // Update log cache
    final blockLogs = _logCache[log.blockHash] ?? [];
    blockLogs.add(log);
    _logCache[log.blockHash] = blockLogs;

    // Cleanup old entries if cache is too large
    _cleanupCaches();
  }

  /// Cleans up old cache entries to maintain size limits.
  void _cleanupCaches() {
    if (_blockHashCache.length > maxCacheSize) {
      // Remove oldest entries
      final sortedBlocks = _blockHashCache.keys.toList()..sort();
      final toRemove = sortedBlocks.take(_blockHashCache.length - maxCacheSize);

      for (final block in toRemove) {
        final hash = _blockHashCache.remove(block);
        if (hash != null) {
          _logCache.remove(hash);
        }
      }
    }
  }

  /// Validates the consistency of a block range.
  Future<List<ReorgEvent>> validateBlockRange(BigInt fromBlock, BigInt toBlock) async {
    final events = <ReorgEvent>[];

    for (var block = fromBlock; block <= toBlock; block += BigInt.one) {
      final cachedHash = _blockHashCache[block];
      if (cachedHash != null) {
        // Verify the block hash is still valid
        try {
          final currentBlock = await subscriber.publicClient.getBlockByNumber('0x${block.toRadixString(16)}');
          if (currentBlock != null && currentBlock.hash != cachedHash) {
            // Reorganization detected
            final removedLogs = await _handleReorganization(block, currentBlock.hash);
            events.add(ReorgEvent.reorganization(block, removedLogs, []));
          }
        } catch (e) {
          // Block might not exist anymore
          final removedLogs = _logCache[cachedHash] ?? [];
          events.add(ReorgEvent.reorganization(block, removedLogs, []));
        }
      }
    }

    return events;
  }

  /// Gets the confirmation count for a log.
  Future<int> getConfirmationCount(Log log) async {
    final currentBlock = await subscriber.publicClient.getBlockNumber();
    return (currentBlock - log.blockNumber).toInt();
  }

  /// Checks if a log is considered final (has enough confirmations).
  Future<bool> isLogFinal(Log log) async {
    final confirmations = await getConfirmationCount(log);
    return confirmations >= confirmationDepth;
  }

  /// Clears all caches.
  void clearCaches() {
    _logCache.clear();
    _blockHashCache.clear();
  }

  /// Gets cache statistics.
  Map<String, int> getCacheStats() {
    return {
      'blockHashCacheSize': _blockHashCache.length,
      'logCacheSize': _logCache.length,
      'totalCachedLogs': _logCache.values.fold(0, (sum, logs) => sum + logs.length),
    };
  }
}

/// Represents different types of reorganization events.
class ReorgEvent {
  /// The type of event.
  final ReorgEventType type;

  /// The affected log.
  final Log? log;

  /// The block number where reorganization occurred.
  final BigInt? blockNumber;

  /// Logs that were removed due to reorganization.
  final List<Log> removedLogs;

  /// New logs that replaced the removed ones.
  final List<Log> newLogs;

  /// Number of confirmations (for pending logs).
  final int? confirmations;

  ReorgEvent._({
    required this.type,
    this.log,
    this.blockNumber,
    this.removedLogs = const [],
    this.newLogs = const [],
    this.confirmations,
  });

  /// Creates a confirmed log event.
  factory ReorgEvent.confirmed(Log log) {
    return ReorgEvent._(
      type: ReorgEventType.confirmed,
      log: log,
    );
  }

  /// Creates a pending log event.
  factory ReorgEvent.pending(Log log, int confirmations) {
    return ReorgEvent._(
      type: ReorgEventType.pending,
      log: log,
      confirmations: confirmations,
    );
  }

  /// Creates a removed log event.
  factory ReorgEvent.removed(Log log) {
    return ReorgEvent._(
      type: ReorgEventType.removed,
      log: log,
    );
  }

  /// Creates a reorganization event.
  factory ReorgEvent.reorganization(
    BigInt blockNumber,
    List<Log> removedLogs,
    List<Log> newLogs,
  ) {
    return ReorgEvent._(
      type: ReorgEventType.reorganization,
      blockNumber: blockNumber,
      removedLogs: removedLogs,
      newLogs: newLogs,
    );
  }

  @override
  String toString() {
    switch (type) {
      case ReorgEventType.confirmed:
        return 'ReorgEvent.confirmed(log: ${log?.transactionHash})';
      case ReorgEventType.pending:
        return 'ReorgEvent.pending(log: ${log?.transactionHash}, confirmations: $confirmations)';
      case ReorgEventType.removed:
        return 'ReorgEvent.removed(log: ${log?.transactionHash})';
      case ReorgEventType.reorganization:
        return 'ReorgEvent.reorganization(block: $blockNumber, removed: ${removedLogs.length}, new: ${newLogs.length})';
    }
  }
}

/// Types of reorganization events.
enum ReorgEventType {
  /// Log has been confirmed with sufficient confirmations.
  confirmed,

  /// Log is pending confirmation.
  pending,

  /// Log was removed due to reorganization.
  removed,

  /// Chain reorganization detected.
  reorganization,
}