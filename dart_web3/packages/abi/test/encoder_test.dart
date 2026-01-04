import 'package:test/test.dart';
import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() {
  group('AbiEncoder Tests', () {
    test('encodes simple function call', () {
      final encoded = AbiEncoder.encodeFunction(
        'transfer(address,uint256)',
        ['0xdead000000000000000000000000000000000000', BigInt.from(100)],
      );

      // Should have 4-byte selector + 64 bytes of data
      expect(encoded.length, equals(68));
    });

    test('encodes function with no arguments', () {
      final encoded = AbiEncoder.encodeFunction('totalSupply()', []);

      // Should have only 4-byte selector
      expect(encoded.length, equals(4));
    });

    test('getFunctionSelector returns correct selector', () {
      // transfer(address,uint256) selector is 0xa9059cbb
      final selector =
          AbiEncoder.getFunctionSelector('transfer(address,uint256)');

      expect(selector.length, equals(4));
      expect(HexUtils.encode(selector), equals('0xa9059cbb'));
    });

    test('getEventTopic returns correct topic', () {
      // Transfer(address,address,uint256) topic
      final topic =
          AbiEncoder.getEventTopic('Transfer(address,address,uint256)');

      expect(topic.length, equals(32));
      expect(
          HexUtils.encode(topic),
          equals(
              '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'));
    });

    test('encodePacked works correctly', () {
      final encoded = AbiEncoder.encodePacked(
        [AbiUint(8), AbiAddress()],
        [42, '0xdead000000000000000000000000000000000000'],
      );

      // uint8 (1 byte) + address (20 bytes) = 21 bytes
      expect(encoded.length, equals(21));
      expect(encoded[0], equals(42));
    });

    test('encode handles multiple types', () {
      final encoded = AbiEncoder.encode(
        [AbiUint(256), AbiAddress(), AbiBool(), AbiString()],
        [
          BigInt.from(42),
          '0xdead000000000000000000000000000000000000',
          true,
          'hello',
        ],
      );

      // Should be properly encoded with dynamic offset for string
      expect(encoded.length % 32, equals(0));
    });
  });
}
