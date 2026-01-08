/// Aptos network configurations.

/// Aptos chain configuration.
class AptosChainConfig {
  /// Creates a new Aptos chain configuration.
  const AptosChainConfig({
    required this.name,
    required this.chainId,
    required this.rpcUrl,
    required this.indexerUrl,
    this.faucetUrl,
    this.explorerUrl,
    this.isTestnet = false,
  });

  /// Network name.
  final String name;

  /// Chain ID.
  final int chainId;

  /// REST API endpoint URL.
  final String rpcUrl;

  /// GraphQL indexer URL.
  final String indexerUrl;

  /// Faucet URL (for testnets).
  final String? faucetUrl;

  /// Block explorer URL.
  final String? explorerUrl;

  /// Whether this is a testnet.
  final bool isTestnet;
}

/// Predefined Aptos network configurations.
class AptosChains {
  AptosChains._();

  /// Aptos Mainnet
  static const mainnet = AptosChainConfig(
    name: 'Aptos Mainnet',
    chainId: 1,
    rpcUrl: 'https://fullnode.mainnet.aptoslabs.com/v1',
    indexerUrl: 'https://indexer.mainnet.aptoslabs.com/v1/graphql',
    faucetUrl: null,
    explorerUrl: 'https://explorer.aptoslabs.com',
    isTestnet: false,
  );

  /// Aptos Testnet
  static const testnet = AptosChainConfig(
    name: 'Aptos Testnet',
    chainId: 2,
    rpcUrl: 'https://fullnode.testnet.aptoslabs.com/v1',
    indexerUrl: 'https://indexer.testnet.aptoslabs.com/v1/graphql',
    faucetUrl: 'https://faucet.testnet.aptoslabs.com',
    explorerUrl: 'https://explorer.aptoslabs.com/?network=testnet',
    isTestnet: true,
  );

  /// Aptos Devnet
  static const devnet = AptosChainConfig(
    name: 'Aptos Devnet',
    chainId: 58,
    rpcUrl: 'https://fullnode.devnet.aptoslabs.com/v1',
    indexerUrl: 'https://indexer.devnet.aptoslabs.com/v1/graphql',
    faucetUrl: 'https://faucet.devnet.aptoslabs.com',
    explorerUrl: 'https://explorer.aptoslabs.com/?network=devnet',
    isTestnet: true,
  );

  /// Aptos Local
  static const local = AptosChainConfig(
    name: 'Aptos Local',
    chainId: 4,
    rpcUrl: 'http://127.0.0.1:8080/v1',
    indexerUrl: 'http://127.0.0.1:8090/v1/graphql',
    faucetUrl: 'http://127.0.0.1:8081',
    explorerUrl: null,
    isTestnet: true,
  );

  /// All predefined chains.
  static const List<AptosChainConfig> all = [mainnet, testnet, devnet, local];

  /// Gets chain by ID.
  static AptosChainConfig? getById(int chainId) {
    for (final chain in all) {
      if (chain.chainId == chainId) return chain;
    }
    return null;
  }
}
