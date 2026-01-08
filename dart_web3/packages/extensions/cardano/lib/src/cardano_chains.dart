/// Cardano network configurations.

/// Cardano network type.
enum CardanoNetwork {
  /// Mainnet.
  mainnet(764824073),

  /// Preprod testnet.
  preprod(1),

  /// Preview testnet.
  preview(2),

  /// Legacy testnet.
  testnet(1097911063);

  const CardanoNetwork(this.networkMagic);

  /// Network magic number.
  final int networkMagic;
}

/// Cardano chain configuration.
class CardanoChainConfig {
  /// Creates a new Cardano chain configuration.
  const CardanoChainConfig({
    required this.name,
    required this.network,
    required this.blockfrostUrl,
    required this.koiosUrl,
    this.explorerUrl,
    this.isTestnet = false,
  });

  /// Network name.
  final String name;

  /// Network type.
  final CardanoNetwork network;

  /// Blockfrost API URL.
  final String blockfrostUrl;

  /// Koios API URL.
  final String koiosUrl;

  /// Block explorer URL.
  final String? explorerUrl;

  /// Whether this is a testnet.
  final bool isTestnet;
}

/// Predefined Cardano network configurations.
class CardanoChains {
  CardanoChains._();

  /// Cardano Mainnet
  static const mainnet = CardanoChainConfig(
    name: 'Cardano Mainnet',
    network: CardanoNetwork.mainnet,
    blockfrostUrl: 'https://cardano-mainnet.blockfrost.io/api/v0',
    koiosUrl: 'https://api.koios.rest/api/v1',
    explorerUrl: 'https://cardanoscan.io',
    isTestnet: false,
  );

  /// Cardano Preprod Testnet
  static const preprod = CardanoChainConfig(
    name: 'Cardano Preprod',
    network: CardanoNetwork.preprod,
    blockfrostUrl: 'https://cardano-preprod.blockfrost.io/api/v0',
    koiosUrl: 'https://preprod.koios.rest/api/v1',
    explorerUrl: 'https://preprod.cardanoscan.io',
    isTestnet: true,
  );

  /// Cardano Preview Testnet
  static const preview = CardanoChainConfig(
    name: 'Cardano Preview',
    network: CardanoNetwork.preview,
    blockfrostUrl: 'https://cardano-preview.blockfrost.io/api/v0',
    koiosUrl: 'https://preview.koios.rest/api/v1',
    explorerUrl: 'https://preview.cardanoscan.io',
    isTestnet: true,
  );

  /// All predefined chains.
  static const List<CardanoChainConfig> all = [mainnet, preprod, preview];

  /// Gets chain by network.
  static CardanoChainConfig? getByNetwork(CardanoNetwork network) {
    for (final chain in all) {
      if (chain.network == network) return chain;
    }
    return null;
  }
}
