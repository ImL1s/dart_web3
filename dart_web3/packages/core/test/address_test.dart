import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() {
  group('EthereumAddress', () {
    // Test addresses
    const validAddress = '0xd8da6bf26964af9d7eed9e03e53415d37aa96045';
    const checksumAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

    group('fromHex', () {
      test('parses lowercase address', () {
        final addr = EthereumAddress.fromHex(validAddress);
        expect(addr.hex, equals(validAddress));
      });

      test('parses uppercase address', () {
        final addr = EthereumAddress.fromHex(validAddress.toUpperCase());
        expect(addr.hex, equals(validAddress));
      });

      test('parses checksummed address', () {
        final addr = EthereumAddress.fromHex(checksumAddress);
        expect(addr.hex, equals(validAddress));
      });

      test('parses address without 0x prefix', () {
        final addr = EthereumAddress.fromHex(validAddress.substring(2));
        expect(addr.hex, equals(validAddress));
      });

      test('throws on invalid length', () {
        expect(
          () => EthereumAddress.fromHex('0x1234'),
          throwsA(isA<InvalidAddressException>()),
        );
      });

      test('throws on invalid characters', () {
        expect(
          () => EthereumAddress.fromHex('0x${validAddress.substring(2, 40)}gg'),
          throwsA(isA<InvalidAddressException>()),
        );
      });
    });

    group('constructor', () {
      test('accepts 20-byte array', () {
        final bytes = Uint8List(20);
        final addr = EthereumAddress(bytes);
        expect(addr.bytes.length, equals(20));
      });

      test('throws on wrong length', () {
        expect(
          () => EthereumAddress(Uint8List(19)),
          throwsA(isA<InvalidAddressException>()),
        );
        expect(
          () => EthereumAddress(Uint8List(21)),
          throwsA(isA<InvalidAddressException>()),
        );
      });
    });

    group('isValid', () {
      test('returns true for valid addresses', () {
        expect(EthereumAddress.isValid(validAddress), isTrue);
        expect(EthereumAddress.isValid(checksumAddress), isTrue);
        expect(EthereumAddress.isValid(validAddress.substring(2)), isTrue);
      });

      test('returns false for invalid addresses', () {
        expect(EthereumAddress.isValid('0x1234'), isFalse);
        expect(EthereumAddress.isValid('invalid'), isFalse);
        expect(EthereumAddress.isValid(''), isFalse);
      });
    });

    group('zero', () {
      test('returns zero address', () {
        final zero = EthereumAddress.zero;
        expect(zero.hex, equals('0x0000000000000000000000000000000000000000'));
        expect(zero.isZero, isTrue);
      });
    });

    group('isZero', () {
      test('returns true for zero address', () {
        expect(EthereumAddress.zero.isZero, isTrue);
      });

      test('returns false for non-zero address', () {
        final addr = EthereumAddress.fromHex(validAddress);
        expect(addr.isZero, isFalse);
      });
    });

    group('equality', () {
      test('equal addresses are equal', () {
        final a = EthereumAddress.fromHex(validAddress);
        final b = EthereumAddress.fromHex(validAddress.toUpperCase());
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different addresses are not equal', () {
        final a = EthereumAddress.fromHex(validAddress);
        final b = EthereumAddress.zero;
        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns lowercase hex', () {
        final addr = EthereumAddress.fromHex(checksumAddress);
        expect(addr.toString(), equals(validAddress));
      });
    });

    group('checksum', () {
      // Mock keccak256 that returns a specific hash for our test address
      // to verify the case conversion logic.
      // 0xd8da... hash start: 0x23... -> 0010 0011 (all < 8)
      // We'll mock a hash where some digits are >= 8
      Uint8List mockKeccak(Uint8List data) {
        // Return a hash where the first few digits are 'f' (>= 8)
        return Uint8List.fromList(List.filled(32, 0xff));
      }

      test('toChecksum converts to uppercase correctly based on hash', () {
        final addr = EthereumAddress.fromHex(validAddress);
        final checksum = addr.toChecksum(mockKeccak);
        
        // Since mockKeccak returns all 0xff, all letters should be uppercase
        expect(checksum, equals('0xD8DA6BF26964AF9D7EED9E03E53415D37AA96045'));
      });

      test('isValidChecksum returns true for all lowercase', () {
        expect(EthereumAddress.isValidChecksum(validAddress, mockKeccak), isTrue);
      });

      test('isValidChecksum returns true for valid checksum', () {
        final addr = EthereumAddress.fromHex(validAddress);
        final checksum = addr.toChecksum(mockKeccak);
        expect(EthereumAddress.isValidChecksum(checksum, mockKeccak), isTrue);
      });
    });
  });
}
