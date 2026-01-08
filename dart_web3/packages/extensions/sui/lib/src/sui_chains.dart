/// Sui network configurations.

/// Sui chain configuration.
class SuiChainConfig {
  /// Creates a new Sui chain configuration.
  const SuiChainConfig({
    required this.name,
    required this.rpcUrl,
    required this.wsUrl,
    required this.faucetUrl,
    this.explorerUrl,
    this.isTestnet = false,
  });

  /// Network name.
  final String name;

  /// JSON-RPC endpoint URL.
  final String rpcUrl;

  /// WebSocket endpoint URL.
  final String wsUrl;

  /// Faucet URL (for testnets).
  final String? faucetUrl;

  /// Block explorer URL.
  final String? explorerUrl;

  /// Whether this is a testnet.
  final bool isTestnet;
}

/// Predefined Sui network configurations.
class SuiChains {
  SuiChains._();

  /// Sui Mainnet
  static const mainnet = SuiChainConfig(
    name: 'Sui Mainnet',
    rpcUrl: 'https://fullnode.mainnet.sui.io:443',
    wsUrl: 'wss://fullnode.mainnet.sui.io:443',
    faucetUrl: null,
    explorerUrl: 'https://suiscan.xyz/mainnet',
    isTestnet: false,
  );

  /// Sui Testnet
  static const testnet = SuiChainConfig(
    name: 'Sui Testnet',
    rpcUrl: 'https://fullnode.testnet.sui.io:443',
    wsUrl: 'wss://fullnode.testnet.sui.io:443',
    faucetUrl: 'https://faucet.testnet.sui.io',
    explorerUrl: 'https://suiscan.xyz/testnet',
    isTestnet: true,
  );

  /// Sui Devnet
  static const devnet = SuiChainConfig(
    name: 'Sui Devnet',
    rpcUrl: 'https://fullnode.devnet.sui.io:443',
    wsUrl: 'wss://fullnode.devnet.sui.io:443',
    faucetUrl: 'https://faucet.devnet.sui.io',
    explorerUrl: 'https://suiscan.xyz/devnet',
    isTestnet: true,
  );

  /// Sui Local
  static const local = SuiChainConfig(
    name: 'Sui Local',
    rpcUrl: 'http://127.0.0.1:9000',
    wsUrl: 'ws://127.0.0.1:9000',
    faucetUrl: 'http://127.0.0.1:9123/gas',
    explorerUrl: null,
    isTestnet: true,
  );

  /// All predefined chains.
  static const List<SuiChainConfig> all = [mainnet, testnet, devnet, local];
}
