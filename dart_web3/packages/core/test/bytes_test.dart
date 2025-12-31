import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

void main() {
  group('BytesUtils', () {
    group('concat', () {
      test('concatenates empty list', () {
        expect(BytesUtils.concat([]), equals(Uint8List(0)));
      });

      test('concatenates single array', () {
        final arr = Uint8List.fromList([1, 2, 3]);
        expect(BytesUtils.concat([arr]), equals(arr));
      });

      test('concatenates multiple arrays', () {
        final a = Uint8List.fromList([1, 2]);
        final b = Uint8List.fromList([3, 4]);
        final c = Uint8List.fromList([5]);
        expect(BytesUtils.concat([a, b, c]), equals(Uint8List.fromList([1, 2, 3, 4, 5])));
      });
    });

    group('slice', () {
      test('slices from start to end', () {
        final arr = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(BytesUtils.slice(arr, 1, 4), equals(Uint8List.fromList([2, 3, 4])));
      });

      test('slices to end when end not specified', () {
        final arr = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(BytesUtils.slice(arr, 2), equals(Uint8List.fromList([3, 4, 5])));
      });

      test('throws on invalid range', () {
        final arr = Uint8List.fromList([1, 2, 3]);
        expect(() => BytesUtils.slice(arr, -1), throwsA(isA<RangeError>()));
        expect(() => BytesUtils.slice(arr, 0, 10), throwsA(isA<RangeError>()));
      });
    });

    group('equals', () {
      test('returns true for equal arrays', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2, 3]);
        expect(BytesUtils.equals(a, b), isTrue);
      });

      test('returns false for different lengths', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2]);
        expect(BytesUtils.equals(a, b), isFalse);
      });

      test('returns false for different content', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2, 4]);
        expect(BytesUtils.equals(a, b), isFalse);
      });
    });

    group('pad', () {
      test('pads on left by default', () {
        final arr = Uint8List.fromList([1, 2]);
        expect(BytesUtils.pad(arr, 4), equals(Uint8List.fromList([0, 0, 1, 2])));
      });

      test('pads on right when specified', () {
        final arr = Uint8List.fromList([1, 2]);
        expect(BytesUtils.pad(arr, 4, left: false), equals(Uint8List.fromList([1, 2, 0, 0])));
      });

      test('returns copy if already long enough', () {
        final arr = Uint8List.fromList([1, 2, 3, 4]);
        expect(BytesUtils.pad(arr, 2), equals(arr));
      });
    });

    group('trimLeadingZeros', () {
      test('trims leading zeros', () {
        final arr = Uint8List.fromList([0, 0, 1, 2]);
        expect(BytesUtils.trimLeadingZeros(arr), equals(Uint8List.fromList([1, 2])));
      });

      test('returns empty for all zeros', () {
        final arr = Uint8List.fromList([0, 0, 0]);
        expect(BytesUtils.trimLeadingZeros(arr), equals(Uint8List(0)));
      });

      test('returns unchanged if no leading zeros', () {
        final arr = Uint8List.fromList([1, 2, 3]);
        expect(BytesUtils.trimLeadingZeros(arr), equals(arr));
      });
    });

    group('bigIntToBytes', () {
      test('converts zero', () {
        expect(BytesUtils.bigIntToBytes(BigInt.zero), equals(Uint8List(0)));
      });

      test('converts positive BigInt', () {
        expect(
          BytesUtils.bigIntToBytes(BigInt.from(256)),
          equals(Uint8List.fromList([1, 0])),
        );
      });

      test('pads to specified length', () {
        expect(
          BytesUtils.bigIntToBytes(BigInt.from(1), length: 4),
          equals(Uint8List.fromList([0, 0, 0, 1])),
        );
      });
    });

    group('bytesToBigInt', () {
      test('converts empty bytes to zero', () {
        expect(BytesUtils.bytesToBigInt(Uint8List(0)), equals(BigInt.zero));
      });

      test('converts bytes to BigInt', () {
        expect(
          BytesUtils.bytesToBigInt(Uint8List.fromList([1, 0])),
          equals(BigInt.from(256)),
        );
      });
    });

    group('round-trip property', () {
      test('bigIntToBytes then bytesToBigInt returns original', () {
        final testCases = [
          BigInt.zero,
          BigInt.one,
          BigInt.from(255),
          BigInt.from(256),
          BigInt.from(65535),
          BigInt.parse('ffffffffffffffff', radix: 16),
        ];

        for (final value in testCases) {
          final bytes = BytesUtils.bigIntToBytes(value);
          final result = BytesUtils.bytesToBigInt(bytes);
          expect(result, equals(value), reason: 'Failed for: $value');
        }
      });
    });

    group('xor', () {
      test('XORs two arrays', () {
        final a = Uint8List.fromList([0xff, 0x00, 0xaa]);
        final b = Uint8List.fromList([0x0f, 0xf0, 0x55]);
        expect(BytesUtils.xor(a, b), equals(Uint8List.fromList([0xf0, 0xf0, 0xff])));
      });

      test('throws on different lengths', () {
        final a = Uint8List.fromList([1, 2]);
        final b = Uint8List.fromList([1, 2, 3]);
        expect(() => BytesUtils.xor(a, b), throwsA(isA<ArgumentError>()));
      });
    });
  });
}
