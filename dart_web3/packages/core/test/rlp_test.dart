import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

void main() {
  group('RLP', () {
    group('encode', () {
      test('encodes single byte < 0x80', () {
        expect(RLP.encode(Uint8List.fromList([0x00])), equals(Uint8List.fromList([0x00])));
        expect(RLP.encode(Uint8List.fromList([0x7f])), equals(Uint8List.fromList([0x7f])));
      });

      test('encodes empty bytes', () {
        expect(RLP.encode(Uint8List(0)), equals(Uint8List.fromList([0x80])));
      });

      test('encodes short string (1-55 bytes)', () {
        // "dog" = [0x64, 0x6f, 0x67]
        final dog = Uint8List.fromList([0x64, 0x6f, 0x67]);
        expect(RLP.encode(dog), equals(Uint8List.fromList([0x83, 0x64, 0x6f, 0x67])));
      });

      test('encodes long string (> 55 bytes)', () {
        final longBytes = Uint8List(56);
        final encoded = RLP.encode(longBytes);
        expect(encoded[0], equals(0xb8)); // 0xb7 + 1 (length of length)
        expect(encoded[1], equals(56)); // length
        expect(encoded.length, equals(58)); // 1 + 1 + 56
      });

      test('encodes empty list', () {
        expect(RLP.encode([]), equals(Uint8List.fromList([0xc0])));
      });

      test('encodes short list', () {
        // ["cat", "dog"]
        final cat = Uint8List.fromList([0x63, 0x61, 0x74]);
        final dog = Uint8List.fromList([0x64, 0x6f, 0x67]);
        final encoded = RLP.encode([cat, dog]);
        expect(
          encoded,
          equals(Uint8List.fromList([0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67])),
        );
      });

      test('encodes nested list', () {
        final nested = [
          [],
          [[]],
          [
            [],
            [[]],
          ],
        ];
        final encoded = RLP.encode(nested);
        expect(
          encoded,
          equals(Uint8List.fromList([0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0])),
        );
      });

      test('encodes integer', () {
        expect(RLP.encode(0), equals(Uint8List.fromList([0x80])));
        expect(RLP.encode(127), equals(Uint8List.fromList([0x7f])));
        expect(RLP.encode(128), equals(Uint8List.fromList([0x81, 0x80])));
        expect(RLP.encode(256), equals(Uint8List.fromList([0x82, 0x01, 0x00])));
      });

      test('encodes BigInt', () {
        expect(RLP.encode(BigInt.zero), equals(Uint8List.fromList([0x80])));
        expect(RLP.encode(BigInt.from(127)), equals(Uint8List.fromList([0x7f])));
        expect(RLP.encode(BigInt.from(256)), equals(Uint8List.fromList([0x82, 0x01, 0x00])));
      });

      test('encodes null as empty bytes', () {
        expect(RLP.encode(null), equals(Uint8List.fromList([0x80])));
      });
    });

    group('decode', () {
      test('decodes single byte < 0x80', () {
        expect(RLP.decode(Uint8List.fromList([0x00])), equals(Uint8List.fromList([0x00])));
        expect(RLP.decode(Uint8List.fromList([0x7f])), equals(Uint8List.fromList([0x7f])));
      });

      test('decodes empty bytes', () {
        expect(RLP.decode(Uint8List.fromList([0x80])), equals(Uint8List(0)));
      });

      test('decodes short string', () {
        final encoded = Uint8List.fromList([0x83, 0x64, 0x6f, 0x67]);
        expect(RLP.decode(encoded), equals(Uint8List.fromList([0x64, 0x6f, 0x67])));
      });

      test('decodes empty list', () {
        expect(RLP.decode(Uint8List.fromList([0xc0])), equals([]));
      });

      test('decodes short list', () {
        final encoded = Uint8List.fromList([0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67]);
        final decoded = RLP.decode(encoded) as List;
        expect(decoded.length, equals(2));
        expect(decoded[0], equals(Uint8List.fromList([0x63, 0x61, 0x74])));
        expect(decoded[1], equals(Uint8List.fromList([0x64, 0x6f, 0x67])));
      });

      test('throws on empty data', () {
        expect(() => RLP.decode(Uint8List(0)), throwsA(isA<RlpException>()));
      });
    });

    group('round-trip property', () {
      test('encode then decode returns equivalent data', () {
        final testCases = [
          Uint8List(0),
          Uint8List.fromList([0x00]),
          Uint8List.fromList([0x7f]),
          Uint8List.fromList([0x80]),
          Uint8List.fromList([0x64, 0x6f, 0x67]), // "dog"
          Uint8List(56), // long string
        ];

        for (final data in testCases) {
          final encoded = RLP.encode(data);
          final decoded = RLP.decode(encoded);
          expect(decoded, equals(data), reason: 'Failed for: $data');
        }
      });

      test('encode then decode list returns equivalent data', () {
        final testCases = [
          <dynamic>[],
          [Uint8List.fromList([1, 2, 3])],
          [
            Uint8List.fromList([1]),
            Uint8List.fromList([2]),
          ],
          [
            [],
            [Uint8List.fromList([1])],
          ],
        ];

        for (final data in testCases) {
          final encoded = RLP.encode(data);
          final decoded = RLP.decode(encoded);
          expect(_deepEquals(decoded, data), isTrue, reason: 'Failed for: $data');
        }
      });
    });
  });
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a is Uint8List && b is Uint8List) {
    return BytesUtils.equals(a, b);
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
