import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for fetching cryptocurrency prices
class PriceService {

  PriceService({
    http.Client? httpClient,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _httpClient = httpClient ?? http.Client(),
        _cacheTtl = cacheTtl;
  final http.Client _httpClient;
  final Map<String, dynamic> _cache = {};
  final Duration _cacheTtl;

  /// Fetch simple price from CoinGecko
  Future<double?> getPrice(String id, {String vsCurrency = 'usd'}) async {
    final cacheKey = '${id}_$vsCurrency';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]['price'] as double;
    }

    try {
      final url = 'https://api.coingecko.com/api/v3/simple/price?ids=$id&vs_currencies=$vsCurrency';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data.containsKey(id)) {
          final price = (data[id][vsCurrency] as num).toDouble();
          _updateCache(cacheKey, price);
          return price;
        }
      }
    } catch (e) {
      // Return cached value if available even if expired
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]['price'] as double;
      }
    }

    return null;
  }

  /// Fetch multiple prices
  Future<Map<String, double>> getPrices(List<String> ids, {String vsCurrency = 'usd'}) async {
    final results = <String, double>{};
    final toFetch = <String>[];

    for (final id in ids) {
      final cacheKey = '${id}_$vsCurrency';
      if (_isCacheValid(cacheKey)) {
        results[id] = _cache[cacheKey]['price'] as double;
      } else {
        toFetch.add(id);
      }
    }

    if (toFetch.isEmpty) return results;

    try {
      final idsParam = toFetch.join(',');
      final url = 'https://api.coingecko.com/api/v3/simple/price?ids=$idsParam&vs_currencies=$vsCurrency';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        for (final id in toFetch) {
          if (data.containsKey(id)) {
            final price = (data[id][vsCurrency] as num).toDouble();
            _updateCache('${id}_$vsCurrency', price);
            results[id] = price;
          }
        }
      }
    } catch (e) {
      // Ignore errors if we have partial results from cache
    }

    return results;
  }

  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;
    final timestamp = _cache[key]['timestamp'] as DateTime;
    return DateTime.now().difference(timestamp) < _cacheTtl;
  }

  void _updateCache(String key, double price) {
    _cache[key] = {
      'price': price,
      'timestamp': DateTime.now(),
    };
  }

  void clearCache() {
    _cache.clear();
  }
}
