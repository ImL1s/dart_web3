import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_web3_abi/dart_web3_abi.dart';

void main() {
  group('AbiType Tests', () {
    group('AbiUint', () {
      test('encodes uint256 correctly', () {
        final type = AbiUint(256);
        final encoded = type.encode(BigInt.from(42));
        
        expect(encoded.length, equals(32));
        expect(encoded[31], equals(42));
        expect(encoded.sublist(0, 31).every((b) => b == 0), isTrue);
      });

      test('encodes large uint256 correctly', () {
        final type = AbiUint(256);
        final value = BigInt.parse('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', radix: 16);
        final encoded = type.encode(value);
        
        expect(encoded.length, equals(32));
        expect(encoded.every((b) => b == 255), isTrue);
      });

      test('decodes uint256 correctly', () {
        final type = AbiUint(256);
        final data = Uint8List(32);
        data[31] = 42;
        
        final (decoded, consumed) = type.decode(data, 0);
        expect(decoded, equals(BigInt.from(42)));
        expect(consumed, equals(32));
      });
    });

    group('AbiInt', () {
      test('encodes positive int256 correctly', () {
        final type = AbiInt(256);
        final encoded = type.encode(BigInt.from(42));
        
        expect(encoded.length, equals(32));
        expect(encoded[31], equals(42));
      });

      test('encodes negative int256 correctly', () {
        final type = AbiInt(256);
        final encoded = type.encode(BigInt.from(-1));
        
        expect(encoded.length, equals(32));
        expect(encoded.every((b) => b == 255), isTrue);
      });

      test('decodes negative int256 correctly', () {
        final type = AbiInt(256);
        final data = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          data[i] = 255;
        }
        
        final (decoded, _) = type.decode(data, 0);
        expect(decoded, equals(BigInt.from(-1)));
      });
    });

    group('AbiAddress', () {
      test('encodes address correctly', () {
        final type = AbiAddress();
        final encoded = type.encode('0xdead000000000000000000000000000000000000');
        
        expect(encoded.length, equals(32));
        expect(encoded[12], equals(0xde));
        expect(encoded[13], equals(0xad));
      });

      test('decodes address correctly', () {
        final type = AbiAddress();
        final data = Uint8List(32);
        data[12] = 0xde;
        data[13] = 0xad;
        
        final (decoded, _) = type.decode(data, 0);
        expect(decoded.toString().toLowerCase(), contains('dead'));
      });
    });

    group('AbiBool', () {
      test('encodes true correctly', () {
        final type = AbiBool();
        final encoded = type.encode(true);
        
        expect(encoded.length, equals(32));
        expect(encoded[31], equals(1));
      });

      test('encodes false correctly', () {
        final type = AbiBool();
        final encoded = type.encode(false);
        
        expect(encoded.length, equals(32));
        expect(encoded[31], equals(0));
      });
    });

    group('AbiString', () {
      test('encodes string correctly', () {
        final type = AbiString();
        final encoded = type.encode('hello');
        
        // Length (32 bytes) + padded data (32 bytes)
        expect(encoded.length, equals(64));
        
        // First 32 bytes should be length (5)
        expect(encoded[31], equals(5));
        
        // Next bytes should be 'hello'
        expect(encoded[32], equals('h'.codeUnitAt(0)));
        expect(encoded[33], equals('e'.codeUnitAt(0)));
        expect(encoded[34], equals('l'.codeUnitAt(0)));
        expect(encoded[35], equals('l'.codeUnitAt(0)));
        expect(encoded[36], equals('o'.codeUnitAt(0)));
      });

      test('decodes string correctly', () {
        final type = AbiString();
        final encoded = type.encode('hello world');
        
        final (decoded, _) = type.decode(encoded, 0);
        expect(decoded, equals('hello world'));
      });
    });

    group('AbiBytes', () {
      test('encodes bytes correctly', () {
        final type = AbiBytes();
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encoded = type.encode(data);
        
        // Length (32 bytes) + padded data (32 bytes)
        expect(encoded.length, equals(64));
        expect(encoded[31], equals(5));
        expect(encoded[32], equals(1));
        expect(encoded[33], equals(2));
      });

      test('decodes bytes correctly', () {
        final type = AbiBytes();
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final encoded = type.encode(data);
        
        final (decoded, _) = type.decode(encoded, 0);
        expect(decoded, equals(data));
      });
    });

    group('AbiFixedBytes', () {
      test('encodes bytes32 correctly', () {
        final type = AbiFixedBytes(32);
        final data = Uint8List(32);
        data[0] = 0xde;
        data[1] = 0xad;
        
        final encoded = type.encode(data);
        expect(encoded.length, equals(32));
        expect(encoded[0], equals(0xde));
        expect(encoded[1], equals(0xad));
      });
    });

    group('AbiArray', () {
      test('encodes dynamic array correctly', () {
        final type = AbiArray(AbiUint(256));
        final values = [BigInt.from(1), BigInt.from(2), BigInt.from(3)];
        final encoded = type.encode(values);
        
        // Length (32) + 3 elements (32 each) = 128 bytes
        expect(encoded.length, equals(128));
        expect(encoded[31], equals(3)); // length
      });

      test('encodes fixed array correctly', () {
        final type = AbiArray(AbiUint(256), 3);
        final values = [BigInt.from(1), BigInt.from(2), BigInt.from(3)];
        final encoded = type.encode(values);
        
        // 3 elements (32 each) = 96 bytes (no length prefix)
        expect(encoded.length, equals(96));
      });

      test('decodes array correctly', () {
        final type = AbiArray(AbiUint(256));
        final values = [BigInt.from(1), BigInt.from(2), BigInt.from(3)];
        final encoded = type.encode(values);
        
        final (decoded, _) = type.decode(encoded, 0);
        expect(decoded, equals(values));
      });
    });

    group('AbiTuple', () {
      test('encodes tuple correctly', () {
        final type = AbiTuple([AbiUint(256), AbiAddress()]);
        final values = [BigInt.from(42), '0xdead000000000000000000000000000000000000'];
        final encoded = type.encode(values);
        
        expect(encoded.length, equals(64));
      });

      test('decodes tuple correctly', () {
        final type = AbiTuple([AbiUint(256), AbiBool()]);
        final values = [BigInt.from(42), true];
        final encoded = type.encode(values);
        
        final (decoded, _) = type.decode(encoded, 0);
        expect((decoded as List)[0], equals(BigInt.from(42)));
        expect((decoded)[1], equals(true));
      });
    });
  });
}
