import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// IPFS gateway manager with fallback support
class IpfsGateway {

  IpfsGateway({
    List<String>? gateways,
    Duration timeout = const Duration(seconds: 10),
  })  : _gateways = List<String>.from(gateways ?? _defaultGateways),
        _timeout = timeout;
  static const List<String> _defaultGateways = [
    'https://ipfs.io/ipfs/',
    'https://gateway.pinata.cloud/ipfs/',
    'https://cloudflare-ipfs.com/ipfs/',
    'https://dweb.link/ipfs/',
    'https://nftstorage.link/ipfs/',
  ];

  final List<String> _gateways;
  final Duration _timeout;
  final Map<String, String> _cache = {};

  /// Resolve IPFS URI to HTTP URL with fallback gateways
  Future<String?> resolveUri(String uri) async {
    if (!_isIpfsUri(uri)) {
      return uri; // Return as-is if not IPFS URI
    }

    // Check cache first
    if (_cache.containsKey(uri)) {
      return _cache[uri];
    }

    final hash = _extractIpfsHash(uri);
    if (hash == null) return null;

    // Try each gateway until one works
    for (final gateway in _gateways) {
      try {
        final url = '$gateway$hash';
        final response = await http.head(
          Uri.parse(url),
          headers: {'User-Agent': 'web3_universal_nft/1.0'},
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          _cache[uri] = url;
          return url;
        }
      } catch (e) {
        // Continue to next gateway
        continue;
      }
    }

    return null; // All gateways failed
  }

  /// Fetch JSON metadata from IPFS with fallback
  Future<Map<String, dynamic>?> fetchJson(String uri) async {
    final resolvedUri = await resolveUri(uri);
    if (resolvedUri == null) return null;

    try {
      final response = await http.get(
        Uri.parse(resolvedUri),
        headers: {'User-Agent': 'web3_universal_nft/1.0'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Return null on error
    }

    return null;
  }

  /// Fetch image data from IPFS with fallback
  Future<List<int>?> fetchImage(String uri) async {
    final resolvedUri = await resolveUri(uri);
    if (resolvedUri == null) return null;

    try {
      final response = await http.get(
        Uri.parse(resolvedUri),
        headers: {'User-Agent': 'web3_universal_nft/1.0'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      // Return null on error
    }

    return null;
  }

  /// Check if URI is an IPFS URI
  bool _isIpfsUri(String uri) {
    return uri.startsWith('ipfs://') || 
           uri.startsWith('Qm') || 
           uri.startsWith('baf');
  }

  /// Extract IPFS hash from URI
  String? _extractIpfsHash(String uri) {
    if (uri.startsWith('ipfs://')) {
      return uri.substring(7);
    } else if (uri.startsWith('Qm') || uri.startsWith('baf')) {
      return uri;
    }
    return null;
  }

  /// Add custom gateway
  void addGateway(String gateway) {
    if (!gateway.endsWith('/')) {
      gateway = '$gateway/';
    }
    if (!_gateways.contains(gateway)) {
      _gateways.add(gateway);
    }
  }

  /// Remove gateway
  void removeGateway(String gateway) {
    if (!gateway.endsWith('/')) {
      gateway = '$gateway/';
    }
    _gateways.remove(gateway);
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cache size
  int get cacheSize => _cache.length;

  /// Get available gateways
  List<String> get gateways => List.unmodifiable(_gateways);
}
