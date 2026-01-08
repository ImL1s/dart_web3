import 'dart:typed_data';

import 'package:web3_universal_near/web3_universal_near.dart';
import 'package:test/test.dart';

void main() {
  group('Borsh Encoder', () {
    group('Boolean encoding', () {
      test('encodes true', () {
        expect(Borsh.encodeBool(true), equals(Uint8List.fromList([1])));
      });

      test('encodes false', () {
        expect(Borsh.encodeBool(false), equals(Uint8List.fromList([0])));
      });
    });

    group('Integer encoding (little-endian)', () {
      test('u8 encoding', () {
        expect(Borsh.encodeU8(0), equals(Uint8List.fromList([0])));
        expect(Borsh.encodeU8(255), equals(Uint8List.fromList([255])));
      });

      test('u32 encoding', () {
        expect(Borsh.encodeU32(0), equals(Uint8List.fromList([0, 0, 0, 0])));
        expect(
          Borsh.encodeU32(0x12345678),
          equals(Uint8List.fromList([0x78, 0x56, 0x34, 0x12])),
        );
      });

      test('u64 encoding', () {
        expect(
          Borsh.encodeU64(BigInt.zero),
          equals(Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0])),
        );
        expect(
          Borsh.encodeU64(BigInt.one),
          equals(Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0])),
        );
      });

      test('u128 encoding', () {
        final bytes = Borsh.encodeU128(BigInt.one);
        expect(bytes.length, equals(16));
        expect(bytes[0], equals(1));
        for (int i = 1; i < 16; i++) {
          expect(bytes[i], equals(0));
        }
      });
    });

    group('Signed integer encoding', () {
      test('i8 encoding', () {
        final encoder = BorshEncoder();
        encoder.writeI8(0);
        encoder.writeI8(127);
        encoder.writeI8(-1);
        encoder.writeI8(-128);

        final decoder = BorshDecoder(encoder.toBytes());
        expect(decoder.readI8(), equals(0));
        expect(decoder.readI8(), equals(127));
        expect(decoder.readI8(), equals(-1));
        expect(decoder.readI8(), equals(-128));
      });

      test('i16 encoding', () {
        final encoder = BorshEncoder();
        encoder.writeI16(0);
        encoder.writeI16(32767);
        encoder.writeI16(-1);
        encoder.writeI16(-32768);

        final decoder = BorshDecoder(encoder.toBytes());
        expect(decoder.readI16(), equals(0));
        expect(decoder.readI16(), equals(32767));
        expect(decoder.readI16(), equals(-1));
        expect(decoder.readI16(), equals(-32768));
      });

      test('i32 encoding', () {
        final encoder = BorshEncoder();
        encoder.writeI32(0);
        encoder.writeI32(2147483647);
        encoder.writeI32(-1);
        encoder.writeI32(-2147483648);

        final decoder = BorshDecoder(encoder.toBytes());
        expect(decoder.readI32(), equals(0));
        expect(decoder.readI32(), equals(2147483647));
        expect(decoder.readI32(), equals(-1));
        expect(decoder.readI32(), equals(-2147483648));
      });

      test('i64 encoding', () {
        final encoder = BorshEncoder();
        encoder.writeI64(BigInt.zero);
        encoder.writeI64(BigInt.from(-1));
        encoder.writeI64(BigInt.parse('9223372036854775807'));
        encoder.writeI64(BigInt.parse('-9223372036854775808'));

        final decoder = BorshDecoder(encoder.toBytes());
        expect(decoder.readI64(), equals(BigInt.zero));
        expect(decoder.readI64(), equals(BigInt.from(-1)));
        expect(decoder.readI64(), equals(BigInt.parse('9223372036854775807')));
        expect(decoder.readI64(), equals(BigInt.parse('-9223372036854775808')));
      });
    });

    group('Floating point encoding', () {
      test('f32 encoding', () {
        final encoder = BorshEncoder();
        encoder.writeF32(0.0);
        encoder.writeF32(1.5);
        encoder.writeF32(-3.14);

        final decoder = BorshDecoder(encoder.toBytes());
        expect(decoder.readF32(), closeTo(0.0, 0.0001));
        expect(decoder.readF32(), closeTo(1.5, 0.0001));
        expect(decoder.readF32(), closeTo(-3.14, 0.01));
      });

      test('f64 encoding', () {
        final encoder = BorshEncoder();
        encoder.writeF64(0.0);
        encoder.writeF64(1.5);
        encoder.writeF64(-3.141592653589793);

        final decoder = BorshDecoder(encoder.toBytes());
        expect(decoder.readF64(), closeTo(0.0, 0.0001));
        expect(decoder.readF64(), closeTo(1.5, 0.0001));
        expect(decoder.readF64(), closeTo(-3.141592653589793, 0.0000001));
      });
    });

    group('String encoding', () {
      test('empty string', () {
        final bytes = Borsh.encodeString('');
        // u32 length (4 bytes) + no content
        expect(bytes, equals(Uint8List.fromList([0, 0, 0, 0])));
      });

      test('ascii string', () {
        final bytes = Borsh.encodeString('abc');
        // u32 length = 3 (little-endian) + bytes
        expect(bytes[0], equals(3));
        expect(bytes[1], equals(0));
        expect(bytes[2], equals(0));
        expect(bytes[3], equals(0));
        expect(bytes[4], equals(0x61)); // 'a'
        expect(bytes[5], equals(0x62)); // 'b'
        expect(bytes[6], equals(0x63)); // 'c'
      });

      test('unicode string round trip', () {
        const testStr = '你好世界🌍';
        expect(Borsh.decodeString(Borsh.encodeString(testStr)), equals(testStr));
      });
    });

    group('Bytes encoding', () {
      test('empty bytes', () {
        final result = Borsh.encodeBytes(Uint8List(0));
        expect(result, equals(Uint8List.fromList([0, 0, 0, 0])));
      });

      test('bytes round trip', () {
        final input = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(Borsh.decodeBytes(Borsh.encodeBytes(input)), equals(input));
      });
    });
  });

  group('Borsh Decoder', () {
    group('Integer decoding', () {
      test('u8 round trip', () {
        for (int i in [0, 1, 127, 128, 255]) {
          expect(Borsh.decodeU8(Borsh.encodeU8(i)), equals(i));
        }
      });

      test('u32 round trip', () {
        for (int i in [0, 1, 0x12345678, 0xFFFFFFFF]) {
          expect(Borsh.decodeU32(Borsh.encodeU32(i)), equals(i));
        }
      });

      test('u64 round trip', () {
        final values = [
          BigInt.zero,
          BigInt.one,
          BigInt.from(256),
          BigInt.parse('18446744073709551615'),
        ];
        for (final v in values) {
          expect(Borsh.decodeU64(Borsh.encodeU64(v)), equals(v));
        }
      });

      test('u128 round trip', () {
        final value = BigInt.parse('340282366920938463463374607431768211455');
        expect(Borsh.decodeU128(Borsh.encodeU128(value)), equals(value));
      });
    });
  });

  group('BorshEncoder advanced', () {
    test('vector of u64', () {
      final encoder = BorshEncoder();
      encoder.writeVector<BigInt>(
        [BigInt.from(1), BigInt.from(2), BigInt.from(3)],
        encoder.writeU64,
      );
      final bytes = encoder.toBytes();

      final decoder = BorshDecoder(bytes);
      final result = decoder.readVector(() => decoder.readU64());
      expect(result, equals([BigInt.from(1), BigInt.from(2), BigInt.from(3)]));
    });

    test('fixed array', () {
      final encoder = BorshEncoder();
      // Fixed array has no length prefix
      encoder.writeArray<int>([1, 2, 3], encoder.writeU32);

      final decoder = BorshDecoder(encoder.toBytes());
      final result = decoder.readArray(3, () => decoder.readU32());
      expect(result, equals([1, 2, 3]));
    });

    test('optional values', () {
      final encoder = BorshEncoder();
      encoder.writeOption<int>(42, encoder.writeU32);
      encoder.writeOption<int>(null, encoder.writeU32);

      final decoder = BorshDecoder(encoder.toBytes());
      expect(decoder.readOption(() => decoder.readU32()), equals(42));
      expect(decoder.readOption(() => decoder.readU32()), isNull);
    });

    test('enum encoding', () {
      final encoder = BorshEncoder();
      // Variant 0 with no data
      encoder.writeEnum(0, null);
      // Variant 1 with u32 data
      encoder.writeEnum(1, () => encoder.writeU32(100));

      final decoder = BorshDecoder(encoder.toBytes());
      expect(decoder.readEnumVariant(), equals(0));
      expect(decoder.readEnumVariant(), equals(1));
      expect(decoder.readU32(), equals(100));
    });

    test('map encoding', () {
      final encoder = BorshEncoder();
      encoder.writeMap<String, int>(
        {'a': 1, 'b': 2, 'c': 3},
        encoder.writeString,
        encoder.writeU32,
      );

      final decoder = BorshDecoder(encoder.toBytes());
      final result = decoder.readMap(
        () => decoder.readString(),
        () => decoder.readU32(),
      );
      expect(result['a'], equals(1));
      expect(result['b'], equals(2));
      expect(result['c'], equals(3));
    });

    test('set encoding', () {
      final encoder = BorshEncoder();
      encoder.writeSet<int>({1, 2, 3}, encoder.writeU32);

      final decoder = BorshDecoder(encoder.toBytes());
      final result = decoder.readSet(() => decoder.readU32());
      expect(result, containsAll([1, 2, 3]));
    });

    test('nested structures', () {
      final encoder = BorshEncoder();
      // Encode a "struct" with multiple fields
      encoder.writeU8(1); // version
      encoder.writeString('metadata'); // name
      encoder.writeVector<int>([10, 20, 30], encoder.writeU32); // values

      final decoder = BorshDecoder(encoder.toBytes());
      expect(decoder.readU8(), equals(1));
      expect(decoder.readString(), equals('metadata'));
      expect(
        decoder.readVector(() => decoder.readU32()),
        equals([10, 20, 30]),
      );
    });
  });

  group('Borsh Edge Cases', () {
    test('empty buffer throws on read', () {
      final decoder = BorshDecoder(Uint8List(0));
      expect(() => decoder.readU8(), throwsRangeError);
    });

    test('partial buffer throws on read', () {
      final decoder = BorshDecoder(Uint8List.fromList([1]));
      expect(() => decoder.readU32(), throwsRangeError);
    });

    test('very long string', () {
      final longStr = 'a' * 10000;
      expect(Borsh.decodeString(Borsh.encodeString(longStr)), equals(longStr));
    });

    test('max u64 value', () {
      final max = BigInt.parse('18446744073709551615');
      expect(Borsh.decodeU64(Borsh.encodeU64(max)), equals(max));
    });

    test('negative values throw for unsigned types', () {
      expect(() => Borsh.encodeU8(-1), throwsArgumentError);
      expect(() => Borsh.encodeU32(-1), throwsArgumentError);
      expect(() => Borsh.encodeU64(BigInt.from(-1)), throwsArgumentError);
    });

    test('overflow values throw', () {
      expect(() => Borsh.encodeU8(256), throwsArgumentError);
      expect(() => Borsh.encodeU32(0x100000000), throwsArgumentError);
    });

    test('length prefix uses u32 (4 bytes)', () {
      // This is a key difference from BCS which uses ULEB128
      final bytes = Borsh.encodeString('a');
      // Length should be 4 bytes (u32) + 1 byte content = 5 bytes
      expect(bytes.length, equals(5));
      expect(bytes[0], equals(1)); // length low byte
      expect(bytes[1], equals(0));
      expect(bytes[2], equals(0));
      expect(bytes[3], equals(0)); // length high byte
    });
  });
}
