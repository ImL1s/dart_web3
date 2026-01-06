import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:test/test.dart';

void main() {
  group('Chains', () {
    setUp(() {
      // Clear any custom chains before each test
      final customChainIds = Chains.getAllChains()
          .where((chain) => ![
                1,
                5,
                11155111,
                137,
                56,
                42161,
                10,
                8453,
                43114,
                -1
              ].contains(chain.chainId))
          .map((chain) => chain.chainId)
          .toList();

      for (final chainId in customChainIds) {
        Chains.unregisterChain(chainId);
      }
    });

    group('predefined chains', () {
      test('should have correct Ethereum mainnet config', () {
        final ethereum = Chains.ethereum;

        expect(ethereum.chainId, equals(1));
        expect(ethereum.name, equals('Ethereum Mainnet'));
        expect(ethereum.shortName, equals('eth'));
        expect(ethereum.symbol, equals('ETH'));
        expect(ethereum.decimals, equals(18));
        expect(ethereum.testnet, isFalse);
        expect(ethereum.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(ethereum.ensRegistryAddress,
            equals('0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e'));
        expect(ethereum.rpcUrls, isNotEmpty);
        expect(ethereum.blockExplorerUrls, contains('https://etherscan.io'));
      });

      test('should have correct Goerli testnet config', () {
        final goerli = Chains.goerli;

        expect(goerli.chainId, equals(5));
        expect(goerli.name, equals('Goerli'));
        expect(goerli.shortName, equals('gor'));
        expect(goerli.symbol, equals('ETH'));
        expect(goerli.decimals, equals(18));
        expect(goerli.testnet, isTrue);
        expect(goerli.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(goerli.rpcUrls, isNotEmpty);
        expect(
            goerli.blockExplorerUrls, contains('https://goerli.etherscan.io'));
      });

      test('should have correct Sepolia testnet config', () {
        final sepolia = Chains.sepolia;

        expect(sepolia.chainId, equals(11155111));
        expect(sepolia.name, equals('Sepolia'));
        expect(sepolia.shortName, equals('sep'));
        expect(sepolia.symbol, equals('ETH'));
        expect(sepolia.decimals, equals(18));
        expect(sepolia.testnet, isTrue);
        expect(sepolia.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(sepolia.rpcUrls, isNotEmpty);
        expect(sepolia.blockExplorerUrls,
            contains('https://sepolia.etherscan.io'));
      });

      test('should have correct Polygon mainnet config', () {
        final polygon = Chains.polygon;

        expect(polygon.chainId, equals(137));
        expect(polygon.name, equals('Polygon Mainnet'));
        expect(polygon.shortName, equals('matic'));
        expect(polygon.symbol, equals('MATIC'));
        expect(polygon.decimals, equals(18));
        expect(polygon.testnet, isFalse);
        expect(polygon.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(polygon.rpcUrls, isNotEmpty);
        expect(polygon.blockExplorerUrls, contains('https://polygonscan.com'));
      });

      test('should have correct BSC mainnet config', () {
        final bsc = Chains.bsc;

        expect(bsc.chainId, equals(56));
        expect(bsc.name, equals('BNB Smart Chain'));
        expect(bsc.shortName, equals('bnb'));
        expect(bsc.symbol, equals('BNB'));
        expect(bsc.decimals, equals(18));
        expect(bsc.testnet, isFalse);
        expect(bsc.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(bsc.rpcUrls, isNotEmpty);
        expect(bsc.blockExplorerUrls, contains('https://bscscan.com'));
      });

      test('should have correct Arbitrum mainnet config', () {
        final arbitrum = Chains.arbitrum;

        expect(arbitrum.chainId, equals(42161));
        expect(arbitrum.name, equals('Arbitrum One'));
        expect(arbitrum.shortName, equals('arb1'));
        expect(arbitrum.symbol, equals('ETH'));
        expect(arbitrum.decimals, equals(18));
        expect(arbitrum.testnet, isFalse);
        expect(arbitrum.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(arbitrum.rpcUrls, isNotEmpty);
        expect(arbitrum.blockExplorerUrls, contains('https://arbiscan.io'));
      });

      test('should have correct Optimism mainnet config', () {
        final optimism = Chains.optimism;

        expect(optimism.chainId, equals(10));
        expect(optimism.name, equals('Optimism'));
        expect(optimism.shortName, equals('oeth'));
        expect(optimism.symbol, equals('ETH'));
        expect(optimism.decimals, equals(18));
        expect(optimism.testnet, isFalse);
        expect(optimism.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(optimism.rpcUrls, isNotEmpty);
        expect(optimism.blockExplorerUrls,
            contains('https://optimistic.etherscan.io'));
      });

      test('should have correct Base mainnet config', () {
        final base = Chains.base;

        expect(base.chainId, equals(8453));
        expect(base.name, equals('Base'));
        expect(base.shortName, equals('base'));
        expect(base.symbol, equals('ETH'));
        expect(base.decimals, equals(18));
        expect(base.testnet, isFalse);
        expect(base.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(base.rpcUrls, isNotEmpty);
        expect(base.blockExplorerUrls, contains('https://basescan.org'));
      });

      test('should have correct Avalanche mainnet config', () {
        final avalanche = Chains.avalanche;

        expect(avalanche.chainId, equals(43114));
        expect(avalanche.name, equals('Avalanche C-Chain'));
        expect(avalanche.shortName, equals('avax'));
        expect(avalanche.symbol, equals('AVAX'));
        expect(avalanche.decimals, equals(18));
        expect(avalanche.testnet, isFalse);
        expect(avalanche.multicallAddress,
            equals('0xcA11bde05977b3631167028862bE2a173976CA11'));
        expect(avalanche.rpcUrls, isNotEmpty);
        expect(avalanche.blockExplorerUrls, contains('https://snowtrace.io'));
      });
    });

    group('getById', () {
      test('should return correct chain for valid chain IDs', () {
        expect(Chains.getById(1), equals(Chains.ethereum));
        expect(Chains.getById(5), equals(Chains.goerli));
        expect(Chains.getById(11155111), equals(Chains.sepolia));
        expect(Chains.getById(137), equals(Chains.polygon));
        expect(Chains.getById(56), equals(Chains.bsc));
        expect(Chains.getById(42161), equals(Chains.arbitrum));
        expect(Chains.getById(10), equals(Chains.optimism));
        expect(Chains.getById(8453), equals(Chains.base));
        expect(Chains.getById(43114), equals(Chains.avalanche));
      });

      test('should return null for unknown chain ID', () {
        expect(Chains.getById(999999), isNull);
      });

      test('should return custom chain when registered', () {
        final customChain = ChainConfig(
          chainId: 12345,
          name: 'Custom Chain',
          shortName: 'custom',
          nativeCurrency: 'Custom Token',
          symbol: 'CUSTOM',
          decimals: 18,
          rpcUrls: ['https://custom.rpc.com'],
          blockExplorerUrls: ['https://custom.explorer.com'],
        );

        Chains.registerChain(customChain);
        expect(Chains.getById(12345), equals(customChain));
      });
    });

    group('getAllChains', () {
      test('should return all predefined chains', () {
        final allChains = Chains.getAllChains();

        expect(allChains, hasLength(11)); // 9 EVM + 2 Solana (testnet/devnet)
        expect(allChains, contains(Chains.ethereum));
        expect(allChains, contains(Chains.goerli));
        expect(allChains, contains(Chains.sepolia));
        expect(allChains, contains(Chains.polygon));
        expect(allChains, contains(Chains.bsc));
        expect(allChains, contains(Chains.arbitrum));
        expect(allChains, contains(Chains.optimism));
        expect(allChains, contains(Chains.base));
        expect(allChains, contains(Chains.avalanche));
      });

      test('should include custom chains', () {
        final customChain = ChainConfig(
          chainId: 12345,
          name: 'Custom Chain',
          shortName: 'custom',
          nativeCurrency: 'Custom Token',
          symbol: 'CUSTOM',
          decimals: 18,
          rpcUrls: ['https://custom.rpc.com'],
          blockExplorerUrls: ['https://custom.explorer.com'],
        );

        Chains.registerChain(customChain);
        final allChains = Chains.getAllChains();

        expect(allChains, hasLength(12)); // 11 predefined + 1 custom
        expect(allChains, contains(customChain));
      });
    });

    group('registerChain', () {
      test('should register a custom chain', () {
        final customChain = ChainConfig(
          chainId: 12345,
          name: 'Custom Chain',
          shortName: 'custom',
          nativeCurrency: 'Custom Token',
          symbol: 'CUSTOM',
          decimals: 18,
          rpcUrls: ['https://custom.rpc.com'],
          blockExplorerUrls: ['https://custom.explorer.com'],
        );

        Chains.registerChain(customChain);

        expect(Chains.getById(12345), equals(customChain));
        expect(Chains.getAllChains(), contains(customChain));
      });

      test('should override existing custom chain with same ID', () {
        final customChain1 = ChainConfig(
          chainId: 12345,
          name: 'Custom Chain 1',
          shortName: 'custom1',
          nativeCurrency: 'Custom Token 1',
          symbol: 'CUSTOM1',
          decimals: 18,
          rpcUrls: ['https://custom1.rpc.com'],
          blockExplorerUrls: ['https://custom1.explorer.com'],
        );

        final customChain2 = ChainConfig(
          chainId: 12345,
          name: 'Custom Chain 2',
          shortName: 'custom2',
          nativeCurrency: 'Custom Token 2',
          symbol: 'CUSTOM2',
          decimals: 18,
          rpcUrls: ['https://custom2.rpc.com'],
          blockExplorerUrls: ['https://custom2.explorer.com'],
        );

        Chains.registerChain(customChain1);
        expect(Chains.getById(12345)?.name, equals('Custom Chain 1'));

        Chains.registerChain(customChain2);
        expect(Chains.getById(12345)?.name, equals('Custom Chain 2'));
      });
    });

    group('unregisterChain', () {
      test('should unregister a custom chain', () {
        final customChain = ChainConfig(
          chainId: 12345,
          name: 'Custom Chain',
          shortName: 'custom',
          nativeCurrency: 'Custom Token',
          symbol: 'CUSTOM',
          decimals: 18,
          rpcUrls: ['https://custom.rpc.com'],
          blockExplorerUrls: ['https://custom.explorer.com'],
        );

        Chains.registerChain(customChain);
        expect(Chains.getById(12345), equals(customChain));

        Chains.unregisterChain(12345);
        expect(Chains.getById(12345), isNull);
        expect(Chains.getAllChains(), isNot(contains(customChain)));
      });

      test('should do nothing when unregistering non-existent chain', () {
        final initialCount = Chains.getAllChains().length;

        Chains.unregisterChain(99999);

        expect(Chains.getAllChains().length, equals(initialCount));
      });
    });
  });
}
