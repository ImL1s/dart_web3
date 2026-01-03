
import 'package:web3_universal_events/web3_universal_events.dart';
import 'package:test/test.dart';

import 'mock_client.dart';

void main() {
  group('EventSubscriber', () {
    late MockPublicClient mockClient;
    late MockWebSocketTransport mockWsTransport;
    late EventSubscriber subscriber;

    setUp(() {
      mockClient = MockPublicClient();
      mockWsTransport = MockWebSocketTransport();
      subscriber = EventSubscriber(mockClient, mockWsTransport);
    });

    tearDown(() {
      subscriber.dispose();
    });

    test('should subscribe to events via WebSocket', () async {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
      );

      // Mock subscription response
      mockWsTransport.emitSubscriptionEvent('sub_1', {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': ['0xabcd'],
        'data': '0x',
        'blockHash': '0xblock1',
        'blockNumber': '0x1',
        'transactionHash': '0xtx1',
        'transactionIndex': '0x0',
        'logIndex': '0x0',
        'removed': false,
      });

      final stream = subscriber.subscribe(filter);
      final logs = await stream.take(1).toList();

      expect(logs, hasLength(1));
      expect(logs[0].address, equals('0x1234567890123456789012345678901234567890'));
      expect(logs[0].topics, equals(['0xabcd']));
    });

    test('should throw error when subscribing without WebSocket', () {
      final subscriberWithoutWs = EventSubscriber(mockClient);
      final filter = EventFilter(address: '0x1234567890123456789012345678901234567890');

      expect(
        () => subscriberWithoutWs.subscribe(filter),
        throwsA(isA<StateError>()),
      );
    });

    test('should poll for events via HTTP', () async {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
      );

      // Mock responses
      mockClient.mockProvider.setResponse('eth_blockNumber', BigInt.from(100));
      mockClient.mockProvider.setResponse('eth_getLogs', [
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xabcd'],
          'data': '0x',
          'blockHash': '0xblock1',
          'blockNumber': '0x64', // 100 in hex
          'transactionHash': '0xtx1',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        }
      ]);

      final stream = subscriber.poll(filter, interval: const Duration(milliseconds: 100));
      final logs = await stream.take(1).toList();

      expect(logs, hasLength(1));
      expect(logs[0].address, equals('0x1234567890123456789012345678901234567890'));
    });

    test('should watch block numbers via WebSocket', () async {
      // Mock new head event
      mockWsTransport.emitSubscriptionEvent('sub_1', {
        'number': '0x64', // 100 in hex
      });

      final stream = subscriber.watchBlockNumber();
      final blockNumbers = await stream.take(1).toList();

      expect(blockNumbers, hasLength(1));
      expect(blockNumbers[0], equals(BigInt.from(100)));
    });

    test('should watch block numbers via polling', () async {
      final subscriberWithoutWs = EventSubscriber(mockClient);
      
      // Mock block number response
      mockClient.mockProvider.setResponse('eth_blockNumber', BigInt.from(100));

      final stream = subscriberWithoutWs.watchBlockNumber(
        interval: const Duration(milliseconds: 100),
      );
      final blockNumbers = await stream.take(1).toList();

      expect(blockNumbers, hasLength(1));
      expect(blockNumbers[0], equals(BigInt.from(100)));
    });

    test('should watch pending transactions', () async {
      // Mock pending transaction event
      mockWsTransport.emitSubscriptionEvent('sub_1', '0xtx123');

      final stream = subscriber.watchPendingTransactions();
      final txHashes = await stream.take(1).toList();

      expect(txHashes, hasLength(1));
      expect(txHashes[0], equals('0xtx123'));
    });

    test('should throw error when watching pending transactions without WebSocket', () {
      final subscriberWithoutWs = EventSubscriber(mockClient);

      expect(
        subscriberWithoutWs.watchPendingTransactions,
        throwsA(isA<StateError>()),
      );
    });

    test('should get historical events', () async {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        fromBlock: '0x1',
        toBlock: '0x10',
      );

      // Mock logs response
      mockClient.mockProvider.setResponse('eth_getLogs', [
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xabcd'],
          'data': '0x',
          'blockHash': '0xblock1',
          'blockNumber': '0x5',
          'transactionHash': '0xtx1',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        },
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xefgh'],
          'data': '0x',
          'blockHash': '0xblock2',
          'blockNumber': '0xa',
          'transactionHash': '0xtx2',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        }
      ]);

      final logs = await subscriber.getEvents(filter);

      expect(logs, hasLength(2));
      expect(logs[0].blockNumber, equals(BigInt.from(5)));
      expect(logs[1].blockNumber, equals(BigInt.from(10)));
    });

    test('should get events with limit', () async {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
      );

      // Mock logs response with 3 logs
      mockClient.mockProvider.setResponse('eth_getLogs', [
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xabcd'],
          'data': '0x',
          'blockHash': '0xblock1',
          'blockNumber': '0x1',
          'transactionHash': '0xtx1',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        },
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xefgh'],
          'data': '0x',
          'blockHash': '0xblock2',
          'blockNumber': '0x2',
          'transactionHash': '0xtx2',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        },
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xijkl'],
          'data': '0x',
          'blockHash': '0xblock3',
          'blockNumber': '0x3',
          'transactionHash': '0xtx3',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        }
      ]);

      final logs = await subscriber.getEvents(filter, limit: 2);

      expect(logs, hasLength(2));
    });

    test('should get events with pagination', () async {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
      );

      // Mock logs response with 5 logs
      final mockLogs = List.generate(5, (i) => {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': ['0xabcd'],
        'data': '0x',
        'blockHash': '0xblock${i + 1}',
        'blockNumber': '0x${(i + 1).toRadixString(16)}',
        'transactionHash': '0xtx${i + 1}',
        'transactionIndex': '0x0',
        'logIndex': '0x0',
        'removed': false,
      },);

      mockClient.mockProvider.setResponse('eth_getLogs', mockLogs);

      final logs = await subscriber.getEventsPaginated(
        filter,
        page: 1,
        pageSize: 2,
      );

      expect(logs, hasLength(2));
      expect(logs[0].blockNumber, equals(BigInt.from(3)));
      expect(logs[1].blockNumber, equals(BigInt.from(4)));
    });

    test('should create and manage filters', () async {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
      );

      // Mock filter creation
      mockClient.mockProvider.setResponse('eth_newFilter', 'filter_123');

      final filterId = await subscriber.createFilter(filter);
      expect(filterId, equals('filter_123'));

      // Mock filter changes
      mockClient.mockProvider.setResponse('eth_getFilterChanges', [
        {
          'address': '0x1234567890123456789012345678901234567890',
          'topics': ['0xabcd'],
          'data': '0x',
          'blockHash': '0xblock1',
          'blockNumber': '0x1',
          'transactionHash': '0xtx1',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
          'removed': false,
        }
      ]);

      final changes = await subscriber.getFilterChanges(filterId);
      expect(changes, hasLength(1));

      // Mock filter uninstall
      mockClient.mockProvider.setResponse('eth_uninstallFilter', true);

      final uninstalled = await subscriber.uninstallFilter(filterId);
      expect(uninstalled, isTrue);
    });
  });
}
