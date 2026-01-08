/// NEAR network configurations.

/// NEAR chain configuration.
class NearChainConfig {
  /// Creates a new NEAR chain configuration.
  const NearChainConfig({
    required this.networkId,
    required this.name,
    required this.rpcUrl,
    required this.archivalRpcUrl,
    this.helperUrl,
    this.explorerUrl,
    this.walletUrl,
    this.isTestnet = false,
  });

  /// Network ID.
  final String networkId;

  /// Human-readable name.
  final String name;

  /// RPC endpoint URL.
  final String rpcUrl;

  /// Archival RPC endpoint URL.
  final String archivalRpcUrl;

  /// Helper/indexer URL.
  final String? helperUrl;

  /// Block explorer URL.
  final String? explorerUrl;

  /// Wallet URL.
  final String? walletUrl;

  /// Whether this is a testnet.
  final bool isTestnet;
}

/// Predefined NEAR network configurations.
class NearChains {
  NearChains._();

  /// NEAR Mainnet
  static const mainnet = NearChainConfig(
    networkId: 'mainnet',
    name: 'NEAR Mainnet',
    rpcUrl: 'https://rpc.mainnet.near.org',
    archivalRpcUrl: 'https://archival-rpc.mainnet.near.org',
    helperUrl: 'https://helper.mainnet.near.org',
    explorerUrl: 'https://nearblocks.io',
    walletUrl: 'https://wallet.near.org',
    isTestnet: false,
  );

  /// NEAR Testnet
  static const testnet = NearChainConfig(
    networkId: 'testnet',
    name: 'NEAR Testnet',
    rpcUrl: 'https://rpc.testnet.near.org',
    archivalRpcUrl: 'https://archival-rpc.testnet.near.org',
    helperUrl: 'https://helper.testnet.near.org',
    explorerUrl: 'https://testnet.nearblocks.io',
    walletUrl: 'https://wallet.testnet.near.org',
    isTestnet: true,
  );

  /// NEAR Betanet (deprecated but sometimes used)
  static const betanet = NearChainConfig(
    networkId: 'betanet',
    name: 'NEAR Betanet',
    rpcUrl: 'https://rpc.betanet.near.org',
    archivalRpcUrl: 'https://archival-rpc.betanet.near.org',
    explorerUrl: null,
    isTestnet: true,
  );

  /// NEAR Local
  static const local = NearChainConfig(
    networkId: 'local',
    name: 'NEAR Local',
    rpcUrl: 'http://127.0.0.1:3030',
    archivalRpcUrl: 'http://127.0.0.1:3030',
    explorerUrl: null,
    isTestnet: true,
  );

  /// All predefined chains.
  static const List<NearChainConfig> all = [mainnet, testnet, betanet, local];

  /// Gets chain by network ID.
  static NearChainConfig? getByNetworkId(String networkId) {
    for (final chain in all) {
      if (chain.networkId == networkId) return chain;
    }
    return null;
  }
}
