import 'dart:async';

import 'package:web3_universal_client/web3_universal_client.dart'
    hide EventFilter;

import 'event_filter.dart';
import 'event_subscriber.dart';

/// Event listener for managing contract event subscriptions.
class EventListener {
  EventListener(this.subscriber);

  /// The event subscriber.
  final EventSubscriber subscriber;

  /// Active subscriptions.
  final Map<String, StreamSubscription<Log>> _subscriptions = {};

  /// Active filter subscriptions.
  final Map<String, StreamSubscription<Log>> _filterSubscriptions = {};

  /// Active non-log subscriptions (for blocks, pending transactions, etc.).
  final Map<String, StreamSubscription<dynamic>> _otherSubscriptions = {};

  /// Listens to contract events.
  ///
  /// [contractAddress] - The contract address to listen to
  /// [eventSignature] - The event signature (topic0)
  /// [indexedArgs] - Optional indexed parameters for filtering
  /// [onEvent] - Callback when an event is received
  /// [onError] - Optional error callback
  /// [useWebSocket] - Whether to use WebSocket subscription (true) or polling (false)
  /// [pollingInterval] - Polling interval when not using WebSocket
  ///
  /// Returns a subscription key that can be used to stop listening.
  String listenToContract(
    String contractAddress,
    String eventSignature, {
    required void Function(Log) onEvent,
    Map<String, dynamic>? indexedArgs,
    void Function(Object)? onError,
    bool useWebSocket = true,
    Duration pollingInterval = const Duration(seconds: 5),
  }) {
    // Create topics array
    final topics = <dynamic>[eventSignature];
    if (indexedArgs != null) {
      // Add indexed parameters as additional topics
      for (final value in indexedArgs.values) {
        topics.add(value);
      }
    }

    final filter = EventFilter(
      address: contractAddress,
      topics: topics,
    );

    final key =
        '${contractAddress}_${eventSignature}_${DateTime.now().millisecondsSinceEpoch}';

    StreamSubscription<Log> subscription;
    if (useWebSocket && subscriber.wsTransport != null) {
      subscription = subscriber.subscribe(filter).listen(
            onEvent,
            onError: onError,
          );
    } else {
      subscription = subscriber.poll(filter, interval: pollingInterval).listen(
            onEvent,
            onError: onError,
          );
    }

    _subscriptions[key] = subscription;
    return key;
  }

  /// Listens to events matching a custom filter.
  ///
  /// [filter] - The event filter
  /// [onEvent] - Callback when an event is received
  /// [onError] - Optional error callback
  /// [useWebSocket] - Whether to use WebSocket subscription (true) or polling (false)
  /// [pollingInterval] - Polling interval when not using WebSocket
  ///
  /// Returns a subscription key that can be used to stop listening.
  String listenToFilter(
    EventFilter filter, {
    required void Function(Log) onEvent,
    void Function(Object)? onError,
    bool useWebSocket = true,
    Duration pollingInterval = const Duration(seconds: 5),
  }) {
    final key = 'filter_${DateTime.now().millisecondsSinceEpoch}';

    StreamSubscription<Log> subscription;
    if (useWebSocket && subscriber.wsTransport != null) {
      subscription = subscriber.subscribe(filter).listen(
            onEvent,
            onError: onError,
          );
    } else {
      subscription = subscriber.poll(filter, interval: pollingInterval).listen(
            onEvent,
            onError: onError,
          );
    }

    _filterSubscriptions[key] = subscription;
    return key;
  }

  /// Listens to all events from a contract.
  ///
  /// [contractAddress] - The contract address to listen to
  /// [onEvent] - Callback when an event is received
  /// [onError] - Optional error callback
  /// [useWebSocket] - Whether to use WebSocket subscription (true) or polling (false)
  /// [pollingInterval] - Polling interval when not using WebSocket
  ///
  /// Returns a subscription key that can be used to stop listening.
  String listenToAllContractEvents(
    String contractAddress, {
    required void Function(Log) onEvent,
    void Function(Object)? onError,
    bool useWebSocket = true,
    Duration pollingInterval = const Duration(seconds: 5),
  }) {
    final filter = EventFilter(address: contractAddress);
    return listenToFilter(
      filter,
      onEvent: onEvent,
      onError: onError,
      useWebSocket: useWebSocket,
      pollingInterval: pollingInterval,
    );
  }

  /// Listens to new blocks.
  ///
  /// [onBlock] - Callback when a new block is detected
  /// [onError] - Optional error callback
  /// [pollingInterval] - Polling interval when not using WebSocket
  ///
  /// Returns a subscription key that can be used to stop listening.
  String listenToBlocks({
    required void Function(BigInt blockNumber) onBlock,
    void Function(Object)? onError,
    Duration pollingInterval = const Duration(seconds: 12),
  }) {
    final key = 'blocks_${DateTime.now().millisecondsSinceEpoch}';

    final subscription =
        subscriber.watchBlockNumber(interval: pollingInterval).listen(
              onBlock,
              onError: onError,
            );

    _otherSubscriptions[key] = subscription;
    return key;
  }

  /// Listens to pending transactions.
  ///
  /// Requires WebSocket transport.
  ///
  /// [onTransaction] - Callback when a pending transaction is detected
  /// [onError] - Optional error callback
  ///
  /// Returns a subscription key that can be used to stop listening.
  String listenToPendingTransactions({
    required void Function(String txHash) onTransaction,
    void Function(Object)? onError,
  }) {
    if (subscriber.wsTransport == null) {
      throw StateError('WebSocket transport required for pending transactions');
    }

    final key = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    final subscription = subscriber.watchPendingTransactions().listen(
          onTransaction,
          onError: onError,
        );

    _otherSubscriptions[key] = subscription;
    return key;
  }

  /// Stops listening to events with the given key.
  void stopListening(String key) {
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);

    _filterSubscriptions[key]?.cancel();
    _filterSubscriptions.remove(key);

    _otherSubscriptions[key]?.cancel();
    _otherSubscriptions.remove(key);
  }

  /// Stops all active subscriptions.
  void stopAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    for (final subscription in _filterSubscriptions.values) {
      subscription.cancel();
    }
    _filterSubscriptions.clear();

    for (final subscription in _otherSubscriptions.values) {
      subscription.cancel();
    }
    _otherSubscriptions.clear();
  }

  /// Gets the number of active subscriptions.
  int get activeSubscriptions =>
      _subscriptions.length +
      _filterSubscriptions.length +
      _otherSubscriptions.length;

  /// Gets all active subscription keys.
  List<String> get subscriptionKeys => [
        ..._subscriptions.keys,
        ..._filterSubscriptions.keys,
        ..._otherSubscriptions.keys,
      ];

  /// Checks if a subscription is active.
  bool isListening(String key) {
    return _subscriptions.containsKey(key) ||
        _filterSubscriptions.containsKey(key) ||
        _otherSubscriptions.containsKey(key);
  }

  /// Disposes of the listener and stops all subscriptions.
  void dispose() {
    stopAll();
    subscriber.dispose();
  }
}
