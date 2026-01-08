/// Cosmos chain configurations.

/// Cosmos chain configuration.
class CosmosChainConfig {
  /// Creates a new Cosmos chain configuration.
  const CosmosChainConfig({
    required this.chainId,
    required this.chainName,
    required this.rpcUrl,
    required this.restUrl,
    required this.bech32Prefix,
    required this.denom,
    required this.minimalDenom,
    required this.decimals,
    this.gasPrice,
    this.explorerUrl,
    this.ibcEnabled = true,
    this.isTestnet = false,
  });

  /// Chain ID (e.g., "cosmoshub-4").
  final String chainId;

  /// Human-readable chain name.
  final String chainName;

  /// Tendermint RPC endpoint URL.
  final String rpcUrl;

  /// LCD/REST API endpoint URL.
  final String restUrl;

  /// Bech32 address prefix (e.g., "cosmos", "osmo").
  final String bech32Prefix;

  /// Display denomination (e.g., "ATOM", "OSMO").
  final String denom;

  /// Minimal denomination (e.g., "uatom", "uosmo").
  final String minimalDenom;

  /// Decimal places.
  final int decimals;

  /// Default gas price.
  final String? gasPrice;

  /// Block explorer URL.
  final String? explorerUrl;

  /// Whether IBC is enabled.
  final bool ibcEnabled;

  /// Whether this is a testnet.
  final bool isTestnet;
}

/// Predefined Cosmos chain configurations.
class CosmosChains {
  CosmosChains._();

  // === Cosmos Hub ===

  /// Cosmos Hub Mainnet
  static const cosmosHub = CosmosChainConfig(
    chainId: 'cosmoshub-4',
    chainName: 'Cosmos Hub',
    rpcUrl: 'https://rpc.cosmos.network',
    restUrl: 'https://lcd.cosmos.network',
    bech32Prefix: 'cosmos',
    denom: 'ATOM',
    minimalDenom: 'uatom',
    decimals: 6,
    gasPrice: '0.025uatom',
    explorerUrl: 'https://www.mintscan.io/cosmos',
    isTestnet: false,
  );

  /// Cosmos Hub Testnet (Theta)
  static const cosmosHubTestnet = CosmosChainConfig(
    chainId: 'theta-testnet-001',
    chainName: 'Cosmos Hub Testnet',
    rpcUrl: 'https://rpc.sentry-01.theta-testnet.polypore.xyz',
    restUrl: 'https://rest.sentry-01.theta-testnet.polypore.xyz',
    bech32Prefix: 'cosmos',
    denom: 'ATOM',
    minimalDenom: 'uatom',
    decimals: 6,
    gasPrice: '0.025uatom',
    explorerUrl: 'https://explorer.theta-testnet.polypore.xyz',
    isTestnet: true,
  );

  // === Osmosis ===

  /// Osmosis Mainnet
  static const osmosis = CosmosChainConfig(
    chainId: 'osmosis-1',
    chainName: 'Osmosis',
    rpcUrl: 'https://rpc.osmosis.zone',
    restUrl: 'https://lcd.osmosis.zone',
    bech32Prefix: 'osmo',
    denom: 'OSMO',
    minimalDenom: 'uosmo',
    decimals: 6,
    gasPrice: '0.025uosmo',
    explorerUrl: 'https://www.mintscan.io/osmosis',
    isTestnet: false,
  );

  /// Osmosis Testnet
  static const osmosisTestnet = CosmosChainConfig(
    chainId: 'osmo-test-5',
    chainName: 'Osmosis Testnet',
    rpcUrl: 'https://rpc.testnet.osmosis.zone',
    restUrl: 'https://lcd.testnet.osmosis.zone',
    bech32Prefix: 'osmo',
    denom: 'OSMO',
    minimalDenom: 'uosmo',
    decimals: 6,
    gasPrice: '0.025uosmo',
    explorerUrl: 'https://testnet.mintscan.io/osmosis-testnet',
    isTestnet: true,
  );

  // === Juno ===

  /// Juno Mainnet
  static const juno = CosmosChainConfig(
    chainId: 'juno-1',
    chainName: 'Juno',
    rpcUrl: 'https://rpc-juno.itastakers.com',
    restUrl: 'https://lcd-juno.itastakers.com',
    bech32Prefix: 'juno',
    denom: 'JUNO',
    minimalDenom: 'ujuno',
    decimals: 6,
    gasPrice: '0.075ujuno',
    explorerUrl: 'https://www.mintscan.io/juno',
    isTestnet: false,
  );

  // === Secret Network ===

  /// Secret Network Mainnet
  static const secret = CosmosChainConfig(
    chainId: 'secret-4',
    chainName: 'Secret Network',
    rpcUrl: 'https://rpc.secret.express',
    restUrl: 'https://lcd.secret.express',
    bech32Prefix: 'secret',
    denom: 'SCRT',
    minimalDenom: 'uscrt',
    decimals: 6,
    gasPrice: '0.1uscrt',
    explorerUrl: 'https://www.mintscan.io/secret',
    isTestnet: false,
  );

  // === Akash ===

