import 'dart:typed_data';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// ENS resolver for name and address resolution
class ENSResolver {
  ENSResolver({
    required PublicClient client,
    String? registryAddress,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _client = client,
        _registryAddress =
            registryAddress ?? '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e',
        _cacheTtl = cacheTtl;
  final PublicClient _client;
  final String _registryAddress;
  final Map<String, dynamic> _cache = {};
  final Duration _cacheTtl;

  /// Resolve ENS name to Ethereum address
  Future<String?> resolveName(String name) async {
    if (!isValidENSName(name)) {
      throw ArgumentError('Invalid ENS name: $name');
    }

    // Check cache first
    final cacheKey = 'name_$name';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached as String?;
    }

    try {
      // Get resolver address from registry
      final resolverAddress = await _getResolver(name);
      if (resolverAddress == null ||
          resolverAddress == '0x0000000000000000000000000000000000000000') {
        return null;
      }

      // Query resolver for address
      final address = await _resolveAddress(resolverAddress, name);

      // Cache result
      _setCache(cacheKey, address);

      return address;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Reverse resolve Ethereum address to ENS name
  Future<String?> resolveAddress(String address) async {
    if (!EthereumAddress.isValid(address)) {
      throw ArgumentError('Invalid Ethereum address: $address');
    }

    // Check cache first
    final cacheKey = 'address_$address';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached as String?;
    }

    try {
      // Normalize address
      final normalizedAddress = address.toLowerCase();
      if (!EthereumAddress.isValid(normalizedAddress)) {
        throw ArgumentError('Invalid Ethereum address: $address');
      }

      // Create reverse ENS name
      final reverseName = '${normalizedAddress.substring(2)}.addr.reverse';

      // Get resolver for reverse name
      final resolverAddress = await _getResolver(reverseName);
      if (resolverAddress == null ||
          resolverAddress == '0x0000000000000000000000000000000000000000') {
        return null;
      }

      // Query resolver for name
      final name = await _resolveName(resolverAddress, reverseName);

      // Verify the name resolves back to the original address
      if (name != null) {
        final verifyAddress = await resolveName(name);
        if (verifyAddress?.toLowerCase() != address.toLowerCase()) {
          return null;
        }
      }

      // Cache result
      _setCache(cacheKey, name);

      return name;
    } on Exception catch (_) {
      return null;
    }
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

  /// Resolve address from resolver contract
  Future<String?> _resolveAddress(String resolverAddress, String name) async {
    final nameHash = _namehash(name);

    final resolverContract = Contract(
      address: resolverAddress,
      abi: _ensResolverAbi,
      publicClient: _client,
    );

    try {
      final result = await resolverContract.read('addr', [nameHash]);
      final address = result[0] as String;

      if (address == '0x0000000000000000000000000000000000000000') {
        return null;
      }

      return address;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Resolve name from resolver contract
  Future<String?> _resolveName(
      String resolverAddress, String reverseName) async {
    final nameHash = _namehash(reverseName);

    final resolverContract = Contract(
      address: resolverAddress,
      abi: _ensResolverAbi,
      publicClient: _client,
    );

    try {
      final result = await resolverContract.read('name', [nameHash]);
      return result[0] as String?;
    } on Exception catch (_) {
      return null;
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

  /// Validate ENS name format
  static bool isValidENSName(String name) {
    if (name.isEmpty) return false;

    // Must end with .eth or other valid TLD
    if (!name.contains('.')) return false;

    // Check for invalid characters (must be lowercase)
    final validPattern = RegExp(r'^[a-z0-9\-\.]+$');
    if (!validPattern.hasMatch(name)) return false;

    // Check each label
    final labels = name.split('.');
    for (final label in labels) {
      if (label.isEmpty) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      if (label.length > 63) return false;
    }

    return true;
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

  /// ENS Resolver ABI (minimal)
  static const String _ensResolverAbi = '''
[
    {
      "type": "function",
      "name": "addr",
      "inputs": [{"name": "node", "type": "bytes32"}],
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "name",
      "inputs": [{"name": "node", "type": "bytes32"}],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "text",
      "inputs": [
        {"name": "node", "type": "bytes32"},
        {"name": "key", "type": "string"}
      ],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    },
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
