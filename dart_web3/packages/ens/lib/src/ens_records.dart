import 'dart:typed_data';

import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// ENS records resolver for text records and avatar resolution
class ENSRecords {

  ENSRecords({
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

  /// Get text record for ENS name
  Future<String?> getTextRecord(String name, String key) async {
    if (!_isValidENSName(name)) {
      throw ArgumentError('Invalid ENS name: $name');
    }

    // Check cache first
    final cacheKey = 'text_${name}_$key';
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

      // Query text record
      final textValue = await _getTextFromResolver(resolverAddress, name, key);
      
      // Cache result
      _setCache(cacheKey, textValue);
      
      return textValue;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Get avatar URL for ENS name
  Future<String?> getAvatar(String name) async {
    final avatar = await getTextRecord(name, 'avatar');
    if (avatar == null || avatar.isEmpty) {
      return null;
    }

    // Handle different avatar formats
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }

    // Handle IPFS URLs
    if (avatar.startsWith('ipfs://')) {
      return _convertIpfsUrl(avatar);
    }

    // Handle NFT avatars (eip155:1/erc721:0x...)
    if (avatar.startsWith('eip155:')) {
      return _resolveNftAvatar(avatar);
    }

    return avatar;
  }

  /// Get multiple text records at once
  Future<Map<String, String?>> getTextRecords(String name, List<String> keys) async {
    final results = <String, String?>{};
    
    for (final key in keys) {
      results[key] = await getTextRecord(name, key);
    }
    
    return results;
  }

  /// Get common ENS profile records
  Future<ENSProfile> getProfile(String name) async {
    final records = await getTextRecords(name, [
      'avatar',
      'description',
      'display',
      'email',
      'keywords',
      'mail',
      'notice',
      'location',
      'phone',
      'url',
      'com.github',
      'com.twitter',
      'com.discord',
    ]);

    return ENSProfile(
      name: name,
      avatar: await getAvatar(name),
      description: records['description'],
      display: records['display'],
      email: records['email'] ?? records['mail'],
      keywords: records['keywords'],
      notice: records['notice'],
      location: records['location'],
      phone: records['phone'],
      url: records['url'],
      github: records['com.github'],
      twitter: records['com.twitter'],
      discord: records['com.discord'],
    );
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

  /// Get text record from resolver contract
  Future<String?> _getTextFromResolver(String resolverAddress, String name, String key) async {
    final nameHash = _namehash(name);
    
    final resolverContract = Contract(
      address: resolverAddress,
      abi: _ensResolverAbi,
      publicClient: _client,
    );

    try {
      final result = await resolverContract.read('text', [nameHash, key]);
      final textValue = result[0] as String?;
      
      if (textValue == null || textValue.isEmpty) {
        return null;
      }
      
      return textValue;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Convert IPFS URL to HTTP gateway URL
  String _convertIpfsUrl(String ipfsUrl) {
    if (ipfsUrl.startsWith('ipfs://')) {
      final hash = ipfsUrl.substring(7);
      return 'https://ipfs.io/ipfs/$hash';
    }
    return ipfsUrl;
  }

  /// Resolve NFT avatar URL
  Future<String?> _resolveNftAvatar(String nftSpec) async {
    // Parse NFT specification: eip155:1/erc721:0xcontract/tokenId
    final parts = nftSpec.split('/');
    if (parts.length != 3) return null;

    final chainPart = parts[0]; // eip155:1
    final contractPart = parts[1]; // erc721:0xcontract
    final tokenId = parts[2];

    if (!chainPart.startsWith('eip155:') || !contractPart.startsWith('erc721:')) {
      return null;
    }

    final contractAddress = contractPart.substring(7); // Remove 'erc721:'
    
    try {
      // Query NFT metadata
      final nftContract = Contract(
        address: contractAddress,
        abi: _erc721Abi,
        publicClient: _client,
      );

      final result = await nftContract.read('tokenURI', [BigInt.parse(tokenId)]);
      final tokenUri = result[0] as String?;
      
      if (tokenUri == null) return null;
      
      // Convert IPFS URLs
      if (tokenUri.startsWith('ipfs://')) {
        return _convertIpfsUrl(tokenUri);
      }
      
      return tokenUri;
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

  /// ENS Resolver ABI (minimal)
  static const String _ensResolverAbi = '''
[
    {
      "type": "function",
      "name": "text",
      "inputs": [
        {"name": "node", "type": "bytes32"},
        {"name": "key", "type": "string"}
      ],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    }
  ]''';

  /// ERC-721 ABI (minimal)
  static const String _erc721Abi = '''
[
    {
      "type": "function",
      "name": "tokenURI",
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view"
    }
  ]''';
}

/// ENS profile data structure
class ENSProfile {

  ENSProfile({
    required this.name,
    this.avatar,
    this.description,
    this.display,
    this.email,
    this.keywords,
    this.notice,
    this.location,
    this.phone,
    this.url,
    this.github,
    this.twitter,
    this.discord,
  });
  final String name;
  final String? avatar;
  final String? description;
  final String? display;
  final String? email;
  final String? keywords;
  final String? notice;
  final String? location;
  final String? phone;
  final String? url;
  final String? github;
  final String? twitter;
  final String? discord;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatar': avatar,
      'description': description,
      'display': display,
      'email': email,
      'keywords': keywords,
      'notice': notice,
      'location': location,
      'phone': phone,
      'url': url,
      'github': github,
      'twitter': twitter,
      'discord': discord,
    };
  }

  @override
  String toString() {
    return 'ENSProfile(name: $name, display: $display, avatar: $avatar)';
  }
}
