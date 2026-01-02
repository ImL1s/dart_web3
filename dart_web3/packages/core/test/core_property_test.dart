import 'dart:typed_data';

import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:glados/glados.dart';

/// Custom generators for property-based testing
extension Uint8ListGenerators on Any {
  /// Generator for Uint8List with exact length
  Generator<Uint8List> uint8ListWithLength(int length) {
    return any.list(any.intInRange(0, 256)).map(
          (list) => Uint8List.fromList(
            List.generate(length, (i) => i < list.length ? list[i] % 256 : 0),
          ),
        );
  }

  /// Generator for Uint8List with length in range
  /// Uses the list length modulo to determine actual length deterministically
  Generator<Uint8List> uint8ListWithLengthInRange(int minLength, int maxLength) {
    return any.list(any.intInRange(0, 256)).map((list) {
      // Use list content to determine length deterministically
      final range = maxLength - minLength + 1;
      final lengthSeed = list.isEmpty ? 0 : list.fold<int>(0, (a, b) => a + b);
      final length = minLength + (lengthSeed % range);
      return Uint8List.fromList(
        List.generate(length, (i) => i < list.length ? list[i] % 256 : 0),
      );
    });
  }

  /// Generator for Uint8List of any length (0-50 bytes)
  Generator<Uint8List> get uint8List => uint8ListWithLengthInRange(0, 50);
}

/// Property-based tests for Core module
/// These tests validate the correctness properties defined in the design document.
///
/// Properties tested:
/// - Property 24: Address Checksum Validation
/// - Property 25: Unit Conversion Accuracy
/// - Property 26: Hex Encoding Round Trip
/// - Property 27: RLP Encoding Round Trip
/// - Property 28: Core Encoding Round Trip
///
/// Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.8

