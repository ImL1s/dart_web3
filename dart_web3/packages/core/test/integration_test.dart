import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';

/// Comprehensive integration tests for core utilities.
/// Tests cross-cutting functionality including address encoding,
/// RLP serialization, and unit conversions.
void main() {
  group('Core Integration Tests', () {
    group('Cross-Chain Address Encoding', () {
      test('Bitcoin mainnet P2PKH address generation', () {
        // Simulated hash160 of public key (20 bytes)
        final pubKeyHash = Uint8List.fromList([
          0x01, 0x09, 0x66, 0x77, 0x60, 0x06, 0x95, 0x3D, 0x55, 0x67,
          0x43, 0x9E, 0x5E, 0x39, 0xF8, 0x6A, 0x0D, 0x27, 0x3B, 0xEE,
        ]);

        // Version 0x00 for mainnet P2PKH
        final address = Base58Check.encodeWithVersion(0x00, pubKeyHash);

        expect(address.startsWith('1'), isTrue);
        expect(address.length, lessThanOrEqualTo(34));
      });

      test('Bitcoin testnet P2PKH address generation', () {
        final pubKeyHash = Uint8List.fromList(List.generate(20, (i) => i));

        // Version 0x6F for testnet P2PKH
        final address = Base58Check.encodeWithVersion(0x6F, pubKeyHash);

        expect(address.startsWith('m') || address.startsWith('n'), isTrue);
      });

      test('Bitcoin SegWit v0 address generation', () {
        // 20-byte witness program for P2WPKH
        final witnessProgram = Uint8List.fromList([
          0x75, 0x1e, 0x76, 0xe8, 0x19, 0x91, 0x96, 0xd4, 0x54, 0x94,
          0x1c, 0x45, 0xd1, 0xb3, 0xa3, 0x23, 0xf1, 0x43, 0x3b, 0xd6,
        ]);

        final address = Bech32.encodeSegwit('bc', 0, witnessProgram);

        expect(address.startsWith('bc1q'), isTrue);
      });

      test('Bitcoin SegWit v1 (Taproot) address generation', () {
        // 32-byte witness program for P2TR
        final witnessProgram = Uint8List.fromList(List.generate(32, (i) => i + 1));

        final address = Bech32.encodeSegwit('bc', 1, witnessProgram);

        expect(address.startsWith('bc1p'), isTrue);
      });

      test('Cosmos address encoding', () {
        final pubKeyHash = Uint8List.fromList(List.generate(20, (i) => i));

        final address = CosmosBech32.encode('cosmos', pubKeyHash);

        expect(address.startsWith('cosmos1'), isTrue);
      });

      test('Osmosis address encoding', () {
        final pubKeyHash = Uint8List.fromList(List.generate(20, (i) => i));

        final address = CosmosBech32.encode('osmo', pubKeyHash);

        expect(address.startsWith('osmo1'), isTrue);
      });

      test('Cardano Shelley address encoding', () {
        final addrBytes = Uint8List.fromList(List.generate(57, (i) => i % 256));

        final address = CardanoBech32.encode('addr', addrBytes);

        expect(address.startsWith('addr1'), isTrue);
      });

      test('Cardano stake address encoding', () {
        final stakeBytes = Uint8List.fromList(List.generate(29, (i) => i * 3 % 256));

        final address = CardanoBech32.encode('stake', stakeBytes);

        expect(address.startsWith('stake1'), isTrue);
      });

      test('cross-chain address round-trip', () {
        // Test that encoding and decoding work correctly for all formats
        final data = Uint8List.fromList(List.generate(20, (i) => i * 7 % 256));

        // Cosmos
        final cosmosAddr = CosmosBech32.encode('cosmos', data);
        final decodedCosmos = CosmosBech32.decode(cosmosAddr);
        expect(decodedCosmos, equals(data));

        // SegWit
        final segwitAddr = Bech32.encodeSegwit('bc', 0, data);
        final (version, decodedSegwit) = Bech32.decodeSegwit('bc', segwitAddr);
        expect(version, equals(0));
        expect(decodedSegwit, equals(data));

        // Base58Check
        final base58Addr = Base58Check.encodeWithVersion(0x00, data);
        final (ver, decodedBase58) = Base58Check.decodeWithVersion(base58Addr);
        expect(ver, equals(0x00));
        expect(decodedBase58, equals(data));
      });
    });

    group('Ethereum Address', () {
      test('creates valid Ethereum address', () {
        final addressHex = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
        final address = EthereumAddress.fromHex(addressHex);

        expect(address.hex, equals(addressHex.toLowerCase()));
        expect(address.bytes.length, equals(20));
      });

      test('validates address format', () {
        expect(EthereumAddress.isValid('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'), isTrue);
        expect(EthereumAddress.isValid('0x1234567890123456789012345678901234567890'), isTrue);
        expect(EthereumAddress.isValid('invalid'), isFalse);
        expect(EthereumAddress.isValid('0x123'), isFalse);
      });

      test('zero address', () {
        final zero = EthereumAddress.zero;

        expect(zero.isZero, isTrue);
        expect(zero.bytes.every((b) => b == 0), isTrue);
      });

      test('address equality', () {
        final addr1 = EthereumAddress.fromHex('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
        final addr2 = EthereumAddress.fromHex('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
        final addr3 = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');

        expect(addr1, equals(addr2)); // Case insensitive
        expect(addr1, isNot(equals(addr3)));
      });
    });

    group('RLP Encoding Integration', () {
      test('encodes simple transaction', () {
        // Legacy transaction structure
        final txData = [
          BigInt.from(1), // nonce
          BigInt.from(20000000000), // gasPrice
          BigInt.from(21000), // gasLimit
          HexUtils.decode('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'), // to
          BigInt.from(1000000000000000000), // value (1 ETH)
          Uint8List(0), // data
        ];

        final encoded = RLP.encode(txData);

        expect(encoded, isA<Uint8List>());
        expect(encoded.isNotEmpty, isTrue);
      });

      test('RLP round-trip for complex structure', () {
        final original = [
          'hello',
          Uint8List.fromList([1, 2, 3]),
          BigInt.from(12345),
          [
            'nested',
            Uint8List.fromList([4, 5, 6]),
            [
              'deeply nested',
              BigInt.from(9999),
            ],
          ],
        ];

        final encoded = RLP.encode(original);
        final decoded = RLP.decode(encoded);

        // Verify structure is preserved
        expect(decoded, isA<List>());
        expect((decoded as List).length, equals(4));
      });

      test('encodes EIP-1559 transaction', () {
        // EIP-1559 transaction structure
        final txData = [
          BigInt.from(1), // chainId
          BigInt.from(1), // nonce
          BigInt.from(1000000000), // maxPriorityFeePerGas
          BigInt.from(20000000000), // maxFeePerGas
          BigInt.from(21000), // gasLimit
          HexUtils.decode('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'), // to
          BigInt.from(1000000000000000000), // value
          Uint8List(0), // data
          [], // accessList
        ];

        // EIP-1559 transactions are prefixed with 0x02
        final encoded = RLP.encode(txData);
        final fullTx = Uint8List.fromList([0x02, ...encoded]);

        expect(fullTx[0], equals(0x02));
        expect(fullTx.length, greaterThan(1));
      });

      test('encodes access list', () {
        final accessList = [
          [
            HexUtils.decode('0x0000000000000000000000000000000000000001'), // address
            [
              Uint8List.fromList(List.filled(32, 0)), // storage slot 1
              Uint8List.fromList(List.filled(32, 1)), // storage slot 2
            ],
          ],
        ];

        final encoded = RLP.encode(accessList);

        expect(encoded, isA<Uint8List>());
      });
    });

    group('Unit Conversions', () {
      test('Wei to Ether conversion', () {
        final weiAmount = BigInt.from(10).pow(18); // 1 ETH in Wei

        final etherString = EthUnit.formatEther(weiAmount);

        expect(etherString, equals('1'));
      });

      test('Ether to Wei conversion', () {
        final etherString = '2.5';

        final weiAmount = EthUnit.ether(etherString);

        expect(weiAmount, equals(BigInt.from(25) * BigInt.from(10).pow(17)));
      });

      test('Gwei to Wei conversion', () {
        final gweiString = '20';

        final weiAmount = EthUnit.gwei(gweiString);

        expect(weiAmount, equals(BigInt.from(20) * BigInt.from(10).pow(9)));
      });

      test('Wei to Gwei formatting', () {
        final weiAmount = BigInt.from(20) * BigInt.from(10).pow(9);

        final gweiString = EthUnit.formatGwei(weiAmount);

        expect(gweiString, equals('20'));
      });

      test('unit conversion using convert', () {
        final amount = BigInt.from(1);

        // Convert from ether to gwei
        final converted = EthUnit.convert(
          amount,
          from: Unit.ether,
          to: Unit.gwei,
        );

        expect(converted, equals(BigInt.from(10).pow(9)));
      });

      test('format with decimals', () {
        final weiAmount = BigInt.parse('1234567890000000000'); // 1.23456789 ETH

        final formatted = EthUnit.formatEther(weiAmount);

        expect(formatted, equals('1.23456789'));
      });

      test('parse decimal ether', () {
        final etherString = '1.5';

        final weiAmount = EthUnit.ether(etherString);

        expect(weiAmount, equals(BigInt.parse('1500000000000000000')));
      });
    });

    group('Hex Utilities', () {
      test('encodes bytes to hex', () {
        final bytes = Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]);

        final hex = HexUtils.encode(bytes);

        expect(hex, equals('0xdeadbeef'));
      });

      test('decodes hex to bytes', () {
        final hex = '0xdeadbeef';

        final bytes = HexUtils.decode(hex);

        expect(bytes, equals(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])));
      });

      test('handles hex without prefix', () {
        final hex = 'deadbeef';

        final bytes = HexUtils.decode(hex);

        expect(bytes, equals(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])));
      });

      test('validates hex strings', () {
        expect(HexUtils.isValid('0xdeadbeef'), isTrue);
        expect(HexUtils.isValid('deadbeef'), isTrue);
        expect(HexUtils.isValid('DEADBEEF'), isTrue);
        expect(HexUtils.isValid('0xgg'), isFalse);
        expect(HexUtils.isValid('xyz'), isFalse);
      });

      test('strips 0x prefix', () {
        expect(HexUtils.strip0x('0xdeadbeef'), equals('deadbeef'));
        expect(HexUtils.strip0x('deadbeef'), equals('deadbeef'));
      });
    });

    group('Bytes Utilities', () {
      test('concatenates byte arrays', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([4, 5, 6]);

        final result = BytesUtils.concat([a, b]);

        expect(result, equals(Uint8List.fromList([1, 2, 3, 4, 5, 6])));
      });

      test('pads bytes to left', () {
        final bytes = Uint8List.fromList([1, 2, 3]);

        final padded = BytesUtils.pad(bytes, 6, left: true);

        expect(padded, equals(Uint8List.fromList([0, 0, 0, 1, 2, 3])));
      });

      test('pads bytes to right', () {
        final bytes = Uint8List.fromList([1, 2, 3]);

        final padded = BytesUtils.pad(bytes, 6, left: false);

        expect(padded, equals(Uint8List.fromList([1, 2, 3, 0, 0, 0])));
      });

      test('slices byte array', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

        final slice = BytesUtils.slice(bytes, 2, 4);

        expect(slice, equals(Uint8List.fromList([3, 4])));
      });

      test('compares byte arrays', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2, 3]);
        final c = Uint8List.fromList([1, 2, 4]);

        expect(BytesUtils.equals(a, b), isTrue);
        expect(BytesUtils.equals(a, c), isFalse);
      });

      test('converts int to bytes', () {
        final value = 0x12345678;

        final bytes = BytesUtils.intToBytes(value, length: 4);

        expect(bytes, equals(Uint8List.fromList([0x12, 0x34, 0x56, 0x78])));
      });

      test('converts bytes to int', () {
        final bytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);

        final value = BytesUtils.bytesToInt(bytes);

        expect(value, equals(0x12345678));
      });

      test('converts BigInt to bytes', () {
        final value = BigInt.from(256);

        final bytes = BytesUtils.bigIntToBytes(value);

        expect(bytes, equals(Uint8List.fromList([0x01, 0x00])));
      });

      test('converts bytes to BigInt', () {
        final bytes = Uint8List.fromList([0x01, 0x00]);

        final value = BytesUtils.bytesToBigInt(bytes);

        expect(value, equals(BigInt.from(256)));
      });

      test('trims leading zeros', () {
        final bytes = Uint8List.fromList([0, 0, 0, 1, 2, 3]);

        final trimmed = BytesUtils.trimLeadingZeros(bytes);

        expect(trimmed, equals(Uint8List.fromList([1, 2, 3])));
      });

      test('trims trailing zeros', () {
        final bytes = Uint8List.fromList([1, 2, 3, 0, 0, 0]);

        final trimmed = BytesUtils.trimTrailingZeros(bytes);

        expect(trimmed, equals(Uint8List.fromList([1, 2, 3])));
      });

      test('XORs byte arrays', () {
        final a = Uint8List.fromList([0xFF, 0x00, 0xAA]);
        final b = Uint8List.fromList([0x0F, 0xF0, 0x55]);

        final result = BytesUtils.xor(a, b);

        expect(result, equals(Uint8List.fromList([0xF0, 0xF0, 0xFF])));
      });
    });

    group('Exception Handling', () {
      test('InvalidAddressException includes details', () {
        final exception = InvalidAddressException('0xinvalid', 'Invalid hex characters');

        expect(exception.address, equals('0xinvalid'));
        expect(exception.reason, equals('Invalid hex characters'));
        expect(exception.message, contains('0xinvalid'));
        expect(exception.message, contains('Invalid hex characters'));
        expect(exception.code, equals('INVALID_ADDRESS'));
      });

      test('HexException provides error info', () {
        final exception = HexException('Invalid hex string');

        expect(exception.message, equals('Invalid hex string'));
        expect(exception.code, equals('HEX_ERROR'));
      });

      test('RlpException provides error info', () {
        final exception = RlpException('Invalid RLP encoding');

        expect(exception.message, equals('Invalid RLP encoding'));
        expect(exception.code, equals('RLP_ERROR'));
      });

      test('UnitConversionException provides error info', () {
        final exception = UnitConversionException('Invalid decimal format');

        expect(exception.message, equals('Invalid decimal format'));
        expect(exception.code, equals('UNIT_CONVERSION_ERROR'));
      });
    });

    group('Complete Transaction Building Flow', () {
      test('builds and encodes legacy transaction', () {
        // 1. Create transaction data
        final nonce = BigInt.from(5);
        final gasPrice = BigInt.from(20000000000); // 20 Gwei
        final gasLimit = BigInt.from(21000);
        final to = EthereumAddress.fromHex(
          '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        );
        final value = EthUnit.ether('0.1');
        final data = Uint8List(0);
        final chainId = BigInt.from(1);

        // 2. Build unsigned transaction for signing
        final unsignedTx = [
          nonce,
          gasPrice,
          gasLimit,
          to.bytes,
          value,
          data,
          chainId,
          BigInt.zero, // r (empty for EIP-155 signing)
          BigInt.zero, // s (empty for EIP-155 signing)
        ];

        // 3. Encode for signing
        final signingData = RLP.encode(unsignedTx);

        expect(signingData, isA<Uint8List>());
        expect(signingData.isNotEmpty, isTrue);

        // 4. Simulate signature (in real use, this would come from signing)
        final v = BigInt.from(37); // chainId * 2 + 35
        final r = BigInt.parse(
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        final s = BigInt.parse(
          '0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
        );

        // 5. Build signed transaction
        final signedTx = [
          nonce,
          gasPrice,
          gasLimit,
          to.bytes,
          value,
          data,
          v,
          r,
          s,
        ];

        // 6. Encode signed transaction
        final encodedTx = RLP.encode(signedTx);

        expect(encodedTx, isA<Uint8List>());
        expect(encodedTx.length, greaterThan(signingData.length));

        // 7. Format for broadcast
        final txHex = HexUtils.encode(encodedTx);

        expect(txHex.startsWith('0x'), isTrue);
      });

      test('builds and encodes EIP-1559 transaction', () {
        // 1. Create EIP-1559 transaction data
        final chainId = BigInt.from(1);
        final nonce = BigInt.from(5);
        final maxPriorityFeePerGas = BigInt.from(1500000000); // 1.5 Gwei
        final maxFeePerGas = BigInt.from(30000000000); // 30 Gwei
        final gasLimit = BigInt.from(21000);
        final to = EthereumAddress.fromHex(
          '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
        );
        final value = EthUnit.ether('0.1');
        final data = Uint8List(0);
        final accessList = <List>[]; // Empty access list

        // 2. Build unsigned transaction for signing
        final unsignedTx = [
          chainId,
          nonce,
          maxPriorityFeePerGas,
          maxFeePerGas,
          gasLimit,
          to.bytes,
          value,
          data,
          accessList,
        ];

        // 3. Encode for signing (with transaction type prefix)
        final rlpEncoded = RLP.encode(unsignedTx);
        final signingData = Uint8List.fromList([0x02, ...rlpEncoded]);

        expect(signingData[0], equals(0x02)); // EIP-1559 type

        // 4. Simulate signature
        final yParity = BigInt.from(0);
        final r = BigInt.parse(
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        final s = BigInt.parse(
          '0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
        );

        // 5. Build signed transaction
        final signedTx = [
          chainId,
          nonce,
          maxPriorityFeePerGas,
          maxFeePerGas,
          gasLimit,
          to.bytes,
          value,
          data,
          accessList,
          yParity,
          r,
          s,
        ];

        // 6. Encode signed transaction with type prefix
        final signedRlp = RLP.encode(signedTx);
        final encodedTx = Uint8List.fromList([0x02, ...signedRlp]);

        expect(encodedTx[0], equals(0x02));

        // 7. Format for broadcast
        final txHex = HexUtils.encode(encodedTx);

        expect(txHex.startsWith('0x02'), isTrue);
      });
    });

    group('Base58 and Bech32 Integration', () {
      test('Base58 encodes and decodes correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        final encoded = Base58.encode(data);
        final decoded = Base58.decode(encoded);

        expect(decoded, equals(data));
      });

      test('Base58Check with different versions', () {
        final data = Uint8List.fromList(List.generate(20, (i) => i));

        // Bitcoin mainnet P2PKH (version 0x00)
        final mainnetAddr = Base58Check.encodeWithVersion(0x00, data);
        expect(mainnetAddr.startsWith('1'), isTrue);

        // Bitcoin testnet P2PKH (version 0x6F)
        final testnetAddr = Base58Check.encodeWithVersion(0x6F, data);
        expect(testnetAddr.startsWith('m') || testnetAddr.startsWith('n'), isTrue);

        // Bitcoin mainnet P2SH (version 0x05)
        final p2shAddr = Base58Check.encodeWithVersion(0x05, data);
        expect(p2shAddr.startsWith('3'), isTrue);
      });

      test('Bech32 vs Bech32m', () {
        final data = [0, 1, 2, 3, 4, 5];

        final bech32 = Bech32.encode('test', data, Bech32Variant.bech32);
        final bech32m = Bech32.encode('test', data, Bech32Variant.bech32m);

        // Same data, different checksums
        expect(bech32, isNot(equals(bech32m)));

        // Both decode to same data but with different variants
        final (hrp1, decoded1, variant1) = Bech32.decode(bech32);
        final (hrp2, decoded2, variant2) = Bech32.decode(bech32m);

        expect(decoded1, equals(decoded2));
        expect(variant1, equals(Bech32Variant.bech32));
        expect(variant2, equals(Bech32Variant.bech32m));
      });

      test('SegWit v0 uses Bech32, v1+ uses Bech32m', () {
        final program20 = Uint8List.fromList(List.generate(20, (i) => i));
        final program32 = Uint8List.fromList(List.generate(32, (i) => i));

        // v0 (P2WPKH) should use Bech32
        final v0Addr = Bech32.encodeSegwit('bc', 0, program20);
        expect(v0Addr.startsWith('bc1q'), isTrue);

        // v1 (P2TR) should use Bech32m
        final v1Addr = Bech32.encodeSegwit('bc', 1, program32);
        expect(v1Addr.startsWith('bc1p'), isTrue);
      });

      test('bit conversion 8-bit to 5-bit and back', () {
        final original = [0xDE, 0xAD, 0xBE, 0xEF];

        final fiveBit = Bech32.convertBits(original, 8, 5);
        final recovered = Bech32.convertBits(fiveBit, 5, 8, pad: false);

        expect(recovered, equals(original));
      });
    });
  });
}
