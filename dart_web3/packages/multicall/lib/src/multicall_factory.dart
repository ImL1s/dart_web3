import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_contract/dart_web3_contract.dart';
import 'multicall.dart';

/// Factory for creating Multicall instances with chain-specific configurations.
class MulticallFactory {
  /// Creates a Multicall instance for the given chain.
  static Multicall create({
    required PublicClient publicClient,
    WalletClient? walletClient,
    String? contractAddress,
    MulticallVersion? version,
  }) {
    final chainId = publicClient.chain.chainId;
    
    // Use provided address or get from chain config
    final address = contractAddress ?? _getMulticallAddress(chainId);
    if (address == null) {
      throw UnsupportedError('Multicall not supported on chain $chainId');
    }
    
    // Determine version based on chain or use provided version
    final multicallVersion = version ?? _getMulticallVersion(chainId);
    
    return Multicall(
      publicClient: publicClient,
      walletClient: walletClient,
      contractAddress: address,
      version: multicallVersion,
    );
  }
  
  /// Gets the Multicall contract address for a given chain ID.
  static String? _getMulticallAddress(int chainId) {
    // Multicall3 is deployed at the same address on most chains
    const multicall3Address = '0xcA11bde05977b3631167028862bE2a173976CA11';
    
    switch (chainId) {
      // Ethereum Mainnet
      case 1:
        return multicall3Address;
      
      // Ethereum Testnets
      case 5: // Goerli
      case 11155111: // Sepolia
        return multicall3Address;
      
      // Polygon
      case 137: // Polygon Mainnet
      case 80001: // Polygon Mumbai
        return multicall3Address;
      
      // BSC
      case 56: // BSC Mainnet
      case 97: // BSC Testnet
        return multicall3Address;
      
      // Arbitrum
      case 42161: // Arbitrum One
      case 421613: // Arbitrum Goerli
        return multicall3Address;
      
      // Optimism
      case 10: // Optimism Mainnet
      case 420: // Optimism Goerli
        return multicall3Address;
      
      // Base
      case 8453: // Base Mainnet
      case 84531: // Base Goerli
        return multicall3Address;
      
      // Avalanche
      case 43114: // Avalanche C-Chain
      case 43113: // Avalanche Fuji
        return multicall3Address;
      
      default:
        // Try Multicall3 address for unknown chains
        return multicall3Address;
    }
  }
  
  /// Gets the recommended Multicall version for a given chain ID.
  static MulticallVersion _getMulticallVersion(int chainId) {
    // Most modern chains support Multicall3
    switch (chainId) {
      // Older chains might need v2
      case 1: // Ethereum Mainnet - has all versions
      case 137: // Polygon - has all versions
        return MulticallVersion.v3;
      
      default:
        // Default to v3 for most chains
        return MulticallVersion.v3;
    }
  }
  
  /// Checks if Multicall is supported on the given chain.
  static bool isSupported(int chainId) {
    return _getMulticallAddress(chainId) != null;
  }
  
  /// Gets available Multicall versions for a chain.
  static List<MulticallVersion> getSupportedVersions(int chainId) {
    switch (chainId) {
      case 1: // Ethereum Mainnet
      case 137: // Polygon Mainnet
        return [MulticallVersion.v1, MulticallVersion.v2, MulticallVersion.v3];
      
      default:
        // Most chains only have v3
        return [MulticallVersion.v3];
    }
  }
}

/// Extension on PublicClient to add multicall functionality.
extension MulticallExtension on PublicClient {
  /// Creates a Multicall instance for this client.
  Multicall multicall({
    String? contractAddress,
    MulticallVersion? version,
  }) {
    return MulticallFactory.create(
      publicClient: this,
      contractAddress: contractAddress,
      version: version,
    );
  }
}

/// Extension on WalletClient to add multicall functionality.
extension WalletMulticallExtension on WalletClient {
  /// Creates a Multicall instance for this wallet client.
  Multicall multicall({
    String? contractAddress,
    MulticallVersion? version,
  }) {
    return MulticallFactory.create(
      publicClient: this,
      walletClient: this,
      contractAddress: contractAddress,
      version: version,
    );
  }
}