void main() {
  group('Core Module Property-Based Tests', () {
    // =========================================================================
    // Property 24: Address Checksum Validation
    // *For any* Ethereum address, the EthereumAddress class should correctly
    // validate checksums according to EIP-55
    // **Validates: Requirements 14.1**
    // =========================================================================
    group('Property 24: Address Checksum Validation', () {
      Glados(any.uint8ListWithLength(20)).test(
        'For any 20-byte array, creating an EthereumAddress should succeed',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 24: Address Checksum Validation**
          final addr = EthereumAddress(bytes);
          expect(addr.bytes.length, equals(20));
          expect(addr.hex.startsWith('0x'), isTrue);
          expect(addr.hex.length, equals(42)); // 0x + 40 hex chars
        },
      );

      Glados(any.uint8ListWithLength(20)).test(
        'For any address bytes, hex representation should be valid and parseable',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 24: Address Checksum Validation**
          final addr = EthereumAddress(bytes);
          final hex = addr.hex;

          // Should be able to parse back
          final parsed = EthereumAddress.fromHex(hex);
          expect(BytesUtils.equals(parsed.bytes, addr.bytes), isTrue);
        },
      );

      Glados(any.uint8ListWithLength(20)).test(
        'For any address, isValid should return true for its hex representation',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 24: Address Checksum Validation**
          final addr = EthereumAddress(bytes);
          expect(EthereumAddress.isValid(addr.hex), isTrue);
        },
      );

      Glados(any.uint8ListWithLength(20)).test(
        'For any address, equality should be reflexive and consistent',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 24: Address Checksum Validation**
          final addr1 = EthereumAddress(Uint8List.fromList(bytes));
          final addr2 = EthereumAddress(Uint8List.fromList(bytes));

          expect(addr1, equals(addr2));
          expect(addr1.hashCode, equals(addr2.hashCode));
        },
      );
    });

    // =========================================================================
    // Property 25: Unit Conversion Accuracy
    // *For any* value, converting between wei/gwei/ether should be
    // mathematically accurate and reversible
    // **Validates: Requirements 14.2**
    // =========================================================================
    group('Property 25: Unit Conversion Accuracy', () {
      Glados(any.positiveIntOrZero).test(
        'For any positive integer, wei conversion should be identity',
        (value) {
          // **Feature: dart-web3-sdk, Property 25: Unit Conversion Accuracy**
          final wei = EthUnit.wei(value.toString());
          final formatted = EthUnit.formatWei(wei);
          expect(formatted, equals(value.toString()));
        },
      );

      Glados(any.intInRange(0, 1000000)).test(
        'For any integer in range, ether to wei and back should be accurate',
        (value) {
          // **Feature: dart-web3-sdk, Property 25: Unit Conversion Accuracy**
          final wei = EthUnit.ether(value.toString());
          final formatted = EthUnit.formatEther(wei);
          final backToWei = EthUnit.ether(formatted);
          expect(backToWei, equals(wei));
        },
      );

      Glados(any.intInRange(0, 1000000000)).test(
        'For any integer in range, gwei to wei and back should be accurate',
        (value) {
          // **Feature: dart-web3-sdk, Property 25: Unit Conversion Accuracy**
          final wei = EthUnit.gwei(value.toString());
          final formatted = EthUnit.formatGwei(wei);
          final backToWei = EthUnit.gwei(formatted);
          expect(backToWei, equals(wei));
        },
      );

      Glados(any.positiveIntOrZero).test(
        'For any value, unit conversion should preserve value',
        (value) {
          // **Feature: dart-web3-sdk, Property 25: Unit Conversion Accuracy**
          final bigValue = BigInt.from(value);

          // ether -> gwei -> wei -> gwei -> ether should preserve value
          final inGwei = EthUnit.convert(bigValue, from: Unit.ether, to: Unit.gwei);
          final inWei = EthUnit.convert(inGwei, from: Unit.gwei, to: Unit.wei);
          final backToGwei = EthUnit.convert(inWei, from: Unit.wei, to: Unit.gwei);
          final backToEther = EthUnit.convert(backToGwei, from: Unit.gwei, to: Unit.ether);

          expect(backToEther, equals(bigValue));
        },
      );

      Glados(any.intInRange(1, 1000000)).test(
        'For any positive value, ether conversion should multiply by 10^18',
        (value) {
          // **Feature: dart-web3-sdk, Property 25: Unit Conversion Accuracy**
          final wei = EthUnit.ether(value.toString());
          final expected = BigInt.from(value) * EthUnit.weiPerEther;
          expect(wei, equals(expected));
        },
      );

      Glados(any.intInRange(1, 1000000000)).test(
        'For any positive value, gwei conversion should multiply by 10^9',
        (value) {
          // **Feature: dart-web3-sdk, Property 25: Unit Conversion Accuracy**
          final wei = EthUnit.gwei(value.toString());
          final expected = BigInt.from(value) * EthUnit.weiPerGwei;
          expect(wei, equals(expected));
        },
      );
    });

    // =========================================================================
    // Property 26: Hex Encoding Round Trip
    // *For any* byte array, hex encoding then decoding should produce the
    // original bytes with proper 0x prefix handling
    // **Validates: Requirements 14.3**
    // =========================================================================
    group('Property 26: Hex Encoding Round Trip', () {
      Glados(any.uint8List).test(
        'For any byte array, encode then decode should return original bytes',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 26: Hex Encoding Round Trip**
          final encoded = HexUtils.encode(bytes);
          final decoded = HexUtils.decode(encoded);
          expect(BytesUtils.equals(decoded, bytes), isTrue);
        },
      );

      Glados(any.uint8List).test(
        'For any byte array, encoding should produce valid hex',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 26: Hex Encoding Round Trip**
          final encoded = HexUtils.encode(bytes);
          expect(HexUtils.isValid(encoded), isTrue);
          expect(encoded.startsWith('0x'), isTrue);
        },
      );

      Glados(any.uint8List).test(
        'For any byte array, encoding without prefix then with prefix should be consistent',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 26: Hex Encoding Round Trip**
          final withPrefix = HexUtils.encode(bytes);
          final withoutPrefix = HexUtils.encode(bytes, prefix: false);

          expect(withPrefix, equals('0x$withoutPrefix'));
          expect(HexUtils.strip0x(withPrefix), equals(withoutPrefix));
        },
      );

      Glados(any.uint8List).test(
        'For any byte array, encoded length should be 2 * bytes.length + 2 (for 0x)',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 26: Hex Encoding Round Trip**
          final encoded = HexUtils.encode(bytes);
          expect(encoded.length, equals(bytes.length * 2 + 2));
        },
      );

      Glados(any.uint8List).test(
        'For any byte array, add0x and strip0x should be inverses',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 26: Hex Encoding Round Trip**
          final hex = HexUtils.encode(bytes, prefix: false);
          final withPrefix = HexUtils.add0x(hex);
          final stripped = HexUtils.strip0x(withPrefix);
          expect(stripped, equals(hex));
        },
      );
    });

    // =========================================================================
    // Property 27: RLP Encoding Round Trip
    // *For any* valid data structure, RLP encoding then decoding should
    // produce equivalent data
    // **Validates: Requirements 14.4**
    // =========================================================================
    group('Property 27: RLP Encoding Round Trip', () {
      Glados(any.uint8List).test(
        'For any byte array, RLP encode then decode should return original bytes',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 27: RLP Encoding Round Trip**
          final encoded = RLP.encode(bytes);
          final dynamic decoded = RLP.decode(encoded);
          expect(decoded, isA<Uint8List>());
          expect(BytesUtils.equals(decoded as Uint8List, bytes), isTrue);
        },
      );

      Glados(any.positiveIntOrZero).test(
        'For any non-negative integer, RLP encode then decode should preserve value',
        (value) {
          // **Feature: dart-web3-sdk, Property 27: RLP Encoding Round Trip**
          final encoded = RLP.encode(value);
          final decoded = RLP.decode(encoded);

          // Decoded value is Uint8List, convert back to int
          final decodedBytes = decoded as Uint8List;
          final decodedValue =
              decodedBytes.isEmpty ? 0 : BytesUtils.bytesToInt(decodedBytes);

          expect(decodedValue, equals(value));
        },
      );

      Glados(any.intInRange(0, 1 << 30)).test(
        'For any BigInt in range, RLP encode then decode should preserve value',
        (value) {
          // **Feature: dart-web3-sdk, Property 27: RLP Encoding Round Trip**
          final bigValue = BigInt.from(value);
          final encoded = RLP.encode(bigValue);
          final decoded = RLP.decode(encoded);

          // Decoded value is Uint8List, convert back to BigInt
          final decodedBytes = decoded as Uint8List;
          final decodedValue =
              decodedBytes.isEmpty ? BigInt.zero : BytesUtils.bytesToBigInt(decodedBytes);

          expect(decodedValue, equals(bigValue));
        },
      );

      Glados(any.list(any.uint8ListWithLengthInRange(0, 20))).test(
        'For any list of byte arrays, RLP encode then decode should preserve structure',
        (list) {
          // **Feature: dart-web3-sdk, Property 27: RLP Encoding Round Trip**
          final encoded = RLP.encode(list);
          final dynamic decoded = RLP.decode(encoded);

          expect(decoded, isA<List<dynamic>>());
          final decodedList = decoded as List<dynamic>;
          expect(decodedList.length, equals(list.length));

          for (var i = 0; i < list.length; i++) {
            expect(BytesUtils.equals(decodedList[i] as Uint8List, list[i]), isTrue);
          }
        },
      );

      Glados(any.uint8List).test(
        'For any byte array, RLP encoding should produce valid RLP',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 27: RLP Encoding Round Trip**
          final encoded = RLP.encode(bytes);

          // Valid RLP should be decodable without throwing
          expect(() => RLP.decode(encoded), returnsNormally);
        },
      );
    });

    // =========================================================================
    // Property 28: Core Encoding Round Trip
    // *For any* encoding operation in the Core module, encoding then decoding
    // should produce the original value
    // **Validates: Requirements 14.8**
    // =========================================================================
    group('Property 28: Core Encoding Round Trip', () {
      Glados(any.intInRange(0, 1 << 30)).test(
        'For any BigInt, bigIntToBytes then bytesToBigInt should return original',
        (value) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          final bigValue = BigInt.from(value);
          final bytes = BytesUtils.bigIntToBytes(bigValue);
          final result = BytesUtils.bytesToBigInt(bytes);
          expect(result, equals(bigValue));
        },
      );

      Glados(any.positiveIntOrZero).test(
        'For any non-negative int, intToBytes then bytesToInt should return original',
        (value) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          final bytes = BytesUtils.intToBytes(value);
          final result = BytesUtils.bytesToInt(bytes);
          expect(result, equals(value));
        },
      );

      Glados2(any.uint8ListWithLengthInRange(0, 50), any.uint8ListWithLengthInRange(0, 50)).test(
        'For any two byte arrays, concat then slice should recover originals',
        (a, b) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          final concatenated = BytesUtils.concat([a, b]);
          final recoveredA = BytesUtils.slice(concatenated, 0, a.length);
          final recoveredB = BytesUtils.slice(concatenated, a.length);

          expect(BytesUtils.equals(recoveredA, a), isTrue);
          expect(BytesUtils.equals(recoveredB, b), isTrue);
        },
      );

      Glados2(any.uint8ListWithLengthInRange(0, 32), any.intInRange(0, 64)).test(
        'For any byte array and padding length, pad should increase or maintain length',
        (bytes, extraPadding) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          final targetLength = bytes.length + extraPadding;
          final padded = BytesUtils.pad(bytes, targetLength);

          expect(padded.length, equals(targetLength));

          // Original bytes should be preserved (at the end for left padding)
          final recovered = BytesUtils.slice(padded, targetLength - bytes.length);
          expect(BytesUtils.equals(recovered, bytes), isTrue);
        },
      );

      Glados(any.uint8ListWithLengthInRange(0, 50)).test(
        'For any byte array, trimLeadingZeros should not change non-zero prefix bytes',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          final trimmed = BytesUtils.trimLeadingZeros(bytes);

          // If trimmed is not empty, first byte should be non-zero
          if (trimmed.isNotEmpty) {
            expect(trimmed[0], isNot(equals(0)));
          }

          // Trimmed should be suffix of original
          if (trimmed.isNotEmpty) {
            final suffix = BytesUtils.slice(bytes, bytes.length - trimmed.length);
            expect(BytesUtils.equals(suffix, trimmed), isTrue);
          }
        },
      );

      Glados2(any.uint8ListWithLengthInRange(1, 32), any.uint8ListWithLengthInRange(1, 32)).test(
        'For any two equal-length byte arrays, xor should be self-inverse',
        (a, b) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          // Make arrays same length
          final minLen = a.length < b.length ? a.length : b.length;
          final aSlice = BytesUtils.slice(a, 0, minLen);
          final bSlice = BytesUtils.slice(b, 0, minLen);

          // XOR is self-inverse: (a XOR b) XOR b = a
          final xored = BytesUtils.xor(aSlice, bSlice);
          final recovered = BytesUtils.xor(xored, bSlice);
          expect(BytesUtils.equals(recovered, aSlice), isTrue);
        },
      );

      Glados(any.uint8ListWithLength(20)).test(
        'For any 20-byte array, address round trip should preserve bytes',
        (bytes) {
          // **Feature: dart-web3-sdk, Property 28: Core Encoding Round Trip**
          final addr = EthereumAddress(bytes);
          final hex = addr.hex;
          final parsed = EthereumAddress.fromHex(hex);
          expect(BytesUtils.equals(parsed.bytes, bytes), isTrue);
        },
      );
    });
  });
}
