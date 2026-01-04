import 'chain_config.dart';

/// Pre-defined chain configurations.
class Chains {
  Chains._();

  static final _customChains = <int, ChainConfig>{};

  /// Ethereum Mainnet.
  static final ethereum = ChainConfig(
    chainId: 1,
    name: 'Ethereum Mainnet',
    shortName: 'eth',
    nativeCurrency: 'Ether',
    symbol: 'ETH',
    decimals: 18,
    rpcUrls: ['https://eth.llamarpc.com', 'https://rpc.ankr.com/eth'],
    blockExplorerUrls: ['https://etherscan.io'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
    ensRegistryAddress: '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e',
  );

  /// Sepolia Testnet.
  static final sepolia = ChainConfig(
    chainId: 11155111,
    name: 'Sepolia',
    shortName: 'sep',
    nativeCurrency: 'Sepolia Ether',
    symbol: 'ETH',
    decimals: 18,
    rpcUrls: ['https://rpc.sepolia.org', 'https://rpc.ankr.com/eth_sepolia'],
    blockExplorerUrls: ['https://sepolia.etherscan.io'],
    testnet: true,
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Goerli Testnet (deprecated but still supported).
  static final goerli = ChainConfig(
    chainId: 5,
    name: 'Goerli',
    shortName: 'gor',
    nativeCurrency: 'Goerli Ether',
    symbol: 'ETH',
    decimals: 18,
    rpcUrls: [
      'https://rpc.ankr.com/eth_goerli',
      'https://goerli.infura.io/v3/'
    ],
    blockExplorerUrls: ['https://goerli.etherscan.io'],
    testnet: true,
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Polygon Mainnet.
  static final polygon = ChainConfig(
    chainId: 137,
    name: 'Polygon Mainnet',
    shortName: 'matic',
    nativeCurrency: 'MATIC',
    symbol: 'MATIC',
    decimals: 18,
    rpcUrls: ['https://polygon.llamarpc.com', 'https://rpc.ankr.com/polygon'],
    blockExplorerUrls: ['https://polygonscan.com'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// BNB Smart Chain.
  static final bsc = ChainConfig(
    chainId: 56,
    name: 'BNB Smart Chain',
    shortName: 'bnb',
    nativeCurrency: 'BNB',
    symbol: 'BNB',
    decimals: 18,
    rpcUrls: ['https://bsc.llamarpc.com', 'https://rpc.ankr.com/bsc'],
    blockExplorerUrls: ['https://bscscan.com'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Arbitrum One.
  static final arbitrum = ChainConfig(
    chainId: 42161,
    name: 'Arbitrum One',
    shortName: 'arb1',
    nativeCurrency: 'Ether',
    symbol: 'ETH',
    decimals: 18,
    rpcUrls: ['https://arbitrum.llamarpc.com', 'https://rpc.ankr.com/arbitrum'],
    blockExplorerUrls: ['https://arbiscan.io'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Optimism.
  static final optimism = ChainConfig(
    chainId: 10,
    name: 'Optimism',
    shortName: 'oeth',
    nativeCurrency: 'Ether',
    symbol: 'ETH',
    decimals: 18,
    rpcUrls: ['https://optimism.llamarpc.com', 'https://rpc.ankr.com/optimism'],
    blockExplorerUrls: ['https://optimistic.etherscan.io'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Base.
  static final base = ChainConfig(
    chainId: 8453,
    name: 'Base',
    shortName: 'base',
    nativeCurrency: 'Ether',
    symbol: 'ETH',
    decimals: 18,
    rpcUrls: ['https://base.llamarpc.com', 'https://rpc.ankr.com/base'],
    blockExplorerUrls: ['https://basescan.org'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Avalanche C-Chain.
  static final avalanche = ChainConfig(
    chainId: 43114,
    name: 'Avalanche C-Chain',
    shortName: 'avax',
    nativeCurrency: 'Avalanche',
    symbol: 'AVAX',
    decimals: 18,
    rpcUrls: [
      'https://avalanche.llamarpc.com',
      'https://rpc.ankr.com/avalanche'
    ],
    blockExplorerUrls: ['https://snowtrace.io'],
    multicallAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  /// Gets a chain by ID.
  static ChainConfig? getById(int chainId) {
    if (_customChains.containsKey(chainId)) {
      return _customChains[chainId];
    }

    switch (chainId) {
      case 1:
        return ethereum;
      case 5:
        return goerli;
      case 11155111:
        return sepolia;
      case 137:
        return polygon;
      case 56:
        return bsc;
      case 42161:
        return arbitrum;
      case 10:
        return optimism;
      case 8453:
        return base;
      case 43114:
        return avalanche;
      default:
        return null;
    }
  }

  /// Gets all pre-defined chains.
  static List<ChainConfig> getAllChains() {
    return [
      ethereum,
      goerli,
      sepolia,
      polygon,
      bsc,
      arbitrum,
      optimism,
      base,
      avalanche,
      ..._customChains.values,
    ];
  }

  /// Registers a custom chain.
  static void registerChain(ChainConfig chain) {
    _customChains[chain.chainId] = chain;
  }

  /// Unregisters a custom chain.
  static void unregisterChain(int chainId) {
    _customChains.remove(chainId);
  }
}
