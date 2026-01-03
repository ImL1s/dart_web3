import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:test/test.dart';

void main() {
  group('ChainConfig', () {
    test('should create a valid chain config', () {
      final config = ChainConfig(
        chainId: 1,
        name: 'Test Chain',
        shortName: 'test',
        nativeCurrency: 'Test Token',
        symbol: 'TEST',
        decimals: 18,
        rpcUrls: ['https://test.rpc.com'],
        blockExplorerUrls: ['https://test.explorer.com'],
      );

      expect(config.chainId, equals(1));
      expect(config.name, equals('Test Chain'));
      expect(config.shortName, equals('test'));
      expect(config.nativeCurrency, equals('Test Token'));
      expect(config.symbol, equals('TEST'));
      expect(config.decimals, equals(18));
      expect(config.rpcUrls, equals(['https://test.rpc.com']));
      expect(config.blockExplorerUrls, equals(['https://test.explorer.com']));
      expect(config.testnet, isFalse);
      expect(config.iconUrl, isNull);
      expect(config.multicallAddress, isNull);
      expect(config.ensRegistryAddress, isNull);
    });

    test('should create a testnet config', () {
      final config = ChainConfig(
        chainId: 5,
        name: 'Test Testnet',
        shortName: 'testnet',
        nativeCurrency: 'Test Token',
        symbol: 'TEST',
        decimals: 18,
        rpcUrls: ['https://testnet.rpc.com'],
        blockExplorerUrls: ['https://testnet.explorer.com'],
        testnet: true,
        multicallAddress: '0x1234567890123456789012345678901234567890',
        ensRegistryAddress: '0x0987654321098765432109876543210987654321',
      );

      expect(config.testnet, isTrue);
      expect(config.multicallAddress, equals('0x1234567890123456789012345678901234567890'));
      expect(config.ensRegistryAddress, equals('0x0987654321098765432109876543210987654321'));
    });

    test('should create a copy with updated fields', () {
      final original = ChainConfig(
        chainId: 1,
        name: 'Original Chain',
        shortName: 'orig',
        nativeCurrency: 'Original Token',
        symbol: 'ORIG',
        decimals: 18,
        rpcUrls: ['https://original.rpc.com'],
        blockExplorerUrls: ['https://original.explorer.com'],
      );

      final copy = original.copyWith(
        name: 'Updated Chain',
        symbol: 'UPD',
        testnet: true,
      );

      expect(copy.chainId, equals(1)); // unchanged
      expect(copy.name, equals('Updated Chain')); // changed
      expect(copy.shortName, equals('orig')); // unchanged
      expect(copy.symbol, equals('UPD')); // changed
      expect(copy.testnet, isTrue); // changed
      expect(copy.rpcUrls, equals(['https://original.rpc.com'])); // unchanged
    });
  });
}
