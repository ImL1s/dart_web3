import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:test/test.dart';

void main() {
  group('AbiPrettyPrinter Tests', () {
    test('formats simple values correctly', () {
      final formatted = AbiPrettyPrinter.format(
        [AbiUint(256), AbiBool()],
        [BigInt.from(42), true],
      );

      expect(formatted, contains('[uint256] 42'));
      expect(formatted, contains('[bool] true'));
    });

    test('formats addresses correctly', () {
      final addr = '0xdead000000000000000000000000000000000000';
      final formatted = AbiPrettyPrinter.formatValue(AbiAddress(), addr);
      expect(formatted, equals(addr));
    });

    test('formats strings correctly', () {
      final formatted = AbiPrettyPrinter.formatValue(AbiString(), 'hello');
      expect(formatted, equals('"hello"'));
    });

    test('formats large numbers with hex', () {
      final largeVal = BigInt.parse('1000000000000000000');
      final formatted = AbiPrettyPrinter.formatValue(AbiUint(256), largeVal);
      expect(formatted, contains('1000000000000000000'));
      expect(formatted, contains('(0x'));
    });

    test('formats arrays correctly', () {
      final type = AbiArray(AbiUint(256));
      final formatted = AbiPrettyPrinter.formatValue(type, [1, 2, 3]);
      expect(formatted, equals('[1, 2, 3]'));
    });

    test('formats tuples correctly', () {
      final type = AbiTuple([AbiUint(256), AbiString()], ['id', 'name']);
      final formatted = AbiPrettyPrinter.formatValue(type, [42, 'Alice']);
      expect(formatted, contains('id: 42'));
      expect(formatted, contains('name: "Alice"'));
    });
  });
}
