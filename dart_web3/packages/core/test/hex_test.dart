import 'dart:typed_data';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:test/test.dart';

void main() {
  group('HexUtils', () {
    group('encode', () {
      test('encodes empty bytes', () {
        expect(HexUtils.encode(Uint8List(0)), equals('0x'));
      });

      test('encodes bytes with prefix', () {
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
        expect(HexUtils.encode(bytes), equals('0xdeadbeef'));
      });

      test('encodes bytes without prefix', () {
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);
        expect(HexUtils.encode(bytes, prefix: false), equals('deadbeef'));
      });

      test('encodes single byte', () {
        expect(HexUtils.encode(Uint8List.fromList([0x0f])), equals('0x0f'));
      });

      test('preserves leading zeros', () {
        expect(HexUtils.encode(Uint8List.fromList([0x00, 0x01])), equals('0x0001'));
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        expect(HexUtils.decode('0x'), equals(Uint8List(0)));
        expect(HexUtils.decode(''), equals(Uint8List(0)));
      });

      test('decodes with 0x prefix', () {
        expect(
          HexUtils.decode('0xdeadbeef'),
          equals(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])),
        );
      });

      test('decodes without prefix', () {
        expect(
          HexUtils.decode('deadbeef'),
          equals(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])),
        );
      });

      test('decodes with 0X prefix (uppercase)', () {
        expect(
          HexUtils.decode('0XDEADBEEF'),
          equals(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])),
        );
      });

      test('handles odd-length hex by padding', () {
        expect(HexUtils.decode('0xf'), equals(Uint8List.fromList([0x0f])));
      });

      test('throws on invalid hex characters', () {
        expect(() => HexUtils.decode('0xgg'), throwsA(isA<HexException>()));
      });
    });

    group('isValid', () {
      test('returns true for valid hex', () {
        expect(HexUtils.isValid('0xdeadbeef'), isTrue);
        expect(HexUtils.isValid('deadbeef'), isTrue);
        expect(HexUtils.isValid('0x'), isTrue);
        expect(HexUtils.isValid(''), isTrue);
        expect(HexUtils.isValid('0xABCDEF'), isTrue);
      });

      test('returns false for invalid hex', () {
        expect(HexUtils.isValid('0xgg'), isFalse);
        expect(HexUtils.isValid('xyz'), isFalse);
      });
    });

    group('strip0x', () {
      test('strips 0x prefix', () {
        expect(HexUtils.strip0x('0xdeadbeef'), equals('deadbeef'));
      });

      test('strips 0X prefix', () {
        expect(HexUtils.strip0x('0Xdeadbeef'), equals('deadbeef'));
      });

      test('returns unchanged if no prefix', () {
        expect(HexUtils.strip0x('deadbeef'), equals('deadbeef'));
      });
    });

    group('add0x', () {
      test('adds 0x prefix', () {
        expect(HexUtils.add0x('deadbeef'), equals('0xdeadbeef'));
      });

      test('returns unchanged if already has prefix', () {
        expect(HexUtils.add0x('0xdeadbeef'), equals('0xdeadbeef'));
      });
    });

    group('pad', () {
      test('pads on left by default', () {
        expect(HexUtils.pad('0xff', 4), equals('0x000000ff'));
      });

      test('pads on right when specified', () {
        expect(HexUtils.pad('0xff', 4, left: false), equals('0xff000000'));
      });

      test('returns unchanged if already long enough', () {
        expect(HexUtils.pad('0xdeadbeef', 2), equals('0xdeadbeef'));
      });
    });

    group('round-trip property', () {
      test('encode then decode returns original bytes', () {
        final testCases = [
          Uint8List(0),
          Uint8List.fromList([0x00]),
          Uint8List.fromList([0xff]),
          Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]),
          Uint8List.fromList(List.generate(32, (i) => i)),
        ];

        for (final bytes in testCases) {
          final encoded = HexUtils.encode(bytes);
          final decoded = HexUtils.decode(encoded);
          expect(decoded, equals(bytes), reason: 'Failed for: $bytes');
        }
      });
    });
  });
}
