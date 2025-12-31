import 'package:dart_web3_client/dart_web3_client.dart';
import 'ens_resolver.dart';
import 'ens_records.dart';
import 'multichain_resolver.dart';

/// Main ENS client that provides all ENS functionality
class ENSClient {
  final ENSResolver _resolver;
  final ENSRecords _records;
  final MultichainResolver _multichainResolver;

  ENSClient({
    required PublicClient client,
    String? registryAddress,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _resolver = ENSResolver(
          client: client,
          registryAddress: registryAddress,
          cacheTtl: cacheTtl,
        ),
        _records = ENSRecords(
          client: client,
          registryAddress: registryAddress,
          cacheTtl: cacheTtl,
        ),
        _multichainResolver = MultichainResolver(
          client: client,
          registryAddress: registryAddress,
          cacheTtl: cacheTtl,
        );

  // Basic resolution methods
  
  /// Resolve ENS name to Ethereum address
  Future<String?> resolveName(String name) async {
    return await _resolver.resolveName(name);
  }

  /// Reverse resolve Ethereum address to ENS name
  Future<String?> resolveAddress(String address) async {
    return await _resolver.resolveAddress(address);
  }

  // Records methods
  
  /// Get text record for ENS name
  Future<String?> getTextRecord(String name, String key) async {
    return await _records.getTextRecord(name, key);
  }

  /// Get avatar URL for ENS name
  Future<String?> getAvatar(String name) async {
    return await _records.getAvatar(name);
  }

  /// Get multiple text records at once
  Future<Map<String, String?>> getTextRecords(String name, List<String> keys) async {
    return await _records.getTextRecords(name, keys);
  }

  /// Get complete ENS profile
  Future<ENSProfile> getProfile(String name) async {
    return await _records.getProfile(name);
  }

  // Multi-chain methods
  
  /// Resolve address for specific coin type (ENSIP-9)
  Future<String?> resolveAddressForCoin(String name, int coinType) async {
    return await _multichainResolver.resolveAddress(name, coinType);
  }

  /// Get Ethereum address (coin type 60)
  Future<String?> getEthereumAddress(String name) async {
    return await _multichainResolver.getEthereumAddress(name);
  }

  /// Get Bitcoin address (coin type 0)
  Future<String?> getBitcoinAddress(String name) async {
    return await _multichainResolver.getBitcoinAddress(name);
  }

  /// Get Litecoin address (coin type 2)
  Future<String?> getLitecoinAddress(String name) async {
    return await _multichainResolver.getLitecoinAddress(name);
  }

  /// Get Dogecoin address (coin type 3)
  Future<String?> getDogecoinAddress(String name) async {
    return await _multichainResolver.getDogecoinAddress(name);
  }

  /// Get Monero address (coin type 128)
  Future<String?> getMoneroAddress(String name) async {
    return await _multichainResolver.getMoneroAddress(name);
  }

  /// Get all supported addresses for a name
  Future<Map<String, String?>> getAllAddresses(String name) async {
    return await _multichainResolver.getAllAddresses(name);
  }

  // Utility methods
  
  /// Validate ENS name format
  static bool isValidENSName(String name) {
    return ENSResolver.isValidENSName(name);
  }

  /// Clear all caches
  void clearCache() {
    _resolver.clearCache();
    _records.clearCache();
    _multichainResolver.clearCache();
  }

  /// Get comprehensive ENS information
  Future<ENSInfo> getENSInfo(String name) async {
    final profile = await getProfile(name);
    final addresses = await getAllAddresses(name);
    
    return ENSInfo(
      name: name,
      profile: profile,
      addresses: addresses,
    );
  }
}

/// Comprehensive ENS information
class ENSInfo {
  final String name;
  final ENSProfile profile;
  final Map<String, String?> addresses;

  ENSInfo({
    required this.name,
    required this.profile,
    required this.addresses,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'profile': profile.toJson(),
      'addresses': addresses,
    };
  }

  @override
  String toString() {
    return 'ENSInfo(name: $name, profile: $profile, addresses: $addresses)';
  }
}