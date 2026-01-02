import 'dart:typed_data';

import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_contract/dart_web3_contract.dart';
import 'package:dart_web3_crypto/dart_web3_crypto.dart';

/// Multi-chain address resolver implementing ENSIP-9
class MultichainResolver {

  MultichainResolver({
    required PublicClient client,
    String? registryAddress,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _client = client,
        _registryAddress = registryAddress ?? '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e',
        _cacheTtl = cacheTtl;
  final PublicClient _client;
  final String _registryAddress;
  final Map<String, dynamic> _cache = {};
  final Duration _cacheTtl;

  /// Resolve address for specific coin type (ENSIP-9)
  Future<String?> resolveAddress(String name, int coinType) async {
    if (!_isValidENSName(name)) {
      throw ArgumentError('Invalid ENS name: $name');
    }

    // Check cache first
    final cacheKey = 'multichain_${name}_$coinType';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached as String?;
    }

    try {
      // Get resolver address
      final resolverAddress = await _getResolver(name);
      if (resolverAddress == null || resolverAddress == '0x0000000000000000000000000000000000000000') {
        return null;
      }

      // Query multi-chain address
      final addressBytes = await _getAddressFromResolver(resolverAddress, name, coinType);
      if (addressBytes == null || addressBytes.isEmpty) {
        return null;
      }

      // Format address based on coin type
      final formattedAddress = _formatAddress(addressBytes, coinType);
      
      // Cache result
      _setCache(cacheKey, formattedAddress);
      
      return formattedAddress;
    } catch (e) {
      return null;
    }
  }

  /// Get Ethereum address (coin type 60)
  Future<String?> getEthereumAddress(String name) async {
    return resolveAddress(name, CoinType.ethereum);
  }

  /// Get Bitcoin address (coin type 0)
  Future<String?> getBitcoinAddress(String name) async {
    return resolveAddress(name, CoinType.bitcoin);
  }

  /// Get Litecoin address (coin type 2)
  Future<String?> getLitecoinAddress(String name) async {
    return resolveAddress(name, CoinType.litecoin);
  }

  /// Get Dogecoin address (coin type 3)
  Future<String?> getDogecoinAddress(String name) async {
    return resolveAddress(name, CoinType.dogecoin);
  }

  /// Get Monero address (coin type 128)
  Future<String?> getMoneroAddress(String name) async {
    return resolveAddress(name, CoinType.monero);
  }

  /// Get all supported addresses for a name
  Future<Map<String, String?>> getAllAddresses(String name) async {
    final results = <String, String?>{};
    
    final supportedCoins = [
      CoinType.bitcoin,
      CoinType.litecoin,
      CoinType.dogecoin,
      CoinType.ethereum,
      CoinType.monero,
    ];

    for (final coinType in supportedCoins) {
      final coinName = _getCoinName(coinType);
      results[coinName] = await resolveAddress(name, coinType);
    }
    
    return results;
  }

  /// Get resolver address from ENS registry
  Future<String?> _getResolver(String name) async {
    final nameHash = _namehash(name);
    
    final registryContract = Contract(
      address: _registryAddress,
      abi: _ensRegistryAbi,
      publicClient: _client,
    );

    final result = await registryContract.read('resolver', [nameHash]);
    return result[0] as String?;
  }

  /// Get address bytes from resolver contract
  Future<Uint8List?> _getAddressFromResolver(String resolverAddress, String name, int coinType) async {
    final nameHash = _namehash(name);
    
    final resolverContract = Contract(
      address: resolverAddress,
      abi: _ensResolverAbi,
      publicClient: _client,
    );

    try {
      final result = await resolverContract.read('addr', [nameHash, BigInt.from(coinType)]);
      final addressBytes = result[0] as Uint8List?;
      
      return addressBytes;
    } catch (e) {
      return null;
    }
  }

  /// Format address bytes based on coin type
  String? _formatAddress(Uint8List addressBytes, int coinType) {
    if (addressBytes.isEmpty) return null;

    switch (coinType) {
      case CoinType.ethereum:
        // Ethereum addresses are 20 bytes
        if (addressBytes.length != 20) return null;
        return '0x${addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      
      case CoinType.bitcoin:
      case CoinType.litecoin:
      case CoinType.dogecoin:
        // Bitcoin-like addresses need base58 encoding
        return _encodeBase58Check(addressBytes, coinType);
      
      case CoinType.monero:
        // Monero addresses use base58 encoding
        return _encodeMoneroAddress(addressBytes);
      
      default:
        // For unknown coin types, return hex representation
        return '0x${addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    }
  }

  /// Encode Bitcoin-like address with base58check
  String _encodeBase58Check(Uint8List addressBytes, int coinType) {
    // This is a simplified implementation
    // In a real implementation, you would use proper base58check encoding
    return '0x${addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Encode Monero address
  String _encodeMoneroAddress(Uint8List addressBytes) {
    // This is a simplified implementation
    // In a real implementation, you would use proper Monero address encoding
    return '0x${addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Get coin name from coin type
  String _getCoinName(int coinType) {
    switch (coinType) {
      case CoinType.bitcoin:
        return 'bitcoin';
      case CoinType.litecoin:
        return 'litecoin';
      case CoinType.dogecoin:
        return 'dogecoin';
      case CoinType.ethereum:
        return 'ethereum';
      case CoinType.monero:
        return 'monero';
      default:
        return 'coin_$coinType';
    }
  }

  /// Calculate ENS namehash
  String _namehash(String name) {
    if (name.isEmpty) {
      return '0x0000000000000000000000000000000000000000000000000000000000000000';
    }

    final labels = name.split('.');
    var hash = Uint8List(32); // Start with 32 zero bytes

    for (var i = labels.length - 1; i >= 0; i--) {
      final labelHash = Keccak256.hash(Uint8List.fromList(labels[i].codeUnits));
      final combined = Uint8List.fromList([...hash, ...labelHash]);
      hash = Keccak256.hash(combined);
    }

    return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Validate ENS name format
  bool _isValidENSName(String name) {
    if (name.isEmpty) return false;
    
    // Must end with .eth or other valid TLD
    if (!name.contains('.')) return false;
    
    // Check for invalid characters
    final validPattern = RegExp(r'^[a-z0-9\-\.]+$');
    if (!validPattern.hasMatch(name.toLowerCase())) return false;
    
    // Check each label
    final labels = name.split('.');
    for (final label in labels) {
      if (label.isEmpty) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      if (label.length > 63) return false;
    }
    
    return true;
  }

  /// Check if cached value is still valid
  dynamic _getCached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    final timestamp = entry['timestamp'] as DateTime;
    if (DateTime.now().difference(timestamp) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    
    return entry['value'];
  }

  /// Set cache value with timestamp
  void _setCache(String key, dynamic value) {
    _cache[key] = {
      'value': value,
      'timestamp': DateTime.now(),
    };
  }

  /// Clear all cached entries
  void clearCache() {
    _cache.clear();
  }

  /// ENS Registry ABI (minimal)
  static const String _ensRegistryAbi = '''
[
    {
      "type": "function",
      "name": "resolver",
      "inputs": [{"name": "node", "type": "bytes32"}],
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view"
    }
  ]''';

  /// ENS Resolver ABI with multi-chain support
  static const String _ensResolverAbi = '''
[
    {
      "type": "function",
      "name": "addr",
      "inputs": [
        {"name": "node", "type": "bytes32"},
        {"name": "coinType", "type": "uint256"}
      ],
      "outputs": [{"name": "", "type": "bytes"}],
      "stateMutability": "view"
    }
  ]''';
}

/// SLIP-44 coin types for multi-chain address resolution
class CoinType {
  static const int bitcoin = 0;
  static const int testnet = 1;
  static const int litecoin = 2;
  static const int dogecoin = 3;
  static const int reddcoin = 4;
  static const int dash = 5;
  static const int peercoin = 6;
  static const int namecoin = 7;
  static const int feathercoin = 8;
  static const int counterparty = 9;
  static const int blackcoin = 10;
  static const int nushares = 11;
  static const int nubits = 12;
  static const int mazacoin = 13;
  static const int viacoin = 14;
  static const int clearinghouse = 15;
  static const int rubycoin = 16;
  static const int groestlcoin = 17;
  static const int digitalcoin = 18;
  static const int cannacoin = 19;
  static const int digibyte = 20;
  static const int ethereum = 60;
  static const int ethereumClassic = 61;
  static const int monero = 128;
  static const int zcash = 133;
  static const int ripple = 144;
  static const int bitcoin_cash = 145;
  static const int stellar = 148;
  static const int neo = 888;
  static const int cardano = 1815;
  static const int tezos = 1729;
}
