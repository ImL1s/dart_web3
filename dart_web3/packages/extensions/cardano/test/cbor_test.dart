import 'dart:typed_data';

import 'package:web3_universal_cardano/web3_universal_cardano.dart';
import 'package:test/test.dart';

void main() {
  group('CBOR Encoder', () {
    group('Unsigned integers', () {
      test('encodes small values (0-23) in single byte', () {
        expect(Cbor.encodeUnsignedInt(0), equals(Uint8List.fromList([0x00])));
        expect(Cbor.encodeUnsignedInt(1), equals(Uint8List.fromList([0x01])));
        expect(Cbor.encodeUnsignedInt(10), equals(Uint8List.fromList([0x0a])));
        expect(Cbor.encodeUnsignedInt(23), equals(Uint8List.fromList([0x17])));
      });

      test('encodes values 24-255 with additional byte', () {
        expect(
          Cbor.encodeUnsignedInt(24),
          equals(Uint8List.fromList([0x18, 24])),
        );
        expect(
          Cbor.encodeUnsignedInt(255),
          equals(Uint8List.fromList([0x18, 0xFF])),
        );
      });

      test('encodes values 256-65535 with 2 additional bytes', () {
        expect(
          Cbor.encodeUnsignedInt(256),
          equals(Uint8List.fromList([0x19, 0x01, 0x00])),
        );
        expect(
          Cbor.encodeUnsignedInt(0xFFFF),
          equals(Uint8List.fromList([0x19, 0xFF, 0xFF])),
        );
      });

      test('encodes values up to u32 with 4 additional bytes', () {
        expect(
          Cbor.encodeUnsignedInt(0x10000),
          equals(Uint8List.fromList([0x1a, 0x00, 0x01, 0x00, 0x00])),
        );
        expect(
          Cbor.encodeUnsignedInt(0xFFFFFFFF),
          equals(Uint8List.fromList([0x1a, 0xFF, 0xFF, 0xFF, 0xFF])),
        );
      });

      test('encodes values up to u64 with 8 additional bytes', () {
        expect(
          Cbor.encodeUnsignedInt(0x100000000),
          equals(Uint8List.fromList([
            0x1b,
            0x00,
            0x00,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            0x00,
          ])),
        );
      });
    });

    group('Negative integers', () {
      test('encodes -1 to -24', () {
        // -1 is encoded as type 1 with argument 0
        expect(Cbor.encodeInt(-1), equals(Uint8List.fromList([0x20])));
        expect(Cbor.encodeInt(-10), equals(Uint8List.fromList([0x29])));
        expect(Cbor.encodeInt(-24), equals(Uint8List.fromList([0x37])));
      });

      test('encodes -25 and lower', () {
        expect(
          Cbor.encodeInt(-25),
          equals(Uint8List.fromList([0x38, 24])),
        );
        expect(
          Cbor.encodeInt(-256),
          equals(Uint8List.fromList([0x38, 0xFF])),
        );
      });

      test('encodes larger negative values', () {
        expect(
          Cbor.encodeInt(-257),
          equals(Uint8List.fromList([0x39, 0x01, 0x00])),
        );
      });
    });

    group('Byte strings', () {
      test('encodes empty bytes', () {
        expect(
          Cbor.encodeBytes(Uint8List(0)),
          equals(Uint8List.fromList([0x40])),
        );
      });

      test('encodes small byte string', () {
        expect(
          Cbor.encodeBytes(Uint8List.fromList([1, 2, 3, 4])),
          equals(Uint8List.fromList([0x44, 1, 2, 3, 4])),
        );
      });

      test('encodes byte string with length > 23', () {
        final bytes = Uint8List(24);
        final result = Cbor.encodeBytes(bytes);
        expect(result[0], equals(0x58)); // Type 2, additional info 24
        expect(result[1], equals(24)); // Length
        expect(result.length, equals(26)); // Header + length
      });
    });

    group('Text strings', () {
      test('encodes empty string', () {
        expect(
          Cbor.encodeString(''),
          equals(Uint8List.fromList([0x60])),
        );
      });

      test('encodes ASCII string', () {
        expect(
          Cbor.encodeString('IETF'),
          equals(Uint8List.fromList([0x64, 0x49, 0x45, 0x54, 0x46])),
        );
      });

      test('encodes Unicode string', () {
        // "水" is 3 UTF-8 bytes
        final result = Cbor.encodeString('水');
        expect(result[0], equals(0x63)); // Type 3, length 3
      });

      test('encodes string round trip', () {
        const testStr = 'Hello, 世界! 🌍';
        expect(Cbor.decodeString(Cbor.encodeString(testStr)), equals(testStr));
      });
    });

    group('Boolean and special values', () {
      test('encodes false', () {
        expect(Cbor.encodeBool(false), equals(Uint8List.fromList([0xF4])));
      });

      test('encodes true', () {
        expect(Cbor.encodeBool(true), equals(Uint8List.fromList([0xF5])));
      });

      test('encodes null', () {
        expect(Cbor.encodeNull(), equals(Uint8List.fromList([0xF6])));
      });
    });

    group('Floats', () {
      test('encodes float32', () {
        final encoder = CborEncoder();
        encoder.writeFloat32(100000.0);
        final bytes = encoder.toBytes();
        expect(bytes[0], equals(0xFA)); // Type 7, additional info 26
        expect(bytes.length, equals(5)); // 1 header + 4 bytes
      });

      test('encodes float64', () {
        final encoder = CborEncoder();
        encoder.writeFloat64(1.1);
        final bytes = encoder.toBytes();
        expect(bytes[0], equals(0xFB)); // Type 7, additional info 27
        expect(bytes.length, equals(9)); // 1 header + 8 bytes
      });

      test('encodes infinity', () {
        final encoder = CborEncoder();
        encoder.writeDouble(double.infinity);
        final bytes = encoder.toBytes();
        // Should use the most compact representation
        expect(bytes.length, lessThanOrEqualTo(5));
      });
    });

    group('Arrays', () {
      test('encodes empty array', () {
        final encoder = CborEncoder();
        encoder.writeArrayStart(0);
        expect(encoder.toBytes(), equals(Uint8List.fromList([0x80])));
      });

      test('encodes array with items', () {
        final encoder = CborEncoder();
        encoder.writeArray<int>([1, 2, 3], encoder.writeUnsignedInt);
        final bytes = encoder.toBytes();
        expect(bytes, equals(Uint8List.fromList([0x83, 0x01, 0x02, 0x03])));
      });

      test('encodes nested arrays', () {
        final encoder = CborEncoder();
        encoder.writeArrayStart(2);
        encoder.writeArrayStart(2);
        encoder.writeUnsignedInt(1);
        encoder.writeUnsignedInt(2);
        encoder.writeArrayStart(2);
        encoder.writeUnsignedInt(3);
        encoder.writeUnsignedInt(4);

        final decoder = CborDecoder(encoder.toBytes());
        expect(decoder.readArrayStart(), equals(2));
        expect(decoder.readArrayStart(), equals(2));
        expect(decoder.readUnsignedInt(), equals(1));
        expect(decoder.readUnsignedInt(), equals(2));
        expect(decoder.readArrayStart(), equals(2));
        expect(decoder.readUnsignedInt(), equals(3));
        expect(decoder.readUnsignedInt(), equals(4));
      });

      test('encodes indefinite array', () {
        final encoder = CborEncoder();
        encoder.writeIndefiniteArrayStart();
        encoder.writeUnsignedInt(1);
        encoder.writeUnsignedInt(2);
        encoder.writeBreak();
        final bytes = encoder.toBytes();
        expect(
          bytes,
          equals(Uint8List.fromList([0x9F, 0x01, 0x02, 0xFF])),
        );
      });
    });

    group('Maps', () {
      test('encodes empty map', () {
        final encoder = CborEncoder();
        encoder.writeMapStart(0);
        expect(encoder.toBytes(), equals(Uint8List.fromList([0xA0])));
      });

      test('encodes map with string keys', () {
        final encoder = CborEncoder();
        encoder.writeMap<String, int>(
          {'a': 1, 'b': 2},
          encoder.writeString,
          encoder.writeUnsignedInt,
        );
        final bytes = encoder.toBytes();
        // Map with 2 entries
        expect(bytes[0], equals(0xA2));
      });

      test('encodes map with int keys', () {
        final encoder = CborEncoder();
        encoder.writeMap<int, String>(
          {1: 'one', 2: 'two'},
          encoder.writeUnsignedInt,
          encoder.writeString,
        );
        final bytes = encoder.toBytes();
        expect(bytes[0], equals(0xA2));
      });
    });

    group('Tags', () {
      test('encodes small tag', () {
        final encoder = CborEncoder();
        encoder.writeTag(0); // Standard date/time
        encoder.writeString('2013-03-21T20:04:00Z');
        final bytes = encoder.toBytes();
        expect(bytes[0], equals(0xC0)); // Tag 0
      });

      test('encodes self-described CBOR', () {
        final encoder = CborEncoder();
        encoder.writeTag(CborTags.selfDescribedCbor);
        encoder.writeUnsignedInt(42);
        final bytes = encoder.toBytes();
        // Tag 55799 = 0xD9D9F7
        expect(bytes[0], equals(0xD9));
        expect(bytes[1], equals(0xD9));
        expect(bytes[2], equals(0xF7));
      });
    });
  });

  group('CBOR Decoder', () {
    group('Integer decoding', () {
      test('decodes unsigned integers', () {
        expect(Cbor.decodeUnsignedInt(Uint8List.fromList([0x00])), equals(0));
        expect(Cbor.decodeUnsignedInt(Uint8List.fromList([0x17])), equals(23));
        expect(
          Cbor.decodeUnsignedInt(Uint8List.fromList([0x18, 0xFF])),
          equals(255),
        );
        expect(
          Cbor.decodeUnsignedInt(Uint8List.fromList([0x19, 0x01, 0x00])),
          equals(256),
        );
      });

      test('decodes negative integers', () {
        expect(Cbor.decodeInt(Uint8List.fromList([0x20])), equals(-1));
        expect(Cbor.decodeInt(Uint8List.fromList([0x37])), equals(-24));
        expect(
          Cbor.decodeInt(Uint8List.fromList([0x38, 0x63])),
          equals(-100),
        );
      });

      test('integer round trips', () {
        final values = [0, 1, 23, 24, 255, 256, 65535, 65536, 0xFFFFFFFF];
        for (final v in values) {
          expect(Cbor.decodeUnsignedInt(Cbor.encodeUnsignedInt(v)), equals(v));
        }
      });

      test('negative integer round trips', () {
        final values = [-1, -10, -24, -25, -100, -256, -257, -65536];
        for (final v in values) {
          expect(Cbor.decodeInt(Cbor.encodeInt(v)), equals(v));
        }
      });
    });

    group('BigInt decoding', () {
      test('encodes and decodes large positive BigInt', () {
        final value = BigInt.parse('18446744073709551615'); // max u64
        final encoded = Cbor.encodeBigInt(value);
        expect(Cbor.decodeBigInt(encoded), equals(value));
      });

      test('encodes and decodes large negative BigInt', () {
        final value = BigInt.parse('-9223372036854775808');
        final encoded = Cbor.encodeBigInt(value);
        expect(Cbor.decodeBigInt(encoded), equals(value));
      });
    });

    group('Array decoding', () {
      test('decodes empty array', () {
        final decoder = CborDecoder(Uint8List.fromList([0x80]));
        expect(decoder.readArrayStart(), equals(0));
      });

      test('decodes array of integers', () {
        final decoder = CborDecoder(
          Uint8List.fromList([0x83, 0x01, 0x02, 0x03]),
        );
        final result = decoder.readArray(() => decoder.readUnsignedInt());
        expect(result, equals([1, 2, 3]));
      });

      test('decodes indefinite array', () {
        final decoder = CborDecoder(
          Uint8List.fromList([0x9F, 0x01, 0x02, 0x03, 0xFF]),
        );
        final result = decoder.readArray(() => decoder.readUnsignedInt());
        expect(result, equals([1, 2, 3]));
      });
    });

    group('Map decoding', () {
      test('decodes empty map', () {
        final decoder = CborDecoder(Uint8List.fromList([0xA0]));
        expect(decoder.readMapStart(), equals(0));
      });

      test('decodes map with string keys', () {
        final encoder = CborEncoder();
        encoder.writeMap<String, int>(
          {'x': 1, 'y': 2},
          encoder.writeString,
          encoder.writeUnsignedInt,
        );

        final decoder = CborDecoder(encoder.toBytes());
        final result = decoder.readMap(
          () => decoder.readString(),
          () => decoder.readUnsignedInt(),
        );
        expect(result['x'], equals(1));
        expect(result['y'], equals(2));
      });
    });

    group('Boolean and special decoding', () {
      test('decodes boolean values', () {
        expect(Cbor.decodeBool(Uint8List.fromList([0xF4])), isFalse);
        expect(Cbor.decodeBool(Uint8List.fromList([0xF5])), isTrue);
      });

      test('decodes null', () {
        final decoder = CborDecoder(Uint8List.fromList([0xF6]));
        expect(() => decoder.readNull(), returnsNormally);
      });
    });

    group('Float decoding', () {
      test('decodes float32 round trip', () {
        final encoder = CborEncoder();
        encoder.writeFloat32(3.14);
        final decoder = CborDecoder(encoder.toBytes());
        expect(decoder.readDouble(), closeTo(3.14, 0.001));
      });

      test('decodes float64 round trip', () {
        final encoder = CborEncoder();
        encoder.writeFloat64(3.141592653589793);
        final decoder = CborDecoder(encoder.toBytes());
        expect(decoder.readDouble(), closeTo(3.141592653589793, 0.0000001));
      });
    });

    group('Tag decoding', () {
      test('decodes tag values', () {
        final encoder = CborEncoder();
        encoder.writeTag(1);
        encoder.writeUnsignedInt(1363896240);

        final decoder = CborDecoder(encoder.toBytes());
        expect(decoder.readTag(), equals(1));
        expect(decoder.readUnsignedInt(), equals(1363896240));
      });
    });

    group('Optional decoding', () {
      test('decodes null as None', () {
        final decoder = CborDecoder(Uint8List.fromList([0xF6]));
        final result = decoder.readOptional(() => decoder.readUnsignedInt());
        expect(result, isNull);
      });

      test('decodes value as Some', () {
        final decoder = CborDecoder(Uint8List.fromList([0x0A]));
        final result = decoder.readOptional(() => decoder.readUnsignedInt());
        expect(result, equals(10));
      });
    });
  });

  group('CBOR Edge Cases', () {
    test('empty buffer throws on read', () {
      final decoder = CborDecoder(Uint8List(0));
      expect(() => decoder.readUnsignedInt(), throwsRangeError);
    });

    test('partial buffer throws on read', () {
      final decoder = CborDecoder(Uint8List.fromList([0x19, 0x01]));
      expect(() => decoder.readUnsignedInt(), throwsRangeError);
    });

    test('very long string round trip', () {
      final longStr = 'a' * 10000;
      expect(Cbor.decodeString(Cbor.encodeString(longStr)), equals(longStr));
    });

    test('negative throws for unsigned', () {
      expect(() => Cbor.encodeUnsignedInt(-1), throwsArgumentError);
    });

    test('big endian byte order', () {
      // CBOR uses big-endian for multi-byte integers
      final bytes = Cbor.encodeUnsignedInt(0x1234);
      expect(bytes, equals(Uint8List.fromList([0x19, 0x12, 0x34])));
    });

    test('major type in high bits', () {
      // Byte string has major type 2 (010 in high 3 bits)
      final bytes = Cbor.encodeBytes(Uint8List.fromList([0xAB]));
      expect(bytes[0] >> 5, equals(2)); // Major type 2
      expect(bytes[0] & 0x1F, equals(1)); // Length 1
    });

    test('peekMajorType identifies type correctly', () {
      final decoder1 = CborDecoder(Uint8List.fromList([0x00]));
      expect(decoder1.peekMajorType(), equals(CborMajorType.unsignedInt));

      final decoder2 = CborDecoder(Uint8List.fromList([0x20]));
      expect(decoder2.peekMajorType(), equals(CborMajorType.negativeInt));

      final decoder3 = CborDecoder(Uint8List.fromList([0x40]));
      expect(decoder3.peekMajorType(), equals(CborMajorType.byteString));

      final decoder4 = CborDecoder(Uint8List.fromList([0x60]));
      expect(decoder4.peekMajorType(), equals(CborMajorType.textString));

      final decoder5 = CborDecoder(Uint8List.fromList([0x80]));
      expect(decoder5.peekMajorType(), equals(CborMajorType.array));

      final decoder6 = CborDecoder(Uint8List.fromList([0xA0]));
      expect(decoder6.peekMajorType(), equals(CborMajorType.map));

      final decoder7 = CborDecoder(Uint8List.fromList([0xC0]));
      expect(decoder7.peekMajorType(), equals(CborMajorType.tag));

      final decoder8 = CborDecoder(Uint8List.fromList([0xF4]));
      expect(decoder8.peekMajorType(), equals(CborMajorType.simpleOrFloat));
    });
  });

  group('CBOR RFC 8949 Test Vectors', () {
    // Test vectors from RFC 8949 Appendix A
    test('integer 0', () {
      expect(Cbor.encodeUnsignedInt(0), equals(Uint8List.fromList([0x00])));
    });

    test('integer 1', () {
      expect(Cbor.encodeUnsignedInt(1), equals(Uint8List.fromList([0x01])));
    });

    test('integer 10', () {
      expect(Cbor.encodeUnsignedInt(10), equals(Uint8List.fromList([0x0a])));
    });

    test('integer 23', () {
      expect(Cbor.encodeUnsignedInt(23), equals(Uint8List.fromList([0x17])));
    });

    test('integer 24', () {
      expect(
        Cbor.encodeUnsignedInt(24),
        equals(Uint8List.fromList([0x18, 0x18])),
      );
    });

    test('integer 25', () {
      expect(
        Cbor.encodeUnsignedInt(25),
        equals(Uint8List.fromList([0x18, 0x19])),
      );
    });

    test('integer 100', () {
      expect(
        Cbor.encodeUnsignedInt(100),
        equals(Uint8List.fromList([0x18, 0x64])),
      );
    });

    test('integer 1000', () {
      expect(
        Cbor.encodeUnsignedInt(1000),
        equals(Uint8List.fromList([0x19, 0x03, 0xe8])),
      );
    });

    test('integer 1000000', () {
      expect(
        Cbor.encodeUnsignedInt(1000000),
        equals(Uint8List.fromList([0x1a, 0x00, 0x0f, 0x42, 0x40])),
      );
    });

    test('negative -1', () {
      expect(Cbor.encodeInt(-1), equals(Uint8List.fromList([0x20])));
    });

    test('negative -10', () {
      expect(Cbor.encodeInt(-10), equals(Uint8List.fromList([0x29])));
    });

    test('negative -100', () {
      expect(Cbor.encodeInt(-100), equals(Uint8List.fromList([0x38, 0x63])));
    });

    test('negative -1000', () {
      expect(
        Cbor.encodeInt(-1000),
        equals(Uint8List.fromList([0x39, 0x03, 0xe7])),
      );
    });

    test('empty byte string', () {
      expect(
        Cbor.encodeBytes(Uint8List(0)),
        equals(Uint8List.fromList([0x40])),
      );
    });

    test('byte string [1, 2, 3, 4]', () {
      expect(
        Cbor.encodeBytes(Uint8List.fromList([0x01, 0x02, 0x03, 0x04])),
        equals(Uint8List.fromList([0x44, 0x01, 0x02, 0x03, 0x04])),
      );
    });

    test('empty text string', () {
      expect(Cbor.encodeString(''), equals(Uint8List.fromList([0x60])));
    });

    test('text string "a"', () {
      expect(Cbor.encodeString('a'), equals(Uint8List.fromList([0x61, 0x61])));
    });

    test('text string "IETF"', () {
      expect(
        Cbor.encodeString('IETF'),
        equals(Uint8List.fromList([0x64, 0x49, 0x45, 0x54, 0x46])),
      );
    });

    test('false', () {
      expect(Cbor.encodeBool(false), equals(Uint8List.fromList([0xf4])));
    });

    test('true', () {
      expect(Cbor.encodeBool(true), equals(Uint8List.fromList([0xf5])));
    });

    test('null', () {
      expect(Cbor.encodeNull(), equals(Uint8List.fromList([0xf6])));
    });
  });
}
