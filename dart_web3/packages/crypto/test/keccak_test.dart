import 'dart:typed_data';

import 'package:dart_web3_crypto/dart_web3_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('Keccak256', () {
    group('hash', () {
      test('hashes empty input', () {
        final hash = Keccak256.hash(Uint8List(0));
        expect(hash.length, equals(32));
        // Keccak-256 of empty string
        expect(
          hash,
          equals(Uint8List.fromList([
            0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c,
            0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
            0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b,
            0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70,
          ])),
        );
      });

      test('hashes "hello" correctly', () {
        final input = Uint8List.fromList('hello'.codeUnits);
        final hash = Keccak256.hash(input);
        expect(hash.length, equals(32));
        // Known keccak256 hash of "hello"
        final expected = Uint8List.fromList([
          0x1c, 0x8a, 0xff, 0x95, 0x06, 0x85, 0xc2, 0xed,
          0x4b, 0xc3, 0x17, 0x4f, 0x34, 0x72, 0x28, 0x7b,
          0x56, 0xd9, 0x51, 0x7b, 0x9c, 0x94, 0x81, 0x27,
          0x31, 0x9a, 0x09, 0xa7, 0xa3, 0x6d, 0xea, 0xc8,
        ]);
        expect(hash, equals(expected));
      });

      test('produces 32-byte output', () {
        final inputs = [
          Uint8List(0),
          Uint8List(1),
          Uint8List(32),
          Uint8List(64),
          Uint8List(100),
          Uint8List(1000),
        ];

        for (final input in inputs) {
          final hash = Keccak256.hash(input);
          expect(hash.length, equals(32), reason: 'Input length: ${input.length}');
        }
      });

      test('produces different hashes for different inputs', () {
        final hash1 = Keccak256.hash(Uint8List.fromList([1, 2, 3]));
        final hash2 = Keccak256.hash(Uint8List.fromList([1, 2, 4]));
        expect(hash1, isNot(equals(hash2)));
      });

      test('produces same hash for same input', () {
        final input = Uint8List.fromList([1, 2, 3, 4, 5]);
        final hash1 = Keccak256.hash(input);
        final hash2 = Keccak256.hash(input);
        expect(hash1, equals(hash2));
      });
    });

    group('hashHex', () {
      test('returns hex string with 0x prefix', () {
        // hashHex expects a hex string input, not Uint8List
        final hash = Keccak256.hashHex('0x');
        expect(hash.startsWith('0x'), isTrue);
        expect(hash.length, equals(66)); // 0x + 64 hex chars
      });

      test('returns lowercase hex', () {
        final hash = Keccak256.hashHex('0x010203');
        expect(hash, equals(hash.toLowerCase()));
      });
    });

    group('hashUtf8', () {
      test('hashes UTF-8 string', () {
        final hash1 = Keccak256.hashUtf8('hello');
        final hash2 = Keccak256.hash(Uint8List.fromList('hello'.codeUnits));
        expect(hash1, equals(hash2));
      });
    });

    group('consistency property', () {
      test('hash is deterministic', () {
        final testCases = [
          Uint8List(0),
          Uint8List.fromList([0x00]),
          Uint8List.fromList([0xff]),
          Uint8List.fromList(List.generate(100, (i) => i % 256)),
        ];

        for (final input in testCases) {
          final hash1 = Keccak256.hash(input);
          final hash2 = Keccak256.hash(Uint8List.fromList(input));
          expect(hash1, equals(hash2), reason: 'Hash should be deterministic');
        }
      });
    });
  });
}
