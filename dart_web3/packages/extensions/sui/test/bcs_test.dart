import 'dart:typed_data';

import 'package:web3_universal_sui/web3_universal_sui.dart';
import 'package:test/test.dart';

void main() {
  group('BCS Encoder', () {
    group('Boolean encoding', () {
      test('encodes true', () {
        expect(Bcs.encodeBool(true), equals(Uint8List.fromList([1])));
      });

      test('encodes false', () {
        expect(Bcs.encodeBool(false), equals(Uint8List.fromList([0])));
      });
    });

    group('Integer encoding (little-endian)', () {
      test('u8 encoding', () {
        expect(Bcs.encodeU8(0), equals(Uint8List.fromList([0])));
        expect(Bcs.encodeU8(255), equals(Uint8List.fromList([255])));
        expect(Bcs.encodeU8(128), equals(Uint8List.fromList([128])));
      });

      test('u16 encoding', () {
        expect(Bcs.encodeU16(0), equals(Uint8List.fromList([0, 0])));
        expect(Bcs.encodeU16(256), equals(Uint8List.fromList([0, 1])));
        expect(Bcs.encodeU16(65535), equals(Uint8List.fromList([255, 255])));
        // 0x1234 = 4660 => little-endian: [0x34, 0x12]
        expect(Bcs.encodeU16(0x1234), equals(Uint8List.fromList([0x34, 0x12])));
      });

      test('u32 encoding', () {
        expect(Bcs.encodeU32(0), equals(Uint8List.fromList([0, 0, 0, 0])));
        expect(
          Bcs.encodeU32(0x12345678),
          equals(Uint8List.fromList([0x78, 0x56, 0x34, 0x12])),
        );
        expect(
          Bcs.encodeU32(0xFFFFFFFF),
          equals(Uint8List.fromList([255, 255, 255, 255])),
        );
      });

      test('u64 encoding', () {
        expect(
          Bcs.encodeU64(BigInt.zero),
          equals(Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0])),
        );
        expect(
          Bcs.encodeU64(BigInt.one),
          equals(Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0])),
        );
        expect(
          Bcs.encodeU64(BigInt.from(256)),
          equals(Uint8List.fromList([0, 1, 0, 0, 0, 0, 0, 0])),
        );
        // Max u64
        expect(
          Bcs.encodeU64(BigInt.parse('18446744073709551615')),
          equals(Uint8List.fromList([255, 255, 255, 255, 255, 255, 255, 255])),
        );
      });

      test('u128 encoding', () {
        final bytes = Bcs.encodeU128(BigInt.one);
        expect(bytes.length, equals(16));
        expect(bytes[0], equals(1));
        for (int i = 1; i < 16; i++) {
          expect(bytes[i], equals(0));
        }
      });

      test('u256 encoding', () {
        final bytes = Bcs.encodeU256(BigInt.one);
        expect(bytes.length, equals(32));
        expect(bytes[0], equals(1));
        for (int i = 1; i < 32; i++) {
          expect(bytes[i], equals(0));
        }
      });
    });

    group('ULEB128 encoding', () {
      test('single byte values', () {
        expect(Bcs.encodeUleb128(0), equals(Uint8List.fromList([0])));
        expect(Bcs.encodeUleb128(1), equals(Uint8List.fromList([1])));
        expect(Bcs.encodeUleb128(127), equals(Uint8List.fromList([127])));
      });

      test('two byte values', () {
        // 128 = 0b10000000 => ULEB128: [0x80, 0x01]
        expect(Bcs.encodeUleb128(128), equals(Uint8List.fromList([0x80, 0x01])));
        // 255 = 0b11111111 => ULEB128: [0xFF, 0x01]
        expect(Bcs.encodeUleb128(255), equals(Uint8List.fromList([0xFF, 0x01])));
        // 300 = 0b100101100 => ULEB128: [0xAC, 0x02]
        expect(Bcs.encodeUleb128(300), equals(Uint8List.fromList([0xAC, 0x02])));
      });

      test('larger values', () {
        // 16384 = 0x4000 => ULEB128: [0x80, 0x80, 0x01]
        expect(
          Bcs.encodeUleb128(16384),
          equals(Uint8List.fromList([0x80, 0x80, 0x01])),
        );
      });
    });

    group('String encoding', () {
      test('empty string', () {
        expect(Bcs.encodeString(''), equals(Uint8List.fromList([0])));
      });

      test('ascii string', () {
        // "abc" => length 3 + bytes
        final bytes = Bcs.encodeString('abc');
        expect(bytes[0], equals(3)); // ULEB128 length
        expect(bytes[1], equals(0x61)); // 'a'
        expect(bytes[2], equals(0x62)); // 'b'
        expect(bytes[3], equals(0x63)); // 'c'
      });

      test('unicode string', () {
        final bytes = Bcs.encodeString('你好');
        // UTF-8 encoding of "你好" is 6 bytes
        expect(bytes[0], equals(6));
      });
    });

    group('Bytes encoding', () {
      test('empty bytes', () {
        expect(
          Bcs.encodeBytes(Uint8List(0)),
          equals(Uint8List.fromList([0])),
        );
      });

      test('bytes with content', () {
        final input = Uint8List.fromList([1, 2, 3]);
        final result = Bcs.encodeBytes(input);
        expect(result[0], equals(3)); // length
        expect(result[1], equals(1));
        expect(result[2], equals(2));
        expect(result[3], equals(3));
      });
    });

    group('Address encoding', () {
      test('32-byte address', () {
        final address = Uint8List(32);
        address[31] = 1;
        final result = Bcs.encodeAddress(address);
        expect(result.length, equals(32));
        expect(result[31], equals(1));
      });

      test('throws for wrong length', () {
        expect(() => Bcs.encodeAddress(Uint8List(31)), throwsArgumentError);
        expect(() => Bcs.encodeAddress(Uint8List(33)), throwsArgumentError);
      });
    });
  });

  group('BCS Decoder', () {
    group('Boolean decoding', () {
      test('decodes true', () {
        expect(Bcs.decodeBool(Uint8List.fromList([1])), isTrue);
      });

      test('decodes false', () {
        expect(Bcs.decodeBool(Uint8List.fromList([0])), isFalse);
      });

      test('throws on invalid value', () {
        expect(
          () => Bcs.decodeBool(Uint8List.fromList([2])),
          throwsFormatException,
        );
      });
    });

    group('Integer decoding', () {
      test('u8 round trip', () {
        for (int i in [0, 1, 127, 128, 255]) {
          expect(Bcs.decodeU8(Bcs.encodeU8(i)), equals(i));
        }
      });

      test('u16 round trip', () {
        for (int i in [0, 1, 256, 0x1234, 65535]) {
          expect(Bcs.decodeU16(Bcs.encodeU16(i)), equals(i));
        }
      });

      test('u32 round trip', () {
        for (int i in [0, 1, 0x12345678, 0xFFFFFFFF]) {
          expect(Bcs.decodeU32(Bcs.encodeU32(i)), equals(i));
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
          expect(Bcs.decodeU64(Bcs.encodeU64(v)), equals(v));
        }
      });

      test('u128 round trip', () {
        final value = BigInt.parse('340282366920938463463374607431768211455');
        expect(Bcs.decodeU128(Bcs.encodeU128(value)), equals(value));
      });

      test('u256 round trip', () {
        final value = BigInt.parse(
          '115792089237316195423570985008687907853269984665640564039457584007913129639935',
        );
        expect(Bcs.decodeU256(Bcs.encodeU256(value)), equals(value));
      });
    });

    group('String decoding', () {
      test('empty string', () {
        expect(Bcs.decodeString(Bcs.encodeString('')), equals(''));
      });

      test('ascii string round trip', () {
        const testStr = 'Hello, World!';
        expect(Bcs.decodeString(Bcs.encodeString(testStr)), equals(testStr));
      });

      test('unicode string round trip', () {
        const testStr = '你好世界🌍';
        expect(Bcs.decodeString(Bcs.encodeString(testStr)), equals(testStr));
      });
    });

    group('Bytes decoding', () {
      test('bytes round trip', () {
        final input = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(Bcs.decodeBytes(Bcs.encodeBytes(input)), equals(input));
      });
    });
  });

  group('BcsEncoder advanced', () {
    test('vector of u64', () {
      final encoder = BcsEncoder();
      encoder.writeVector<BigInt>(
        [BigInt.from(1), BigInt.from(2), BigInt.from(3)],
        encoder.writeU64,
      );
      final bytes = encoder.toBytes();

      final decoder = BcsDecoder(bytes);
      final result = decoder.readVector(() => decoder.readU64());
      expect(result, equals([BigInt.from(1), BigInt.from(2), BigInt.from(3)]));
    });

    test('optional values', () {
      final encoder = BcsEncoder();
      encoder.writeOption<int>(42, encoder.writeU32);
      encoder.writeOption<int>(null, encoder.writeU32);

      final decoder = BcsDecoder(encoder.toBytes());
      expect(decoder.readOption(() => decoder.readU32()), equals(42));
      expect(decoder.readOption(() => decoder.readU32()), isNull);
    });

    test('enum encoding', () {
      final encoder = BcsEncoder();
      // Variant 0 with no data
      encoder.writeEnum(0, null);
      // Variant 1 with u32 data
      encoder.writeEnum(1, () => encoder.writeU32(100));
      // Variant 2 with string data
      encoder.writeEnum(2, () => encoder.writeString('test'));

      final decoder = BcsDecoder(encoder.toBytes());
      expect(decoder.readEnumVariant(), equals(0));
      expect(decoder.readEnumVariant(), equals(1));
      expect(decoder.readU32(), equals(100));
      expect(decoder.readEnumVariant(), equals(2));
      expect(decoder.readString(), equals('test'));
    });

    test('nested structures', () {
      final encoder = BcsEncoder();
      // Encode a "struct" with multiple fields
      encoder.writeU8(1); // version
      encoder.writeString('metadata'); // name
      encoder.writeVector<int>([10, 20, 30], encoder.writeU32); // values

      final decoder = BcsDecoder(encoder.toBytes());
      expect(decoder.readU8(), equals(1));
      expect(decoder.readString(), equals('metadata'));
      expect(
        decoder.readVector(() => decoder.readU32()),
        equals([10, 20, 30]),
      );
    });
  });

  group('BCS Edge Cases', () {
    test('empty buffer throws on read', () {
      final decoder = BcsDecoder(Uint8List(0));
      expect(() => decoder.readU8(), throwsRangeError);
    });

    test('partial buffer throws on read', () {
      final decoder = BcsDecoder(Uint8List.fromList([1]));
      expect(() => decoder.readU32(), throwsRangeError);
    });

    test('very long string', () {
      final longStr = 'a' * 1000;
      expect(Bcs.decodeString(Bcs.encodeString(longStr)), equals(longStr));
    });

    test('max u64 value', () {
      final max = BigInt.parse('18446744073709551615');
      expect(Bcs.decodeU64(Bcs.encodeU64(max)), equals(max));
    });

    test('negative values throw', () {
      expect(() => Bcs.encodeU8(-1), throwsArgumentError);
      expect(() => Bcs.encodeU16(-1), throwsArgumentError);
      expect(() => Bcs.encodeU32(-1), throwsArgumentError);
      expect(() => Bcs.encodeU64(BigInt.from(-1)), throwsArgumentError);
    });

    test('overflow values throw', () {
      expect(() => Bcs.encodeU8(256), throwsArgumentError);
      expect(() => Bcs.encodeU16(65536), throwsArgumentError);
      expect(() => Bcs.encodeU32(0x100000000), throwsArgumentError);
      expect(
        () => Bcs.encodeU64(BigInt.parse('18446744073709551616')),
        throwsArgumentError,
      );
    });
  });
}
