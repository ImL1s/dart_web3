import 'dart:async';

import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_provider/dart_web3_provider.dart';

import 'event_filter.dart';

/// Event subscriber for blockchain events.
class EventSubscriber {
  /// The public client for blockchain queries.
  final PublicClient publicClient;

  /// The WebSocket transport for subscriptions (optional).
  final WebSocketTransport? wsTransport;

  EventSubscriber(this.publicClient, [this.wsTransport]);

  /// Subscribes to events using WebSocket.
  /// 
  /// Requires a WebSocket transport to be configured.
  /// Returns a stream of logs matching the filter.
  Stream<Log> subscribe(EventFilter filter) {
    if (wsTransport == null) {
      throw StateError('WebSocket transport required for subscriptions');
    }

    return wsTransport!
        .subscribe('eth_subscribe', ['logs', filter.toJson()])
        .map((data) => Log.fromJson(data));
  }

  /// Polls for events using HTTP transport.
  /// 
  /// This method periodically queries for new events matching the filter.
  /// Returns a stream of logs with the specified polling interval.
  Stream<Log> poll(
    EventFilter filter, {
    Duration interval = const Duration(seconds: 5),
  }) async* {
    String? lastBlock;
    
    while (true) {
      try {
        // Get current block number
        final currentBlock = await publicClient.getBlockNumber();
        final currentBlockHex = '0x${currentBlock.toRadixString(16)}';

        // Create filter with updated block range
        final pollFilter = EventFilter(
          address: filter.address,
          topics: filter.topics,
          fromBlock: lastBlock ?? filter.fromBlock ?? 'latest',
          toBlock: currentBlockHex,
          blockHash: filter.blockHash,
        );

        // Get logs
        final logs = await publicClient.getLogs(LogFilter(
          address: pollFilter.address,
          topics: pollFilter.topics?.cast<String?>(),
          fromBlock: pollFilter.fromBlock,
          toBlock: pollFilter.toBlock,
        ));

        // Emit logs
        for (final log in logs) {
          yield log;
        }

        // Update last block
        lastBlock = currentBlockHex;

        // Wait for next interval
        await Future.delayed(interval);
      } catch (e) {
        // Continue polling on error
        await Future.delayed(interval);
      }
    }
  }

  /// Watches for new block numbers.
  /// 
  /// If WebSocket is available, uses subscription. Otherwise, polls.
  Stream<BigInt> watchBlockNumber({
    Duration interval = const Duration(seconds: 12),
  }) {
    if (wsTransport != null) {
      return wsTransport!
          .subscribe('eth_subscribe', ['newHeads'])
          .map((data) {
            final numberStr = data['number'] as String;
            // Remove 0x prefix if present and parse as hex
            final cleanHex = numberStr.startsWith('0x') ? numberStr.substring(2) : numberStr;
            return BigInt.parse(cleanHex, radix: 16);
          });
    } else {
      return Stream.periodic(interval)
          .asyncMap((_) => publicClient.getBlockNumber());
    }
  }

  /// Watches for pending transactions.
  /// 
  /// Requires WebSocket transport.
  Stream<String> watchPendingTransactions() {
    if (wsTransport == null) {
      throw StateError('WebSocket transport required for pending transactions');
    }

    return wsTransport!
        .subscribe('eth_subscribe', ['newPendingTransactions'])
        .map((data) {
          // Handle both string and map responses
          if (data.containsKey('txHash')) {
            return data['txHash'] as String;
          } else {
            // Assume the data itself is the transaction hash
            return data.toString();
          }
        });
  }

  /// Gets historical events matching the filter.
  Future<List<Log>> getEvents(
    EventFilter filter, {
    int? limit,
    bool ascending = true,
  }) async {
    final logs = await publicClient.getLogs(LogFilter(
      address: filter.address,
      topics: filter.topics?.cast<String?>(),
      fromBlock: filter.fromBlock,
      toBlock: filter.toBlock,
    ));

    // Sort logs
    if (!ascending) {
      logs.sort((a, b) => b.blockNumber.compareTo(a.blockNumber));
    } else {
      logs.sort((a, b) => a.blockNumber.compareTo(b.blockNumber));
    }

    // Apply limit
    if (limit != null && logs.length > limit) {
      return logs.take(limit).toList();
    }

    return logs;
  }

  /// Gets events with pagination.
  Future<List<Log>> getEventsPaginated(
    EventFilter filter, {
    required int page,
    required int pageSize,
    bool ascending = true,
  }) async {
    final allLogs = await getEvents(filter, ascending: ascending);
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allLogs.length);

    if (startIndex >= allLogs.length) {
      return [];
    }

    return allLogs.sublist(startIndex, endIndex);
  }

  /// Creates a filter ID for use with eth_getFilterChanges.
  Future<String> createFilter(EventFilter filter) async {
    return await publicClient.provider.call<String>('eth_newFilter', [filter.toJson()]);
  }

  /// Gets changes for a filter ID.
  Future<List<Log>> getFilterChanges(String filterId) async {
    final logs = await publicClient.provider.call<List<dynamic>>('eth_getFilterChanges', [filterId]);
    return logs.map((log) => Log.fromJson(log as Map<String, dynamic>)).toList();
  }

  /// Uninstalls a filter.
  Future<bool> uninstallFilter(String filterId) async {
    return await publicClient.provider.call<bool>('eth_uninstallFilter', [filterId]);
  }

  /// Disposes of the subscriber.
  void dispose() {
    wsTransport?.dispose();
  }
}