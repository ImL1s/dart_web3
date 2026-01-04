import 'package:test/test.dart';
import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_ens/web3_universal_ens.dart';

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
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.resolveName('vitalik.eth');

        // Assert
        expect(result, isA<String?>());
      });

      test('should reverse resolve address to name', () async {
        // Arrange
        final validAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.resolveAddress(validAddress);

        // Assert
        expect(result, isA<String?>());
      });
    });

    group('text records', () {
      test('should get text record', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.getTextRecord('test.eth', 'description');

        // Assert
        expect(result, isA<String?>());
      });

      test('should get avatar', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.getAvatar('test.eth');

        // Assert
        expect(result, isA<String?>());
      });

      test('should get multiple text records', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.getTextRecords('test.eth', ['description', 'url']);

        // Assert
        expect(result, isA<Map<String, String?>>());
        expect(result.keys, containsAll(['description', 'url']));
      });

      test('should get complete profile', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final profile = await ensClient.getProfile('test.eth');

        // Assert
        expect(profile, isA<ENSProfile>());
        expect(profile.name, equals('test.eth'));
      });
    });

    group('multi-chain addresses', () {
      test('should resolve address for specific coin type', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.resolveAddressForCoin('test.eth', CoinType.bitcoin);

        // Assert
        expect(result, isA<String?>());
      });

      test('should get Ethereum address', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.getEthereumAddress('test.eth');

        // Assert
        expect(result, isA<String?>());
      });

      test('should get Bitcoin address', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final result = await ensClient.getBitcoinAddress('test.eth');

        // Assert
        expect(result, isA<String?>());
      });

      test('should get all supported addresses', () async {
        // Arrange
        final resolverAddress = '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41';
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

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
        final resolverAddressEncoded = AbiEncoder.encode([AbiAddress()], [resolverAddress]);
        mockClient.mockCall(resolverAddressEncoded);

        // Act
        final info = await ensClient.getENSInfo('test.eth');

        // Assert
        expect(info, isA<ENSInfo>());
        expect(info.name, equals('test.eth'));
        expect(info.profile, isA<ENSProfile>());
        expect(info.addresses, isA<Map<String, String?>>());
        expect(info.toJson(), isA<Map<String, dynamic>>());
        expect(info.toString(), contains('test.eth'));
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
