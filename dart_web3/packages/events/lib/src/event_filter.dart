import 'package:meta/meta.dart';

/// Event filter for subscribing to blockchain events.
@immutable
class EventFilter {
  EventFilter({
    this.address,
    this.topics,
    this.fromBlock,
    this.toBlock,
    this.blockHash,
  });

  /// Creates a filter for a specific contract address.
  EventFilter.forContract(
    String contractAddress, {
    this.topics,
    this.fromBlock,
    this.toBlock,
    this.blockHash,
  }) : address = contractAddress;

  /// Creates a filter for a specific event signature.
  EventFilter.forEvent(
    String eventSignature, {
    this.address,
    List<dynamic>? indexedParams,
    this.fromBlock,
    this.toBlock,
    this.blockHash,
  }) : topics = [
          eventSignature,
          if (indexedParams != null) ...indexedParams,
        ];

  /// Creates a filter for a specific block range.
  EventFilter.forBlockRange(
    String from,
    String to, {
    this.address,
    this.topics,
    this.blockHash,
  })  : fromBlock = from,
        toBlock = to;

  /// Creates an EventFilter from JSON.
  factory EventFilter.fromJson(Map<String, dynamic> json) {
    return EventFilter(
      address: json['address'] as String?,
      topics: json['topics'] as List<dynamic>?,
      fromBlock: json['fromBlock'] as String?,
      toBlock: json['toBlock'] as String?,
      blockHash: json['blockHash'] as String?,
    );
  }

  /// Contract address to filter by (optional).
  final String? address;

  /// List of topics to filter by (optional).
  /// Each topic can be null (any topic), a string (exact match), or a list of strings (OR match).
  final List<dynamic>? topics;

  /// Starting block number or tag ('earliest', 'latest', 'pending').
  final String? fromBlock;

  /// Ending block number or tag ('earliest', 'latest', 'pending').
  final String? toBlock;

  /// Block hash to filter by (alternative to fromBlock/toBlock).
  final String? blockHash;

  /// Converts the filter to JSON format for RPC calls.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (address != null) {
      json['address'] = address;
    }

    if (topics != null) {
      json['topics'] = topics;
    }

    if (blockHash != null) {
      json['blockHash'] = blockHash;
    } else {
      if (fromBlock != null) {
        json['fromBlock'] = fromBlock;
      }
      if (toBlock != null) {
        json['toBlock'] = toBlock;
      }
    }

    return json;
  }

  @override
  String toString() {
    return 'EventFilter(address: $address, topics: $topics, fromBlock: $fromBlock, toBlock: $toBlock, blockHash: $blockHash)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventFilter &&
        other.address == address &&
        _listEquals(other.topics, topics) &&
        other.fromBlock == fromBlock &&
        other.toBlock == toBlock &&
        other.blockHash == blockHash;
  }

  @override
  int get hashCode {
    return Object.hash(
      address,
      _listHashCode(topics),
      fromBlock,
      toBlock,
      blockHash,
    );
  }

  /// Helper method to compare lists.
  bool _listEquals(List<dynamic>? a, List<dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to compute hash code for lists.
  int _listHashCode(List<dynamic>? list) {
    if (list == null) return 0;
    var hash = 0;
    for (final item in list) {
      hash = hash ^ item.hashCode;
    }
    return hash;
  }
}
