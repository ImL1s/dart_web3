import 'package:test/test.dart';
import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_ens/web3_universal_ens.dart';
import 'dart:typed_data';

import 'mock_client.dart';

void main() {
  group('ENSClient', () {
    late MockPublicClient mockClient;
    late ENSClient ensClient;

    setUp(() {
      mockClient = MockPublicClient();
      ensClient = ENSClient(client: mockClient);
    });

    group('basic resolution', () {
      test('should resolve ENS name to address', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        final finalAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
        final finalAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [finalAddress]);
        mockClient.mockCall(finalAddressEncoded);

        // Act
        final result = await ensClient.resolveName('vitalik.eth');

        // Assert
        expect(result?.toLowerCase(), equals(finalAddress.toLowerCase()));
      });

      test('should reverse resolve address to name', () async {
        // Arrange
        final validAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);

        final name = 'vitalik.eth';
        final nameEncoded = AbiEncoder.encode([AbiString()], [name]);

        // 1. Resolver for reverse name
        mockClient.mockCall(resolverAddressEncoded);
        // 2. Name function call
        mockClient.mockCall(nameEncoded);
        // 3. Verification: resolver for name
        mockClient.mockCall(resolverAddressEncoded);
        // 4. Verification: address for name
        final addressEncoded =
            AbiEncoder.encode([AbiAddress()], [validAddress]);
        mockClient.mockCall(addressEncoded);

        // Act
        final result = await ensClient.resolveAddress(validAddress);

        // Assert
        expect(result, equals(name));
      });
    });

    group('text records', () {
      test('should get text record', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        final textValue = 'description text';
        final textEncoded = AbiEncoder.encode([AbiString()], [textValue]);
        mockClient.mockCall(textEncoded);

        // Act
        final result = await ensClient.getTextRecord('test.eth', 'description');

        // Assert
        expect(result, equals(textValue));
      });

      test('should get avatar', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        final avatarUrl = 'https://example.com/avatar.png';
        final avatarEncoded = AbiEncoder.encode([AbiString()], [avatarUrl]);
        mockClient.mockCall(avatarEncoded);

        // Act
        final result = await ensClient.getAvatar('test.eth');

        // Assert
        expect(result, equals(avatarUrl));
      });

      test('should get multiple text records', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        mockClient.mockCall(AbiEncoder.encode([AbiString()], ['desc']));
        mockClient
            .mockCall(AbiEncoder.encode([AbiString()], ['https://test.com']));

        // Act
        final result =
            await ensClient.getTextRecords('test.eth', ['description', 'url']);

        // Assert
        expect(result, isA<Map<String, String?>>());
        expect(result['description'], equals('desc'));
        expect(result['url'], equals('https://test.com'));
      });

      test('should get complete profile', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // 13 text records in getProfile
        for (var i = 0; i < 13; i++) {
          mockClient.mockCall(AbiEncoder.encode([AbiString()], ['value_$i']));
        }

        // Act
        final profile = await ensClient.getProfile('test.eth');

        // Assert
        expect(profile, isA<ENSProfile>());
        expect(profile.name, equals('test.eth'));
        expect(profile.description,
            equals('value_1')); // description is 2nd in list
      });
    });

    group('multi-chain addresses', () {
      test('should resolve address for specific coin type', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        final btcAddress = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
        final btcEncoded = AbiEncoder.encode(
            [AbiBytes()], [Uint8List.fromList(btcAddress.codeUnits)]);
        mockClient.mockCall(btcEncoded);

        // Act
        final result =
            await ensClient.resolveAddressForCoin('test.eth', CoinType.bitcoin);

        // Assert
        final expectedHex =
            '0x${Uint8List.fromList(btcAddress.codeUnits).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
        expect(result, equals(expectedHex));
      });

      test('should get Ethereum address', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        final ethAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
        // Ethereum in multicoin resolver is also bytes
        final ethBytes = Uint8List.fromList([
          0xd8,
          0xda,
          0x6b,
          0xf2,
          0x69,
          0x64,
          0xaf,
          0x9d,
          0x7e,
          0xed,
          0x9e,
          0x03,
          0xe5,
          0x34,
          0x15,
          0xd3,
          0x7a,
          0xa9,
          0x60,
          0x45
        ]);
        final ethEncoded = AbiEncoder.encode([AbiBytes()], [ethBytes]);
        mockClient.mockCall(ethEncoded);

        // Act
        final result = await ensClient.getEthereumAddress('test.eth');

        // Assert
        expect(result?.toLowerCase(), equals(ethAddress.toLowerCase()));
      });

      test('should get Bitcoin address', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        final btcAddress = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
        final btcEncoded = AbiEncoder.encode(
            [AbiBytes()], [Uint8List.fromList(btcAddress.codeUnits)]);
        mockClient.mockCall(btcEncoded);

        // Act
        final result = await ensClient.getBitcoinAddress('test.eth');

        // Assert
        final expectedHex =
            '0x${Uint8List.fromList(btcAddress.codeUnits).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
        expect(result, equals(expectedHex));
      });

      test('should get all supported addresses', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // 5 supported coins in getAllAddresses: BTC, LTC, DOGE, ETH, XMR
        // With resolver caching, only one registry call is made.
        for (var i = 0; i < 5; i++) {
          final addrStr = 'addr_$i';
          final addrBytes = Uint8List.fromList(addrStr.codeUnits);
          mockClient.mockCall(AbiEncoder.encode([AbiBytes()], [addrBytes]));
        }

        // Act
        final result = await ensClient.getAllAddresses('test.eth');

        // Assert
        expect(result, isA<Map<String, String?>>());
        expect(result.keys, contains('bitcoin'));
        expect(result.keys, contains('ethereum'));
      });
    });

    group('comprehensive info', () {
      test('should get complete ENS information', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded =
            AbiEncoder.encode([AbiAddress()], [resolverAddress]);

        // getProfile: 1 resolver + 13 text
        mockClient.mockCall(resolverAddressEncoded);
        for (var i = 0; i < 13; i++) {
          mockClient.mockCall(AbiEncoder.encode([AbiString()], ['text_$i']));
        }

        // getAllAddresses in getENSInfo uses a DIFFERENT ENSClient._multichainResolver instance (non-shared cache in this test setup)
        // Wait, ENSClient has one _resolver, one _records, one _multichainResolver.
        // So getProfile (using _records) and getAllAddresses (using _multichainResolver) have SEPARATE caches.
        mockClient.mockCall(resolverAddressEncoded);
        for (var i = 0; i < 5; i++) {
          final addrStr = 'addr_$i';
          final addrBytes = Uint8List.fromList(addrStr.codeUnits);
          mockClient.mockCall(AbiEncoder.encode([AbiBytes()], [addrBytes]));
        }

        // Act
        final info = await ensClient.getENSInfo('test.eth');

        // Assert
        expect(info, isA<ENSInfo>());
        expect(info.name, equals('test.eth'));
        expect(info.profile, isA<ENSProfile>());
        expect(info.addresses, isA<Map<String, String?>>());
      });
    });

    group('utility methods', () {
      test('should validate ENS names', () {
        expect(ENSClient.isValidENSName('vitalik.eth'), isTrue);
        expect(ENSClient.isValidENSName('invalid name'), isFalse);
      });

      test('should clear all caches', () {
        // Act
        ensClient.clearCache();

        // Assert - Should not throw
        expect(true, isTrue);
      });
    });

    group('error handling', () {
      test('should handle RPC errors gracefully', () async {
        // Arrange
        mockClient.mockCallThrow('Network error');

        // Act
        final result = await ensClient.resolveName('test.eth');

        // Assert
        expect(result, isNull);
      });
    });
  });
}
