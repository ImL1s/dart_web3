import 'package:web3_universal_abi/web3_universal_abi.dart';

/// Event filter for contract event subscriptions.
class EventFilter {
  EventFilter({
    this.address,
    this.topics,
    this.fromBlock,
    this.toBlock,
    this.event,
  });

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
