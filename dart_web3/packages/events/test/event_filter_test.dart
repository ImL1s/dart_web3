import 'package:dart_web3_events/dart_web3_events.dart';
import 'package:test/test.dart';

void main() {
  group('EventFilter', () {
    test('should create basic filter', () {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
        toBlock: '0x10',
      );

      expect(filter.address, equals('0x1234567890123456789012345678901234567890'));
      expect(filter.topics, equals(['0xabcd']));
      expect(filter.fromBlock, equals('0x1'));
      expect(filter.toBlock, equals('0x10'));
    });

    test('should create filter for contract', () {
      final filter = EventFilter.forContract(
        '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: 'latest',
      );

      expect(filter.address, equals('0x1234567890123456789012345678901234567890'));
      expect(filter.topics, equals(['0xabcd']));
      expect(filter.fromBlock, equals('latest'));
    });

    test('should create filter for event', () {
      final filter = EventFilter.forEvent(
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        address: '0x1234567890123456789012345678901234567890',
        indexedParams: ['0x5678', '0x9abc'],
      );

      expect(filter.address, equals('0x1234567890123456789012345678901234567890'));
      expect(filter.topics, equals([
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
        '0x5678',
        '0x9abc',
      ]));
    });

    test('should create filter for block range', () {
      final filter = EventFilter.forBlockRange(
        '0x1',
        '0x10',
        address: '0x1234567890123456789012345678901234567890',
      );

      expect(filter.address, equals('0x1234567890123456789012345678901234567890'));
      expect(filter.fromBlock, equals('0x1'));
      expect(filter.toBlock, equals('0x10'));
    });

    test('should convert to JSON', () {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd', '0xefgh'],
        fromBlock: '0x1',
        toBlock: '0x10',
      );

      final json = filter.toJson();

      expect(json['address'], equals('0x1234567890123456789012345678901234567890'));
      expect(json['topics'], equals(['0xabcd', '0xefgh']));
      expect(json['fromBlock'], equals('0x1'));
      expect(json['toBlock'], equals('0x10'));
    });

    test('should create from JSON', () {
      final json = {
        'address': '0x1234567890123456789012345678901234567890',
        'topics': ['0xabcd', '0xefgh'],
        'fromBlock': '0x1',
        'toBlock': '0x10',
      };

      final filter = EventFilter.fromJson(json);

      expect(filter.address, equals('0x1234567890123456789012345678901234567890'));
      expect(filter.topics, equals(['0xabcd', '0xefgh']));
      expect(filter.fromBlock, equals('0x1'));
      expect(filter.toBlock, equals('0x10'));
    });

    test('should handle null values', () {
      final filter = EventFilter();

      expect(filter.address, isNull);
      expect(filter.topics, isNull);
      expect(filter.fromBlock, isNull);
      expect(filter.toBlock, isNull);
      expect(filter.blockHash, isNull);
    });

    test('should handle blockHash filter', () {
      final filter = EventFilter(
        blockHash: '0xabcdef1234567890',
        address: '0x1234567890123456789012345678901234567890',
      );

      final json = filter.toJson();

      expect(json['blockHash'], equals('0xabcdef1234567890'));
      expect(json['address'], equals('0x1234567890123456789012345678901234567890'));
      expect(json.containsKey('fromBlock'), isFalse);
      expect(json.containsKey('toBlock'), isFalse);
    });

    test('should test equality', () {
      final filter1 = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
      );

      final filter2 = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
      );

      final filter3 = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xefgh'],
        fromBlock: '0x1',
      );

      expect(filter1, equals(filter2));
      expect(filter1, isNot(equals(filter3)));
    });

    test('should have consistent hashCode', () {
      final filter1 = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
      );

      final filter2 = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
      );

      expect(filter1.hashCode, equals(filter2.hashCode));
    });

    test('should have meaningful toString', () {
      final filter = EventFilter(
        address: '0x1234567890123456789012345678901234567890',
        topics: ['0xabcd'],
        fromBlock: '0x1',
        toBlock: '0x10',
      );

      final str = filter.toString();
      expect(str, contains('EventFilter'));
      expect(str, contains('0x1234567890123456789012345678901234567890'));
      expect(str, contains('0xabcd'));
    });
  });
}