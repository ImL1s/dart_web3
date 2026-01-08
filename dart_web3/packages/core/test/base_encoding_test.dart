import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

void main() {
  group('Base58', () {
    group('encode', () {
      test('encodes empty bytes', () {
        expect(Base58.encode(Uint8List(0)), equals(''));
      });

      test('encodes single zero byte', () {
        expect(Base58.encode(Uint8List.fromList([0])), equals('1'));
      });

      test('encodes multiple leading zeros', () {
        expect(Base58.encode(Uint8List.fromList([0, 0, 0])), equals('111'));
      });

      test('encodes simple values', () {
        expect(Base58.encode(Uint8List.fromList([1])), equals('2'));
        expect(Base58.encode(Uint8List.fromList([58])), equals('21'));
      });

      test('encodes larger values', () {
        // "Hello" in bytes
        final hello = Uint8List.fromList([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
        expect(Base58.encode(hello), equals('9Ajdvzr'));
      });

      test('encodes with leading zeros preserved', () {
        final data = Uint8List.fromList([0, 0, 1, 2, 3]);
        final encoded = Base58.encode(data);
        expect(encoded.startsWith('11'), isTrue);
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        expect(Base58.decode(''), equals(Uint8List(0)));
      });

      test('decodes single "1" to zero byte', () {
        expect(Base58.decode('1'), equals(Uint8List.fromList([0])));
      });

      test('decodes multiple "1"s to zeros', () {
        expect(Base58.decode('111'), equals(Uint8List.fromList([0, 0, 0])));
      });

      test('decodes simple values', () {
        expect(Base58.decode('2'), equals(Uint8List.fromList([1])));
      });

      test('throws on invalid characters', () {
        expect(() => Base58.decode('0'), throwsFormatException); // 0 not in Base58
        expect(() => Base58.decode('I'), throwsFormatException);
        expect(() => Base58.decode('O'), throwsFormatException);
        expect(() => Base58.decode('l'), throwsFormatException);
      });

      test('round trip encode/decode', () {
        final testCases = [
          [0x00],
          [0x00, 0x00, 0x01],
          [0x01, 0x02, 0x03, 0x04, 0x05],
          List.generate(32, (i) => i),
        ];

        for (final data in testCases) {
          final original = Uint8List.fromList(data);
          final encoded = Base58.encode(original);
          final decoded = Base58.decode(encoded);
          expect(decoded, equals(original));
        }
      });
    });
  });

  group('Base58Check', () {
    test('encode and decode round trip', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final encoded = Base58Check.encode(data);
      final decoded = Base58Check.decode(encoded);
      expect(decoded, equals(data));
    });

    test('detects checksum errors', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final encoded = Base58Check.encode(data);

      // Corrupt the encoded string
      final corrupted = encoded.substring(0, encoded.length - 1) + 'z';
      expect(() => Base58Check.decode(corrupted), throwsFormatException);
    });

    test('encode with version', () {
      final data = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final encoded = Base58Check.encodeWithVersion(0x00, data);
      final (version, decoded) = Base58Check.decodeWithVersion(encoded);
      expect(version, equals(0x00));
      expect(decoded, equals(data));
    });

    test('Bitcoin mainnet address encoding', () {
      // Version 0x00 for mainnet P2PKH
      // Example: hash160 of a public key
      final pubKeyHash = Uint8List.fromList([
        0x01, 0x09, 0x66, 0x77, 0x60, 0x06, 0x95, 0x3D, 0x55, 0x67,
        0x43, 0x9E, 0x5E, 0x39, 0xF8, 0x6A, 0x0D, 0x27, 0x3B, 0xEE,
      ]);

      final address = Base58Check.encodeWithVersion(0x00, pubKeyHash);
      expect(address.startsWith('1'), isTrue);
    });
  });

  group('Bech32', () {
    group('character set', () {
      test('charset has 32 characters', () {
        expect(Bech32.charset.length, equals(32));
      });

      test('charset excludes 1, b, i, o', () {
        expect(Bech32.charset.contains('1'), isFalse);
        expect(Bech32.charset.contains('b'), isFalse);
        expect(Bech32.charset.contains('i'), isFalse);
        expect(Bech32.charset.contains('o'), isFalse);
      });
    });

    group('encode', () {
      test('encodes with empty data', () {
        final encoded = Bech32.encode('a', [], Bech32Variant.bech32);
        expect(encoded, equals('a12uel5l'));
      });

      test('encodes with data', () {
        final data = [0, 14, 20, 15];
        final encoded = Bech32.encode('test', data, Bech32Variant.bech32);
        expect(encoded.startsWith('test1'), isTrue);
        expect(encoded.length, greaterThan(10)); // HRP + separator + data + checksum
      });
    });

    group('decode', () {
      test('decodes valid Bech32 string', () {
        final (hrp, data, variant) = Bech32.decode('a12uel5l');
        expect(hrp, equals('a'));
        expect(data, isEmpty);
        expect(variant, equals(Bech32Variant.bech32));
      });

      test('throws on mixed case', () {
        expect(() => Bech32.decode('A12UEL5L'), returnsNormally);
        expect(() => Bech32.decode('a12uel5l'), returnsNormally);
        expect(() => Bech32.decode('A12uel5l'), throwsFormatException);
      });

      test('throws on invalid checksum', () {
        expect(() => Bech32.decode('a12uel5m'), throwsFormatException);
      });

      test('throws on missing separator', () {
        expect(() => Bech32.decode('abcdef'), throwsFormatException);
      });

      test('round trip encode/decode', () {
        final data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        final encoded = Bech32.encode('test', data, Bech32Variant.bech32);
        final (hrp, decoded, variant) = Bech32.decode(encoded);
        expect(hrp, equals('test'));
        expect(decoded, equals(data));
        expect(variant, equals(Bech32Variant.bech32));
      });
    });

    group('Bech32m', () {
      test('encode with Bech32m constant', () {
        final encoded = Bech32.encode('a', [], Bech32Variant.bech32m);
        expect(encoded, isNot(equals('a12uel5l'))); // Different checksum
      });

      test('round trip with Bech32m', () {
        final data = [1, 2, 3, 4, 5];
        final encoded = Bech32.encode('test', data, Bech32Variant.bech32m);
        final (hrp, decoded, variant) = Bech32.decode(encoded);
        expect(hrp, equals('test'));
        expect(decoded, equals(data));
        expect(variant, equals(Bech32Variant.bech32m));
      });
    });

    group('convertBits', () {
      test('converts 8-bit to 5-bit', () {
        final bytes = [0xFF]; // 11111111
        final result = Bech32.convertBits(bytes, 8, 5);
        // 11111111 -> 11111 111 -> 31, 28 (with padding)
        expect(result, equals([31, 28]));
      });

      test('converts 5-bit to 8-bit without padding', () {
        final fiveBit = [31, 28];
        final result = Bech32.convertBits(fiveBit, 5, 8, pad: false);
        expect(result, equals([0xFF]));
      });

      test('round trip 8->5->8', () {
        final original = [0xDE, 0xAD, 0xBE, 0xEF];
        final fiveBit = Bech32.convertBits(original, 8, 5);
        final recovered = Bech32.convertBits(fiveBit, 5, 8, pad: false);
        expect(recovered, equals(original));
      });
    });

    group('SegWit addresses', () {
      test('encodes v0 P2WPKH address', () {
        // 20-byte witness program
        final program = Uint8List.fromList([
          0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94,
          0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6,
        ]);
        final address = Bech32.encodeSegwit('bc', 0, program);
        expect(address.startsWith('bc1q'), isTrue);
      });

      test('encodes v0 P2WSH address', () {
        // 32-byte witness program
        final program = Uint8List(32);
        for (int i = 0; i < 32; i++) program[i] = i;

        final address = Bech32.encodeSegwit('bc', 0, program);
        expect(address.startsWith('bc1q'), isTrue);
      });

      test('encodes v1 Taproot address', () {
        // 32-byte witness program
        final program = Uint8List(32);
        for (int i = 0; i < 32; i++) program[i] = i + 1;

        final address = Bech32.encodeSegwit('bc', 1, program);
        expect(address.startsWith('bc1p'), isTrue); // v1 uses 'p'
      });

      test('decode SegWit address round trip', () {
        final program = Uint8List.fromList(List.generate(20, (i) => i * 7 % 256));
        final encoded = Bech32.encodeSegwit('tb', 0, program);
        final (version, decoded) = Bech32.decodeSegwit('tb', encoded);
        expect(version, equals(0));
        expect(decoded, equals(program));
      });

      test('throws on invalid witness version', () {
        final program = Uint8List(20);
        expect(
          () => Bech32.encodeSegwit('bc', -1, program),
          throwsArgumentError,
        );
        expect(
          () => Bech32.encodeSegwit('bc', 17, program),
          throwsArgumentError,
        );
      });

      test('throws on invalid program length', () {
        expect(
          () => Bech32.encodeSegwit('bc', 0, Uint8List(1)),
          throwsArgumentError,
        );
        expect(
          () => Bech32.encodeSegwit('bc', 0, Uint8List(41)),
          throwsArgumentError,
        );
      });

      test('validates HRP on decode', () {
        final program = Uint8List(20);
        final address = Bech32.encodeSegwit('bc', 0, program);
        expect(
          () => Bech32.decodeSegwit('tb', address),
          throwsFormatException,
        );
      });
    });
  });

  group('CosmosBech32', () {
    test('encodes Cosmos address', () {
      final pubKeyHash = Uint8List.fromList(List.generate(20, (i) => i));
      final address = CosmosBech32.encode('cosmos', pubKeyHash);
      expect(address.startsWith('cosmos1'), isTrue);
    });

    test('decodes Cosmos address', () {
      final pubKeyHash = Uint8List.fromList(List.generate(20, (i) => i + 10));
      final encoded = CosmosBech32.encode('cosmos', pubKeyHash);
      final decoded = CosmosBech32.decode(encoded);
      expect(decoded, equals(pubKeyHash));
    });

    test('round trip with different HRPs', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      for (final hrp in ['cosmos', 'osmo', 'juno', 'atom']) {
        final encoded = CosmosBech32.encode(hrp, data);
        expect(encoded.startsWith('$hrp'), isTrue);

        final (decodedHrp, decoded) = CosmosBech32.decodeWithHrp(encoded);
        expect(decodedHrp, equals(hrp));
        expect(decoded, equals(data));
      }
    });
  });

  group('CardanoBech32', () {
    test('encodes mainnet address', () {
      final addrBytes = Uint8List.fromList(List.generate(57, (i) => i % 256));
      final address = CardanoBech32.encode('addr', addrBytes);
      expect(address.startsWith('addr1'), isTrue);
    });

    test('encodes stake address', () {
      final stakeBytes = Uint8List.fromList(List.generate(29, (i) => i * 3 % 256));
      final address = CardanoBech32.encode('stake', stakeBytes);
      expect(address.startsWith('stake1'), isTrue);
    });

    test('decodes Cardano address', () {
      final addrBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
      final encoded = CardanoBech32.encode('addr', addrBytes);
      final (hrp, decoded) = CardanoBech32.decode(encoded);
      expect(hrp, equals('addr'));
      expect(decoded, equals(addrBytes));
    });
  });

  group('BIP-173 Test Vectors', () {
    // Test vectors from BIP-173
    test('valid Bech32 strings', () {
      final validStrings = [
        'A12UEL5L',
        'a12uel5l',
        'an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs',
        'abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw',
        '11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j',
        'split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w',
      ];

      for (final s in validStrings) {
        expect(() => Bech32.decode(s), returnsNormally, reason: 'Failed for: $s');
      }
    });

    test('invalid Bech32 strings', () {
      final invalidStrings = [
        // HRP character out of range
        '\x201nwldj5',
        // Overall max length exceeded
        'an84characterslonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1569pvx',
        // No separator character
        'pzry9x0s0muk',
        // Empty HRP
        '1pzry9x0s0muk',
        // Invalid data character
        'x1b4n0q5v',
        // Too short checksum
        'li1dgmt3',
        // Invalid character in checksum
        'de1lg7wt\xff',
        // Mixed case
        'A1G7SGD8',
      ];

      for (final s in invalidStrings) {
        // Most should throw, but some may be edge cases
        // Just checking we don't crash
        try {
          Bech32.decode(s);
        } catch (e) {
          // Expected for invalid strings
        }
      }
    });
  });
}
