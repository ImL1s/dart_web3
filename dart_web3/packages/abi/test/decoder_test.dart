import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:test/test.dart';

void main() {
  group('AbiDecoder Tests', () {
    test('decodes simple values', () {
      final types = [AbiUint(256), AbiBool()];
      final values = [BigInt.from(42), true];
      final encoded = AbiEncoder.encode(types, values);

      final decoded = AbiDecoder.decode(types, encoded);

      expect(decoded[0], equals(BigInt.from(42)));
      expect(decoded[1], equals(true));
    });

    test('decodes function return data', () {
      final outputTypes = [AbiUint(256)];
      final encoded = AbiEncoder.encode(outputTypes, [BigInt.from(1000)]);

      final decoded = AbiDecoder.decodeFunction(outputTypes, encoded);

      expect(decoded[0], equals(BigInt.from(1000)));
    });

    test('decodes Error(string) revert', () {
      // Error(string) selector: 0x08c379a0
      final selector = Uint8List.fromList([0x08, 0xc3, 0x79, 0xa0]);
      final errorMessage = AbiEncoder.encode([AbiString()], ['Insufficient balance']);
      final revertData = BytesUtils.concat([selector, errorMessage]);

      final decoded = AbiDecoder.decodeError(revertData);

      expect(decoded, equals('Insufficient balance'));
    });

    test('decodes Panic(uint256) revert', () {
      // Panic(uint256) selector: 0x4e487b71
      final selector = Uint8List.fromList([0x4e, 0x48, 0x7b, 0x71]);
      final panicCode = AbiEncoder.encode([AbiUint(256)], [BigInt.from(0x11)]);
      final revertData = BytesUtils.concat([selector, panicCode]);

      final decoded = AbiDecoder.decodeError(revertData);

      expect(decoded, equals('Arithmetic overflow/underflow'));
    });

    test('decodes event log', () {
      final types = [AbiAddress(), AbiAddress(), AbiUint(256)];
      final indexed = [true, true, false];
      final names = ['from', 'to', 'value'];

      // Simulate Transfer event
      final fromAddress = '0x0000000000000000000000001111111111111111111111111111111111111111';
      final toAddress = '0x0000000000000000000000002222222222222222222222222222222222222222';
      final topics = [
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef', // event signature
        fromAddress,
        toAddress,
      ];
      final data = AbiEncoder.encode([AbiUint(256)], [BigInt.from(1000)]);

      final decoded = AbiDecoder.decodeEvent(
        types: types,
        indexed: indexed,
        names: names,
        topics: topics,
        data: data,
      );

      expect(decoded['from'].toString().toLowerCase(), contains('1111'));
      expect(decoded['to'].toString().toLowerCase(), contains('2222'));
      expect(decoded['value'], equals(BigInt.from(1000)));
    });

    test('returns null for invalid error data', () {
      final invalidData = Uint8List.fromList([1, 2, 3]);
      final decoded = AbiDecoder.decodeError(invalidData);
      expect(decoded, isNull);
    });
  });
}
