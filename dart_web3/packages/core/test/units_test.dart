import 'package:test/test.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() {
  group('EthUnit', () {
    group('wei', () {
      test('parses wei string', () {
        expect(EthUnit.wei('1000000000000000000'),
            equals(BigInt.parse('1000000000000000000')));
        expect(EthUnit.wei('0'), equals(BigInt.zero));
      });
    });

    group('gwei', () {
      test('converts gwei to wei', () {
        expect(EthUnit.gwei('1'), equals(BigInt.from(1000000000)));
        expect(EthUnit.gwei('0.5'), equals(BigInt.from(500000000)));
        expect(EthUnit.gwei('1.5'), equals(BigInt.from(1500000000)));
      });
    });

    group('ether', () {
      test('converts ether to wei', () {
        expect(EthUnit.ether('1'), equals(BigInt.parse('1000000000000000000')));
        expect(
            EthUnit.ether('0.5'), equals(BigInt.parse('500000000000000000')));
        expect(
            EthUnit.ether('1.5'), equals(BigInt.parse('1500000000000000000')));
      });

      test('handles small decimals', () {
        expect(EthUnit.ether('0.000000000000000001'), equals(BigInt.one));
      });

      test('handles large values', () {
        expect(EthUnit.ether('1000000'),
            equals(BigInt.parse('1000000000000000000000000')));
      });
    });

    group('formatWei', () {
      test('formats wei', () {
        expect(EthUnit.formatWei(BigInt.from(1000)), equals('1000'));
      });
    });

    group('formatGwei', () {
      test('formats whole gwei', () {
        expect(EthUnit.formatGwei(BigInt.from(1000000000)), equals('1'));
      });

      test('formats fractional gwei', () {
        expect(EthUnit.formatGwei(BigInt.from(1500000000)), equals('1.5'));
      });

      test('removes trailing zeros', () {
        expect(EthUnit.formatGwei(BigInt.from(1100000000)), equals('1.1'));
      });
    });

    group('formatEther', () {
      test('formats whole ether', () {
        expect(EthUnit.formatEther(BigInt.parse('1000000000000000000')),
            equals('1'));
      });

      test('formats fractional ether', () {
        expect(EthUnit.formatEther(BigInt.parse('1500000000000000000')),
            equals('1.5'));
      });

      test('formats small amounts', () {
        expect(EthUnit.formatEther(BigInt.one), equals('0.000000000000000001'));
      });
    });

    group('convert', () {
      test('converts ether to gwei', () {
        expect(
          EthUnit.convert(BigInt.one, from: Unit.ether, to: Unit.gwei),
          equals(BigInt.from(1000000000)),
        );
      });

      test('converts gwei to wei', () {
        expect(
          EthUnit.convert(BigInt.one, from: Unit.gwei, to: Unit.wei),
          equals(BigInt.from(1000000000)),
        );
      });

      test('converts wei to ether', () {
        expect(
          EthUnit.convert(BigInt.parse('1000000000000000000'),
              from: Unit.wei, to: Unit.ether),
          equals(BigInt.one),
        );
      });
    });

    group('round-trip property', () {
      test('ether to wei and back', () {
        final testCases = [
          '0',
          '1',
          '0.5',
          '1.5',
          '100',
          '0.000000000000000001'
        ];

        for (final value in testCases) {
          final wei = EthUnit.ether(value);
          final formatted = EthUnit.formatEther(wei);
          final backToWei = EthUnit.ether(formatted);
          expect(backToWei, equals(wei), reason: 'Failed for: $value');
        }
      });

      test('gwei to wei and back', () {
        final testCases = ['0', '1', '0.5', '1.5', '100', '0.000000001'];

        for (final value in testCases) {
          final wei = EthUnit.gwei(value);
          final formatted = EthUnit.formatGwei(wei);
          final backToWei = EthUnit.gwei(formatted);
          expect(backToWei, equals(wei), reason: 'Failed for: $value');
        }
      });
    });

    group('error handling', () {
      test('throws on empty value', () {
        expect(
            () => EthUnit.ether(''), throwsA(isA<UnitConversionException>()));
        expect(
            () => EthUnit.ether('  '), throwsA(isA<UnitConversionException>()));
      });

      test('throws on invalid format', () {
        expect(() => EthUnit.ether('1.2.3'),
            throwsA(isA<UnitConversionException>()));
        expect(() => EthUnit.ether('abc'),
            throwsA(isA<UnitConversionException>()));
      });
    });
  });
}
