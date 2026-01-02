/// Configuration for a blockchain network.
class ChainConfig {

  ChainConfig({
    required this.chainId,
    required this.name,
    required this.shortName,
    required this.nativeCurrency,
    required this.symbol,
    required this.decimals,
    required this.rpcUrls,
    required this.blockExplorerUrls,
    this.iconUrl,
    this.testnet = false,
    this.multicallAddress,
    this.ensRegistryAddress,
  });
  /// The chain ID.
  final int chainId;

  /// The network name.
  final String name;

  /// Short name for the network.
  final String shortName;

  /// Native currency name.
  final String nativeCurrency;

  /// Native currency symbol.
  final String symbol;

  /// Native currency decimals.
  final int decimals;

  /// RPC endpoint URLs.
  final List<String> rpcUrls;

  /// Block explorer URLs.
  final List<String> blockExplorerUrls;

  /// Icon URL.
  final String? iconUrl;

  /// Whether this is a testnet.
  final bool testnet;

  /// Multicall3 contract address.
  final String? multicallAddress;

  /// ENS registry address.
  final String? ensRegistryAddress;

  /// Creates a copy with updated fields.
  ChainConfig copyWith({
    int? chainId,
    String? name,
    String? shortName,
    String? nativeCurrency,
    String? symbol,
    int? decimals,
    List<String>? rpcUrls,
    List<String>? blockExplorerUrls,
    String? iconUrl,
    bool? testnet,
    String? multicallAddress,
    String? ensRegistryAddress,
  }) {
    return ChainConfig(
      chainId: chainId ?? this.chainId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      nativeCurrency: nativeCurrency ?? this.nativeCurrency,
      symbol: symbol ?? this.symbol,
      decimals: decimals ?? this.decimals,
      rpcUrls: rpcUrls ?? this.rpcUrls,
      blockExplorerUrls: blockExplorerUrls ?? this.blockExplorerUrls,
      iconUrl: iconUrl ?? this.iconUrl,
      testnet: testnet ?? this.testnet,
      multicallAddress: multicallAddress ?? this.multicallAddress,
      ensRegistryAddress: ensRegistryAddress ?? this.ensRegistryAddress,
    );
  }
}
