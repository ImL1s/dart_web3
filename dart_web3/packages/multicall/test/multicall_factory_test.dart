import 'package:test/test.dart';
import 'package:web3_universal_multicall/web3_universal_multicall.dart';

import 'mock_client.dart';

void main() {
  group('MulticallFactory', () {
    late MockPublicClient publicClient;

    setUp(() {
      publicClient = MockPublicClient();
    });

    group('create', () {
      test('should create multicall with default address for supported chain', () {
        final multicall = MulticallFactory.create(
          publicClient: publicClient,
        );

        expect(multicall, isA<Multicall>());
      });

      test('should use provided contract address', () {
        const customAddress = '0x1234567890123456789012345678901234567890';
        
        final multicall = MulticallFactory.create(
          publicClient: publicClient,
          contractAddress: customAddress,
        );

        expect(multicall, isA<Multicall>());
      });

      test('should use provided version', () {
        final multicall = MulticallFactory.create(
          publicClient: publicClient,
          version: MulticallVersion.v2,
        );

        expect(multicall, isA<Multicall>());
      });


    });

    group('isSupported', () {
      test('should return true for Ethereum mainnet', () {
        expect(MulticallFactory.isSupported(1), isTrue);
      });

      test('should return true for Polygon', () {
        expect(MulticallFactory.isSupported(137), isTrue);
      });

      test('should return true for BSC', () {
        expect(MulticallFactory.isSupported(56), isTrue);
      });

      test('should return true for Arbitrum', () {
        expect(MulticallFactory.isSupported(42161), isTrue);
      });

      test('should return true for Optimism', () {
        expect(MulticallFactory.isSupported(10), isTrue);
      });

      test('should return true for Base', () {
        expect(MulticallFactory.isSupported(8453), isTrue);
      });

      test('should return true for Avalanche', () {
        expect(MulticallFactory.isSupported(43114), isTrue);
      });

      test('should return true for unknown chains (fallback)', () {
        expect(MulticallFactory.isSupported(999999), isTrue);
      });
    });

    group('getSupportedVersions', () {
      test('should return all versions for Ethereum mainnet', () {
        final versions = MulticallFactory.getSupportedVersions(1);
        expect(versions, containsAll([
          MulticallVersion.v1,
          MulticallVersion.v2,
          MulticallVersion.v3,
        ]),);
      });

      test('should return all versions for Polygon', () {
        final versions = MulticallFactory.getSupportedVersions(137);
        expect(versions, containsAll([
          MulticallVersion.v1,
          MulticallVersion.v2,
          MulticallVersion.v3,
        ]),);
      });

      test('should return only v3 for most chains', () {
        final versions = MulticallFactory.getSupportedVersions(56); // BSC
        expect(versions, equals([MulticallVersion.v3]));
      });
    });
  });

  group('MulticallExtension', () {
    late MockPublicClient publicClient;
    late MockWalletClient walletClient;

    setUp(() {
      publicClient = MockPublicClient();
      walletClient = MockWalletClient();
    });

    test('PublicClient.multicall() should create multicall instance', () {
      final multicall = publicClient.multicall();
      expect(multicall, isA<Multicall>());
    });

    test('WalletClient.multicall() should create multicall instance', () {
      final multicall = walletClient.multicall();
      expect(multicall, isA<Multicall>());
    });

    test('should pass custom parameters to factory', () {
      const customAddress = '0x1234567890123456789012345678901234567890';
      
      final multicall = publicClient.multicall(
        contractAddress: customAddress,
        version: MulticallVersion.v2,
      );
      
      expect(multicall, isA<Multicall>());
    });
  });
}
