import 'dart:typed_data';

import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:test/test.dart';

/// Tests for ABI module fixes:
/// 1. Tuple/Array static size calculation (Gemini 3 Pro finding)
/// 2. UTF-8 string encoding (Codex finding)
/// 3. Nested tuple parsing in signatures (Codex finding)
void main() {
  group('Static Size Calculation Fixes', () {
    test('AbiTuple.getStaticSize returns correct size for static tuple', () {
      // (uint256, uint256) should be 64 bytes, not 32
      final staticTuple = AbiTuple([AbiUint(256), AbiUint(256)]);
      expect(staticTuple.isDynamic, isFalse);
      expect(staticTuple.getStaticSize(), equals(64));
    });

    test('AbiTuple.getStaticSize returns 32 for dynamic tuple', () {
      // (uint256, string) is dynamic, so head size is 32 (offset pointer)
      final dynamicTuple = AbiTuple([AbiUint(256), AbiString()]);
      expect(dynamicTuple.isDynamic, isTrue);
      expect(dynamicTuple.getStaticSize(), equals(32));
    });

    test('AbiArray.getStaticSize returns correct size for fixed static array', () {
      // uint256[3] should be 96 bytes
      final staticArray = AbiArray(AbiUint(256), 3);
      expect(staticArray.isDynamic, isFalse);
      expect(staticArray.getStaticSize(), equals(96));
    });

    test('AbiArray.getStaticSize returns 32 for dynamic array', () {
      // uint256[] is dynamic
      final dynamicArray = AbiArray(AbiUint(256));
      expect(dynamicArray.isDynamic, isTrue);
      expect(dynamicArray.getStaticSize(), equals(32));
    });

    test('nested static tuple size is calculated correctly', () {
      // ((uint256, uint256), uint256) = 64 + 32 = 96 bytes
      final innerTuple = AbiTuple([AbiUint(256), AbiUint(256)]);
      final outerTuple = AbiTuple([innerTuple, AbiUint(256)]);
      expect(outerTuple.isDynamic, isFalse);
      expect(outerTuple.getStaticSize(), equals(96));
    });

    test('encoding tuple with nested static struct calculates offset correctly', () {
      // ((uint256, uint256), string)
      // Head: 64 bytes (static tuple) + 32 bytes (string offset) = 96 bytes
      // Offset should point to byte 96
      final innerTuple = AbiTuple([AbiUint(256), AbiUint(256)]);
      final outerTuple = AbiTuple([innerTuple, AbiString()]);

      final encoded = outerTuple.encode([
        [BigInt.from(1), BigInt.from(2)],
        'hello',
      ]);

      // First 64 bytes: inner tuple (1, 2)
      // Next 32 bytes: offset to string data (should be 96 = 0x60)
      final offset = _bytesToBigInt(encoded.sublist(64, 96));
      expect(offset, equals(BigInt.from(96)));
    });
  });

  group('UTF-8 Encoding Fixes', () {
    test('AbiString encodes non-ASCII characters correctly', () {
      final abiString = AbiString();
      final testString = '你好世界'; // Chinese characters

      final encoded = abiString.encode(testString);

      // Decode and verify round-trip
      final (decoded, _) = abiString.decode(encoded, 0);
      expect(decoded, equals(testString));
    });

    test('AbiString encodes emoji correctly', () {
      final abiString = AbiString();
      final testString = 'Hello 🌍🚀';

      final encoded = abiString.encode(testString);

      // Decode and verify round-trip
      final (decoded, _) = abiString.decode(encoded, 0);
      expect(decoded, equals(testString));
    });

    test('AbiString encodes mixed content correctly', () {
      final abiString = AbiString();
      final testString = 'Hello 世界 🎉 Привет';

      final encoded = abiString.encode(testString);

      // Decode and verify
      final (decoded, _) = abiString.decode(encoded, 0);
      expect(decoded, equals(testString));
    });

    test('function selector uses UTF-8 encoding', () {
      // Verify selector matches expected keccak256 of UTF-8 bytes
      final selector = AbiEncoder.getFunctionSelector('transfer(address,uint256)');
      expect(selector.length, equals(4));

      // transfer(address,uint256) selector = 0xa9059cbb
      expect(_toHex(selector), equals('a9059cbb'));
    });

    test('event topic uses UTF-8 encoding', () {
      final topic = AbiEncoder.getEventTopic('Transfer(address,address,uint256)');
      expect(topic.length, equals(32));

      // Transfer(address,address,uint256) topic hash
      expect(_toHex(topic).startsWith('ddf252ad'), isTrue);
    });

    test('packed encoding uses UTF-8 for strings', () {
      final encoded = AbiEncoder.encodePacked([AbiString()], ['你好']);

      // UTF-8 encoding of '你好' is 6 bytes: e4 bd a0 e5 a5 bd
      expect(encoded.length, equals(6));
      expect(_toHex(encoded), equals('e4bda0e5a5bd'));
    });
  });

  group('Signature Parsing Fixes', () {
    test('parses simple tuple in signature', () {
      final encoded = AbiEncoder.encodeFunction(
        'foo((uint256,address))',
        [
          [BigInt.from(123), '0x1234567890123456789012345678901234567890'],
        ],
      );

      // Should have 4-byte selector + encoded tuple
      expect(encoded.length, greaterThan(4));
    });

    test('parses nested tuples in signature', () {
      final encoded = AbiEncoder.encodeFunction(
        'foo((uint256,(address,bool)))',
        [
          [
            BigInt.from(123),
            ['0x1234567890123456789012345678901234567890', true],
          ]
        ],
      );

      expect(encoded.length, greaterThan(4));
    });

    test('parses tuple with dynamic types', () {
      final encoded = AbiEncoder.encodeFunction(
        'foo((uint256,string))',
        [
          [BigInt.from(123), 'hello'],
        ],
      );

      expect(encoded.length, greaterThan(4));
    });

    test('parses tuple array', () {
      final encoded = AbiEncoder.encodeFunction(
        'foo((uint256,address)[])',
        [
          [
            [BigInt.from(1), '0x1111111111111111111111111111111111111111'],
            [BigInt.from(2), '0x2222222222222222222222222222222222222222'],
          ]
        ],
      );

      expect(encoded.length, greaterThan(4));
    });

    test('splits types correctly with nested brackets', () {
      // Internal test: verify comma splitting handles nested structures
      final encoded = AbiEncoder.encodeFunction(
        'complex((uint256,string),address,(bool,bytes32))',
        [
          [BigInt.from(123), 'test'],
          '0x1234567890123456789012345678901234567890',
          [true, Uint8List(32)],
        ],
      );

      expect(encoded.length, greaterThan(4));
    });

    test('parses fixed-size tuple array', () {
      final encoded = AbiEncoder.encodeFunction(
        'foo((uint256,uint256)[2])',
        [
          [
            [BigInt.from(1), BigInt.from(2)],
            [BigInt.from(3), BigInt.from(4)],
          ]
        ],
      );

      // 4-byte selector + 2 static tuples (64 bytes each) = 4 + 128 = 132 bytes
      expect(encoded.length, equals(132));
    });
  });

  group('Integration Tests', () {
    test('encode complex nested structure with correct offsets', () {
      // struct Order { uint256 id; string name; Item[] items; }
      // struct Item { address addr; uint256 amount; }
      // This tests static size calculation + UTF-8 + dynamic arrays

      final itemType = AbiTuple([AbiAddress(), AbiUint(256)]);
      final orderType = AbiTuple([
        AbiUint(256), // id
        AbiString(), // name (dynamic)
        AbiArray(itemType), // items (dynamic)
      ]);

      final order = [
        BigInt.from(1),
        'Test Order 中文',
        [
          ['0x1111111111111111111111111111111111111111', BigInt.from(100)],
          ['0x2222222222222222222222222222222222222222', BigInt.from(200)],
        ]
      ];

      final encoded = orderType.encode(order);

      // Decode and verify
      final (decoded, _) = orderType.decode(encoded, 0);
      expect(decoded[0], equals(BigInt.from(1)));
      expect(decoded[1], equals('Test Order 中文'));
      expect((decoded[2] as List).length, equals(2));
    });
  });
}

String _toHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (var i = 0; i < bytes.length; i++) {
    result = (result << 8) + BigInt.from(bytes[i]);
  }
  return result;
}
