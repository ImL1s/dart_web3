import 'dart:typed_data';

import 'package:web3_universal_multicall/web3_universal_multicall.dart';
import 'package:test/test.dart';

void main() {
  group('MulticallError', () {
    group('UnsupportedMulticallError', () {
      test('should create error with chain ID and operation', () {
        const error = UnsupportedMulticallError(
          chainId: 999,
          operation: 'tryAggregate',
        );

        expect(error.chainId, equals(999));
        expect(error.operation, equals('tryAggregate'));
        expect(error.message, equals('tryAggregate is not supported on chain 999'));
        expect(error.toString(), contains('tryAggregate is not supported on chain 999'));
      });
    });

    group('MulticallExecutionError', () {
      test('should create error with call failures', () {
        final failures = [
          CallFailure(
            index: 0,
            target: '0x1234567890123456789012345678901234567890',
            callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
            errorData: Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0]),
            errorMessage: 'Execution reverted',
          ),
          CallFailure(
            index: 2,
            target: '0x2345678901234567890123456789012345678901',
            callData: Uint8List.fromList([0xa9, 0x05, 0x9c, 0xbb]),
            errorData: Uint8List.fromList([0x4e, 0x48, 0x7b, 0x71]),
            errorMessage: 'Panic: Arithmetic overflow',
          ),
        ];

        final error = MulticallExecutionError(failures);

        expect(error.failures, equals(failures));
        expect(error.message, equals('2 call(s) failed in multicall batch'));
        expect(error.toString(), contains('2 call(s) failed in multicall batch'));
      });
    });

    group('CallFailure', () {
      test('should create failure with all properties', () {
        final failure = CallFailure(
          index: 1,
          target: '0x1234567890123456789012345678901234567890',
          callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
          errorData: Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0]),
          errorMessage: 'Execution reverted',
        );

        expect(failure.index, equals(1));
        expect(failure.target, equals('0x1234567890123456789012345678901234567890'));
        expect(failure.callData, equals(Uint8List.fromList([0x70, 0xa0, 0x82, 0x31])));
        expect(failure.errorData, equals(Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0])));
        expect(failure.errorMessage, equals('Execution reverted'));
      });

      test('should handle missing error message', () {
        final failure = CallFailure(
          index: 0,
          target: '0x1234567890123456789012345678901234567890',
          callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
          errorData: Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0]),
        );

        expect(failure.errorMessage, isNull);
        expect(failure.toString(), contains('Unknown error'));
      });

      test('should format toString correctly', () {
        final failure = CallFailure(
          index: 2,
          target: '0x1234567890123456789012345678901234567890',
          callData: Uint8List.fromList([0x70, 0xa0, 0x82, 0x31]),
          errorData: Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0]),
          errorMessage: 'Custom error message',
        );

        final str = failure.toString();
        expect(str, contains('Call 2'));
        expect(str, contains('0x1234567890123456789012345678901234567890'));
        expect(str, contains('Custom error message'));
      });
    });

    group('MulticallEncodingError', () {
      test('should create error with operation', () {
        const error = MulticallEncodingError(operation: 'encode');

        expect(error.operation, equals('encode'));
        expect(error.cause, isNull);
        expect(error.message, equals('Failed to encode multicall data'));
        expect(error.toString(), contains('Failed to encode multicall data'));
      });

      test('should create error with operation and cause', () {
        final cause = Exception('Invalid ABI');
        final error = MulticallEncodingError(
          operation: 'decode',
          cause: cause,
        );

        expect(error.operation, equals('decode'));
        expect(error.cause, equals(cause));
        expect(error.message, equals('Failed to decode multicall data'));
        expect(error.toString(), contains('Failed to decode multicall data'));
        expect(error.toString(), contains('Exception: Invalid ABI'));
      });
    });

    group('MulticallContractError', () {
      test('should create error with chain ID and contract address', () {
        const error = MulticallContractError(
          chainId: 1337,
          contractAddress: '0x1234567890123456789012345678901234567890',
        );

        expect(error.chainId, equals(1337));
        expect(error.contractAddress, equals('0x1234567890123456789012345678901234567890'));
        expect(error.message, contains('Multicall contract not found'));
        expect(error.message, contains('0x1234567890123456789012345678901234567890'));
        expect(error.message, contains('chain 1337'));
      });
    });
  });
}
