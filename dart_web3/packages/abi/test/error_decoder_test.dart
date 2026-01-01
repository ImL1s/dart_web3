import 'package:dart_web3_abi/dart_web3_abi.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorDecoder', () {
    group('decode standard errors', () {
      test('decodes Error(string)', () {
        final decoder = ErrorDecoder();

        // Error("Insufficient balance")
        // Selector: 0x08c379a0
        // Encoded string: offset(32) + length(20) + "Insufficient balance"
        const data = '0x08c379a0'
            '0000000000000000000000000000000000000000000000000000000000000020'
            '0000000000000000000000000000000000000000000000000000000000000014'
            '496e73756666696369656e742062616c616e6365000000000000000000000000';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.name, equals('Error'));
        expect(error.selector, equals('0x08c379a0'));
        expect(error.args[0], equals('Insufficient balance'));
        expect(error.namedArgs?['message'], equals('Insufficient balance'));
      });

      test('decodes Panic(uint256) - assert failed', () {
        final decoder = ErrorDecoder();

        // Panic(0x01) - Assert failed
        const data = '0x4e487b71'
            '0000000000000000000000000000000000000000000000000000000000000001';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.name, equals('Panic'));
        expect(error.selector, equals('0x4e487b71'));
        expect(error.namedArgs?['code'], equals(1));
        expect(error.namedArgs?['reason'], equals('Assert failed'));
      });

      test('decodes Panic(uint256) - arithmetic overflow', () {
        final decoder = ErrorDecoder();

        // Panic(0x11) - Arithmetic overflow
        const data = '0x4e487b71'
            '0000000000000000000000000000000000000000000000000000000000000011';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.name, equals('Panic'));
        expect(error.namedArgs?['code'], equals(0x11));
        expect(error.namedArgs?['reason'], equals('Arithmetic overflow/underflow'));
      });

      test('decodes Panic(uint256) - division by zero', () {
        final decoder = ErrorDecoder();

        // Panic(0x12) - Division by zero
        const data = '0x4e487b71'
            '0000000000000000000000000000000000000000000000000000000000000012';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.namedArgs?['reason'], equals('Division by zero'));
      });
    });

    group('decode custom errors', () {
      test('decodes custom error from signature', () {
        final decoder = ErrorDecoder([
          ErrorDefinition.fromSignature('InsufficientBalance(address account, uint256 balance)'),
        ]);

        // InsufficientBalance(0x1234...5678, 1000)
        // First calculate the selector
        final errorDef = ErrorDefinition.fromSignature('InsufficientBalance(address,uint256)');

        // Construct data with selector + encoded params
        final data = '${errorDef.selector}'
            '0000000000000000000000001234567890123456789012345678901234567890'
            '00000000000000000000000000000000000000000000000000000000000003e8';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.name, equals('InsufficientBalance'));
        expect(error.args.length, equals(2));
        expect(error.namedArgs?['account'], equals('0x1234567890123456789012345678901234567890'));
        expect(error.namedArgs?['balance'], equals(BigInt.from(1000)));
      });

      test('decodes custom error added from ABI', () {
        final decoder = ErrorDecoder();
        decoder.addErrorsFromAbi([
          {
            'type': 'error',
            'name': 'Unauthorized',
            'inputs': [
              {'name': 'caller', 'type': 'address'},
            ],
          },
        ]);

        // Calculate selector for Unauthorized(address)
        final selectorBytes = AbiEncoder.getFunctionSelector('Unauthorized(address)');
        final selector = '0x${selectorBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
        final data = '$selector'
            '000000000000000000000000abcdef1234567890abcdef1234567890abcdef12';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.name, equals('Unauthorized'));
        expect(error.namedArgs?['caller'], equals('0xabcdef1234567890abcdef1234567890abcdef12'));
      });

      test('handles unknown error selectors', () {
        final decoder = ErrorDecoder();

        // Unknown selector
        const data = '0xdeadbeef'
            '0000000000000000000000000000000000000000000000000000000000000001';

        final error = decoder.decode(data);

        expect(error, isNotNull);
        expect(error!.name, equals('UnknownError'));
        expect(error.selector, equals('0xdeadbeef'));
      });
    });

    group('ErrorDefinition', () {
      test('calculates correct selector', () {
        final error = ErrorDefinition.fromSignature('InsufficientBalance(address,uint256)');
        // keccak256("InsufficientBalance(address,uint256)")[0:4]
        expect(error.selector.length, equals(10)); // 0x + 8 hex chars
      });

      test('parses complex signature', () {
        final error = ErrorDefinition.fromSignature(
            'ComplexError(address indexed sender, (uint256,bytes32) data, string message)');

        expect(error.name, equals('ComplexError'));
        expect(error.types.length, equals(3));
        expect(error.names, equals(['sender', 'data', 'message']));
      });
    });

    group('decodeFromRpcError', () {
      test('extracts error data from RPC response', () {
        final decoder = ErrorDecoder();

        // "Not allowed" = 11 bytes = 0x0b
        final rpcError = {
          'code': 3,
          'message': 'execution reverted',
          'data': '0x08c379a0'
              '0000000000000000000000000000000000000000000000000000000000000020'
              '000000000000000000000000000000000000000000000000000000000000000b'
              '4e6f7420616c6c6f776564000000000000000000000000000000000000000000',
        };

        final error = decoder.decodeFromRpcError(rpcError);

        expect(error, isNotNull);
        expect(error!.name, equals('Error'));
        expect(error.namedArgs?['message'], equals('Not allowed'));
      });

      test('handles nested error data', () {
        final decoder = ErrorDecoder();

        final rpcError = {
          'code': 3,
          'message': 'execution reverted',
          'error': {
            'data': '0x08c379a0'
                '0000000000000000000000000000000000000000000000000000000000000020'
                '0000000000000000000000000000000000000000000000000000000000000005'
                '4572726f72000000000000000000000000000000000000000000000000000000',
          },
        };

        final error = decoder.decodeFromRpcError(rpcError);

        expect(error, isNotNull);
        expect(error!.namedArgs?['message'], equals('Error'));
      });
    });

    group('DecodedRpcError', () {
      test('creates from RPC error with decoding', () {
        final rpcError = DecodedRpcError.fromRpcError({
          'code': 3,
          'message': 'execution reverted',
          'data': '0x4e487b71'
              '0000000000000000000000000000000000000000000000000000000000000012',
        });

        expect(rpcError.code, equals(3));
        expect(rpcError.decoded, isNotNull);
        expect(rpcError.decoded!.name, equals('Panic'));
        expect(rpcError.reason, equals('Division by zero'));
      });

      test('provides human-readable reason', () {
        // "Transfer failed" = 15 bytes = 0x0f
        final rpcError = DecodedRpcError.fromRpcError({
          'code': 3,
          'message': 'execution reverted',
          'data': '0x08c379a0'
              '0000000000000000000000000000000000000000000000000000000000000020'
              '000000000000000000000000000000000000000000000000000000000000000f'
              '5472616e73666572206661696c65640000000000000000000000000000000000',
        });

        expect(rpcError.reason, equals('Transfer failed'));
      });
    });
  });
}
