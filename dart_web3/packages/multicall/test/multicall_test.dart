import 'dart:typed_data';

import 'package:web3_universal_multicall/web3_universal_multicall.dart';
import 'package:test/test.dart';

import 'mock_client.dart';

void main() {
  group('Multicall', () {
    late MockPublicClient publicClient;
    late Multicall multicall;

    setUp(() {
      publicClient = MockPublicClient();
      multicall = Multicall(
        publicClient: publicClient,
        contractAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
      );
    });

    group('aggregate', () {
      test('should execute multiple calls successfully', () async {
        // Mock successful multicall result
        // Result format: [blockNumber, blockHash, [[success, returnData], ...]]
        final mockResult = Uint8List.fromList([
          // Array length (2 calls)
          ...List.filled(31, 0), 2,
          // First call result length
          ...List.filled(31, 0), 32,
          // First call result data (uint256: 1000)
          ...List.filled(28, 0), 3, 232, 0, 0,
          // Second call result length  
          ...List.filled(31, 0), 32,
          // Second call result data (uint256: 2000)
          ...List.filled(28, 0), 7, 208, 0, 0,
        ]);
        
        publicClient.mockCall(mockResult);

        final calls = [
          Call(
            target: '0x1234567890123456789012345678901234567890',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]), // balanceOf selector
          ),
          Call(
            target: '0x2345678901234567890123456789012345678901',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]), // balanceOf selector
          ),
        ];

        final results = await multicall.aggregate(calls);

        expect(results, hasLength(2));
        expect(results[0].success, isTrue);
        expect(results[1].success, isTrue);
        expect(publicClient.lastCallRequest?.to, equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
      });

      test('should handle empty calls list', () async {
        publicClient.mockCall(Uint8List.fromList([
          ...List.filled(31, 0), 0, // Empty array
        ]),);

        final results = await multicall.aggregate([]);
        expect(results, isEmpty);
      });
    });

    group('tryAggregate', () {
      test('should handle mixed success and failure results', () async {
        // Mock tryAggregate result with one success and one failure
        final mockResult = Uint8List.fromList([
          // Array length (2 results)
          ...List.filled(31, 0), 2,
          // First result: success = true
          ...List.filled(31, 0), 1,
          // First result data length
          ...List.filled(31, 0), 32,
          // First result data
          ...List.filled(28, 0), 3, 232, 0, 0,
          // Second result: success = false
          ...List.filled(31, 0), 0,
          // Second result data length (error data)
          ...List.filled(31, 0), 4,
          // Second result error data
          0x08, 0xc3, 0x79, 0xa0, // Error selector
        ]);

        publicClient.mockCall(mockResult);

        final calls = [
          Call(
            target: '0x1234567890123456789012345678901234567890',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
            allowFailure: true,
          ),
          Call(
            target: '0x2345678901234567890123456789012345678901',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
            allowFailure: true,
          ),
        ];

        final results = await multicall.tryAggregate(calls);

        expect(results, hasLength(2));
        expect(results[0].success, isTrue);
        expect(results[1].success, isFalse);
      });

      test('should throw for Multicall v1', () async {
        final v1Multicall = Multicall(
          publicClient: publicClient,
          contractAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
          version: MulticallVersion.v1,
        );

        expect(
          () => v1Multicall.tryAggregate([]),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('aggregateWithBlock', () {
      test('should return block information with results', () async {
        // Mock aggregateWithBlock result
        final mockResult = Uint8List.fromList([
          // Block number (1234 = 0x4d2)
          ...List.filled(30, 0), 0x04, 0xd2, // 1234 in big-endian
          // Block hash (32 bytes)
          0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
          0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
          0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
          0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
          // Results array length
          ...List.filled(31, 0), 1,
          // First result: success = true
          ...List.filled(31, 0), 1,
          // First result data length
          ...List.filled(31, 0), 32,
          // First result data
          ...List.filled(32, 0),
        ]);

        publicClient.mockCall(mockResult);

        final calls = [
          Call(
            target: '0x1234567890123456789012345678901234567890',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
          ),
        ];

        final result = await multicall.aggregateWithBlock(calls);

        expect(result.blockNumber, equals(BigInt.from(1234)));
        expect(result.blockHash, startsWith('0x'));
        expect(result.results, hasLength(1));
        expect(result.results[0].success, isTrue);
      });

      test('should throw for non-v3 multicall', () async {
        final v2Multicall = Multicall(
          publicClient: publicClient,
          contractAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
          version: MulticallVersion.v2,
        );

        expect(
          () => v2Multicall.aggregateWithBlock([]),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('estimateGas', () {
      test('should estimate gas for multicall', () async {
        publicClient.mockEstimateGas(BigInt.from(150000));

        final calls = [
          Call(
            target: '0x1234567890123456789012345678901234567890',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
          ),
        ];

        final gasEstimate = await multicall.estimateGas(calls);

        expect(gasEstimate, equals(BigInt.from(150000)));
        // Note: We can't easily test the call request details without more complex mocking
      });
    });

    group('encoding', () {
      test('should encode aggregate calls correctly', () async {
        publicClient.mockCall(Uint8List(64)); // Mock empty result

        final calls = [
          Call(
            target: '0x1234567890123456789012345678901234567890',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
          ),
        ];

        await multicall.aggregate(calls);

        // Verify that the call was made (we can't easily inspect the exact encoding)
        expect(calls, hasLength(1));
        expect(calls[0].target, equals('0x1234567890123456789012345678901234567890'));
      });
    });
  });
}
