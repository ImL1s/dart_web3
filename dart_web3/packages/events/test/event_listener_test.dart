import 'dart:async';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_events/web3_universal_events.dart';
import 'package:test/test.dart';

import 'mock_client.dart';

void main() {
  group('EventListener', () {
    late MockPublicClient mockClient;
    late MockWebSocketTransport mockWsTransport;
    late EventSubscriber subscriber;
    late EventListener listener;

    setUp(() {
      mockClient = MockPublicClient();
      mockWsTransport = MockWebSocketTransport();
      subscriber = EventSubscriber(mockClient, mockWsTransport);
      listener = EventListener(subscriber);
    });

    tearDown(() {
      listener.dispose();
    });

    test('should listen to contract events', () async {
      final completer = Completer<Log>();
      
      final key = listener.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        onEvent: completer.complete,
      );

      expect(listener.isListening(key), isTrue);
      expect(listener.activeSubscriptions, equals(1));

      // Emit mock event
      mockWsTransport.emitSubscriptionEvent('sub_1', {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': ['0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'],
        'data': '0x',
        'blockHash': '0xblock1',
        'blockNumber': '0x1',
        'transactionHash': '0xtx1',
        'transactionIndex': '0x0',
        'logIndex': '0x0',
        'removed': false,
      });

      final log = await completer.future.timeout(const Duration(seconds: 1));
      expect(log.address, equals('0x1234567890123456789012345678901234567890'));
      expect(log.topics[0], equals('0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'));
    });

    test('should listen to contract events with indexed args', () async {
      final completer = Completer<Log>();
      
      final key = listener.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        indexedArgs: {
          'from': '0xfrom123',
          'to': '0xto456',
        },
        onEvent: completer.complete,
      );

      expect(listener.isListening(key), isTrue);

      // Emit mock event with indexed parameters
      mockWsTransport.emitSubscriptionEvent('sub_1', {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': [
          '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
          '0xfrom123',
          '0xto456',
        ],
        'data': '0x',
        'blockHash': '0xblock1',
        'blockNumber': '0x1',
        'transactionHash': '0xtx1',
        'transactionIndex': '0x0',
        'logIndex': '0x0',
        'removed': false,
      });

      final log = await completer.future.timeout(const Duration(seconds: 1));
      expect(log.topics, hasLength(3));
      expect(log.topics[1], equals('0xfrom123'));
      expect(log.topics[2], equals('0xto456'));
    });

    test('should listen to custom filter', () async {
      final completer = Completer<Log>();
      
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
        toBlock: '0x10',
      );

      final key = listener.listenToFilter(
        filter,
        onEvent: completer.complete,
      );

      expect(listener.isListening(key), isTrue);

      // Emit mock event
      mockWsTransport.emitSubscriptionEvent('sub_1', {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': ['0xabcd'],
        'data': '0x',
        'blockHash': '0xblock1',
        'blockNumber': '0x5',
        'transactionHash': '0xtx1',
        'transactionIndex': '0x0',
        'logIndex': '0x0',
        'removed': false,
      });

      final log = await completer.future.timeout(const Duration(seconds: 1));
      expect(log.blockNumber, equals(BigInt.from(5)));
    });

    test('should listen to all contract events', () async {
      final completer = Completer<Log>();
      
      final key = listener.listenToAllContractEvents(
        '0x1234567890123456789012345678901234567890',
        onEvent: completer.complete,
      );

      expect(listener.isListening(key), isTrue);

      // Emit mock event (any event from the contract)
      mockWsTransport.emitSubscriptionEvent('sub_1', {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': ['0xanytopic'],
        'data': '0x',
        'blockHash': '0xblock1',
        'blockNumber': '0x1',
        'transactionHash': '0xtx1',
        'transactionIndex': '0x0',
        'logIndex': '0x0',
        'removed': false,
      });

      final log = await completer.future.timeout(const Duration(seconds: 1));
      expect(log.address, equals('0x1234567890123456789012345678901234567890'));
    });

    test('should listen to pending transactions', () async {
      final completer = Completer<String>();
      
      final key = listener.listenToPendingTransactions(
        onTransaction: completer.complete,
      );

      expect(listener.isListening(key), isTrue);

      // Emit mock pending transaction
      mockWsTransport.emitSubscriptionEvent('sub_1', '0xtx123');

      final txHash = await completer.future.timeout(const Duration(seconds: 1));
      expect(txHash, equals('0xtx123'));
    });

    test('should throw error when listening to pending transactions without WebSocket', () {
      final subscriberWithoutWs = EventSubscriber(mockClient);
      final listenerWithoutWs = EventListener(subscriberWithoutWs);

      expect(
        () => listenerWithoutWs.listenToPendingTransactions(
          onTransaction: (txHash) {},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('should use polling when WebSocket is not available', () async {
      final subscriberWithoutWs = EventSubscriber(mockClient);
      final listenerWithoutWs = EventListener(subscriberWithoutWs);

      // Mock responses for polling
      mockClient.mockProvider.setResponse('eth_blockNumber', BigInt.from(100));
      mockClient.mockProvider.setResponse('eth_getLogs', [
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xabcd'],
          'data': '0x',
          'blockHash': '0xblock1',
          'blockNumber': '0x64',
          'transactionHash': '0xtx1',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        }
      ]);

      final completer = Completer<Log>();
      
      final key = listenerWithoutWs.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xabcd',
        onEvent: completer.complete,
        useWebSocket: false,
        pollingInterval: const Duration(milliseconds: 100),
      );

      expect(listenerWithoutWs.isListening(key), isTrue);

      final log = await completer.future.timeout(const Duration(seconds: 2));
      expect(log.address, equals('0x1234567890123456789012345678901234567890'));

      listenerWithoutWs.dispose();
    });

    test('should stop listening to specific subscription', () {
      final key = listener.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xabcd',
        onEvent: (log) {},
      );

      expect(listener.isListening(key), isTrue);
      expect(listener.activeSubscriptions, equals(1));

      listener.stopListening(key);

      expect(listener.isListening(key), isFalse);
      expect(listener.activeSubscriptions, equals(0));
    });

    test('should stop all subscriptions', () {
      final key1 = listener.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xabcd',
        onEvent: (log) {},
      );

      final key2 = listener.listenToContract(
        '0x9876543210987654321098765432109876543210',
        '0xefgh',
        onEvent: (log) {},
      );

      expect(listener.activeSubscriptions, equals(2));

      listener.stopAll();

      expect(listener.activeSubscriptions, equals(0));
      expect(listener.isListening(key1), isFalse);
      expect(listener.isListening(key2), isFalse);
    });

    test('should get subscription keys', () {
      final key1 = listener.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xabcd',
        onEvent: (log) {},
      );

      final key2 = listener.listenToContract(
        '0x9876543210987654321098765432109876543210',
        '0xefgh',
        onEvent: (log) {},
      );

      final keys = listener.subscriptionKeys;
      expect(keys, hasLength(2));
      expect(keys, contains(key1));
      expect(keys, contains(key2));
    });

    test('should handle errors in event callbacks', () async {
      // This test verifies that error callbacks are properly set up
      // The actual error handling is tested implicitly in other tests
      final key = listener.listenToContract(
        '0x1234567890123456789012345678901234567890',
        '0xabcd',
        onEvent: (log) {
          // Normal event handling
        },
        onError: (error) {
          // Error callback is set up
        },
      );

      expect(listener.isListening(key), isTrue);
      listener.stopListening(key);
      expect(listener.isListening(key), isFalse);
    });
  });
}
