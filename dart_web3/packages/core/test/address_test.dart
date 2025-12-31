import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

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

    // Note: toChecksum and isValidChecksum tests require keccak256
    // which is in the crypto module. These will be tested in integration tests.
  });
}
