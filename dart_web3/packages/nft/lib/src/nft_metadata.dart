import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ipfs_gateway.dart';
import 'nft_types.dart';

/// NFT metadata parser and resolver
class NftMetadataParser {

  NftMetadataParser({
    IpfsGateway? ipfsGateway,
    Duration timeout = const Duration(seconds: 15),
  })  : _ipfsGateway = ipfsGateway ?? IpfsGateway(),
        _timeout = timeout;
  final IpfsGateway _ipfsGateway;
  final Duration _timeout;
  final Map<String, NftMetadata> _cache = {};

  /// Parse metadata from token URI
  Future<NftMetadata?> parseMetadata(String? tokenUri) async {
    if (tokenUri == null || tokenUri.isEmpty) return null;

    // Check cache first
    if (_cache.containsKey(tokenUri)) {
      return _cache[tokenUri];
    }

    try {
      Map<String, dynamic>? jsonData;

      // Handle different URI schemes
      if (_isDataUri(tokenUri)) {
        jsonData = _parseDataUri(tokenUri);
      } else if (_isIpfsUri(tokenUri)) {
        jsonData = await _ipfsGateway.fetchJson(tokenUri);
      } else if (_isHttpUri(tokenUri)) {
        jsonData = await _fetchHttpJson(tokenUri);
      } else {
        // Try as direct JSON
        try {
          jsonData = json.decode(tokenUri) as Map<String, dynamic>;
        } catch (e) {
          return null;
        }
      }

      if (jsonData != null) {
        final metadata = NftMetadata.fromJson(jsonData);
        _cache[tokenUri] = metadata;
        return metadata;
      }
    } catch (e) {
      // Return null on error
    }

    return null;
  }

  /// Resolve image URI to accessible URL
  Future<String?> resolveImageUri(String? imageUri) async {
    if (imageUri == null || imageUri.isEmpty) return null;

    if (_isIpfsUri(imageUri)) {
      return _ipfsGateway.resolveUri(imageUri);
    } else if (_isHttpUri(imageUri)) {
      return imageUri;
    } else if (_isDataUri(imageUri)) {
      return imageUri; // Data URIs are already accessible
    }

    return null;
  }

  /// Parse metadata with image resolution
  Future<NftMetadata?> parseMetadataWithImages(String? tokenUri) async {
    final metadata = await parseMetadata(tokenUri);
    if (metadata == null) return null;

    // Resolve image URIs
    final resolvedImage = await resolveImageUri(metadata.image);
    final resolvedAnimationUrl = await resolveImageUri(metadata.animationUrl);

    return NftMetadata(
      name: metadata.name,
      description: metadata.description,
      image: resolvedImage,
      externalUrl: metadata.externalUrl,
      animationUrl: resolvedAnimationUrl,
      youtubeUrl: metadata.youtubeUrl,
      backgroundColor: metadata.backgroundColor,
      attributes: metadata.attributes,
      rawMetadata: metadata.rawMetadata,
    );
  }

  /// Check if URI is a data URI
  bool _isDataUri(String uri) {
    return uri.startsWith('data:');
  }

  /// Check if URI is an IPFS URI
  bool _isIpfsUri(String uri) {
    return uri.startsWith('ipfs://') || 
           uri.startsWith('Qm') || 
           uri.startsWith('baf');
  }

  /// Check if URI is an HTTP URI
  bool _isHttpUri(String uri) {
    return uri.startsWith('http://') || uri.startsWith('https://');
  }

  /// Parse data URI
  Map<String, dynamic>? _parseDataUri(String dataUri) {
    try {
      final parts = dataUri.split(',');
      if (parts.length != 2) return null;

      final header = parts[0];
      final data = parts[1];

      if (header.contains('base64')) {
        final decoded = base64.decode(data);
        final jsonString = utf8.decode(decoded);
        return json.decode(jsonString) as Map<String, dynamic>;
      } else {
        final decoded = Uri.decodeComponent(data);
        return json.decode(decoded) as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch JSON from HTTP URI
  Future<Map<String, dynamic>?> _fetchHttpJson(String uri) async {
    try {
      final response = await http.get(
        Uri.parse(uri),
        headers: {
          'User-Agent': 'web3_universal_nft/1.0',
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Return null on error
    }

    return null;
  }

  /// Validate metadata structure
  bool validateMetadata(Map<String, dynamic> metadata) {
    // Basic validation - should have at least name or image
    return metadata.containsKey('name') || 
           metadata.containsKey('image') ||
           metadata.containsKey('description');
  }

  /// Extract metadata from contract response
  NftMetadata? extractFromContractResponse(Map<String, dynamic> response) {
    try {
      // Handle different response formats from various APIs
      if (response.containsKey('metadata')) {
        final metadata = response['metadata'];
        if (metadata is Map<String, dynamic>) {
          return NftMetadata.fromJson(metadata);
        } else if (metadata is String) {
          final parsed = json.decode(metadata) as Map<String, dynamic>;
          return NftMetadata.fromJson(parsed);
        }
      }

      // Direct metadata in response
      if (validateMetadata(response)) {
        return NftMetadata.fromJson(response);
      }
    } catch (e) {
      // Return null on error
    }

    return null;
  }

  /// Clear metadata cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cache size
  int get cacheSize => _cache.length;

  /// Get IPFS gateway
  IpfsGateway get ipfsGateway => _ipfsGateway;
}
