import 'package:dart_web3_abi/dart_web3_abi.dart';

/// Event filter for contract event subscriptions.
class EventFilter {
  /// The contract address to filter by.
  final String? address;

  /// The topics to filter by.
  final List<String?>? topics;

  /// The starting block (inclusive).
  final String? fromBlock;

  /// The ending block (inclusive).
  final String? toBlock;

  /// The event definition (for decoding).
  final AbiEvent? event;

  EventFilter({
    this.address,
    this.topics,
    this.fromBlock,
    this.toBlock,
    this.event,
  });

  /// Converts to JSON for RPC calls.
  Map<String, dynamic> toJson() {
    return {
      if (address != null) 'address': address,
      if (topics != null) 'topics': topics,
      if (fromBlock != null) 'fromBlock': fromBlock,
      if (toBlock != null) 'toBlock': toBlock,
    };
  }
}