  /// Akash Network Mainnet
  static const akash = CosmosChainConfig(
    chainId: 'akashnet-2',
    chainName: 'Akash Network',
    rpcUrl: 'https://rpc.akash.forbole.com',
    restUrl: 'https://api.akash.forbole.com',
    bech32Prefix: 'akash',
    denom: 'AKT',
    minimalDenom: 'uakt',
    decimals: 6,
    gasPrice: '0.025uakt',
    explorerUrl: 'https://www.mintscan.io/akash',
    isTestnet: false,
  );

  // === Stargaze ===

  /// Stargaze Mainnet
  static const stargaze = CosmosChainConfig(
    chainId: 'stargaze-1',
    chainName: 'Stargaze',
    rpcUrl: 'https://rpc.stargaze-apis.com',
    restUrl: 'https://rest.stargaze-apis.com',
    bech32Prefix: 'stars',
    denom: 'STARS',
    minimalDenom: 'ustars',
    decimals: 6,
    gasPrice: '1.0ustars',
    explorerUrl: 'https://www.mintscan.io/stargaze',
    isTestnet: false,
  );

  // === Injective ===

  /// Injective Mainnet
  static const injective = CosmosChainConfig(
    chainId: 'injective-1',
    chainName: 'Injective',
    rpcUrl: 'https://sentry.tm.injective.network:443',
    restUrl: 'https://sentry.lcd.injective.network',
    bech32Prefix: 'inj',
    denom: 'INJ',
    minimalDenom: 'inj',
    decimals: 18,
    gasPrice: '500000000inj',
    explorerUrl: 'https://explorer.injective.network',
    isTestnet: false,
  );

  // === Sei ===

  /// Sei Mainnet
  static const sei = CosmosChainConfig(
    chainId: 'pacific-1',
    chainName: 'Sei',
    rpcUrl: 'https://rpc.sei-apis.com',
    restUrl: 'https://rest.sei-apis.com',
    bech32Prefix: 'sei',
    denom: 'SEI',
    minimalDenom: 'usei',
    decimals: 6,
    gasPrice: '0.1usei',
    explorerUrl: 'https://www.seiscan.app',
    isTestnet: false,
  );

  // === Celestia ===

  /// Celestia Mainnet
  static const celestia = CosmosChainConfig(
    chainId: 'celestia',
    chainName: 'Celestia',
    rpcUrl: 'https://rpc.celestia.nodestake.top',
    restUrl: 'https://api.celestia.nodestake.top',
    bech32Prefix: 'celestia',
    denom: 'TIA',
    minimalDenom: 'utia',
    decimals: 6,
    gasPrice: '0.002utia',
    explorerUrl: 'https://www.mintscan.io/celestia',
    isTestnet: false,
  );

  // === dYdX ===

  /// dYdX Mainnet
  static const dydx = CosmosChainConfig(
    chainId: 'dydx-mainnet-1',
    chainName: 'dYdX',
    rpcUrl: 'https://dydx-rpc.lavenderfive.com:443',
    restUrl: 'https://dydx-api.lavenderfive.com:443',
    bech32Prefix: 'dydx',
    denom: 'DYDX',
    minimalDenom: 'adydx',
    decimals: 18,
    gasPrice: '12500000000adydx',
    explorerUrl: 'https://www.mintscan.io/dydx',
    isTestnet: false,
  );

  // === Terra ===

  /// Terra (Luna 2.0) Mainnet
  static const terra = CosmosChainConfig(
    chainId: 'phoenix-1',
    chainName: 'Terra',
    rpcUrl: 'https://terra-rpc.publicnode.com',
    restUrl: 'https://terra-lcd.publicnode.com',
    bech32Prefix: 'terra',
    denom: 'LUNA',
    minimalDenom: 'uluna',
    decimals: 6,
    gasPrice: '0.015uluna',
    explorerUrl: 'https://finder.terra.money',
    isTestnet: false,
  );

  // === Kava ===

  /// Kava Mainnet
  static const kava = CosmosChainConfig(
    chainId: 'kava_2222-10',
    chainName: 'Kava',
    rpcUrl: 'https://rpc.data.kava.io',
    restUrl: 'https://api.data.kava.io',
    bech32Prefix: 'kava',
    denom: 'KAVA',
    minimalDenom: 'ukava',
    decimals: 6,
    gasPrice: '0.05ukava',
    explorerUrl: 'https://www.mintscan.io/kava',
    isTestnet: false,
  );

  /// All predefined mainnet chains.
  static const List<CosmosChainConfig> mainnets = [
    cosmosHub,
    osmosis,
    juno,
    secret,
    akash,
    stargaze,
    injective,
    sei,
    celestia,
    dydx,
    terra,
    kava,
  ];

  /// All predefined testnet chains.
  static const List<CosmosChainConfig> testnets = [
    cosmosHubTestnet,
    osmosisTestnet,
  ];

  /// All predefined chains.
  static List<CosmosChainConfig> get all => [...mainnets, ...testnets];

  /// Gets chain by chain ID.
  static CosmosChainConfig? getByChainId(String chainId) {
    for (final chain in all) {
      if (chain.chainId == chainId) return chain;
    }
    return null;
  }

  /// Gets chain by Bech32 prefix.
  static CosmosChainConfig? getByPrefix(String prefix) {
    for (final chain in all) {
      if (chain.bech32Prefix == prefix) return chain;
    }
    return null;
  }
}
