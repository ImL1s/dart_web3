/// Middleware for intercepting RPC requests and responses.
abstract class Middleware {
  /// Called before a request is sent.
  Future<Map<String, dynamic>?> beforeRequest(String method, List<dynamic> params) async => null;

  /// Called after a response is received.
  Future<Map<String, dynamic>> afterResponse(Map<String, dynamic> response) async => response;

  /// Called when an error occurs.
  Future<void> onError(Exception error) async {}
}

/// Middleware that retries failed requests.
class RetryMiddleware extends Middleware {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Delay between retries.
  final Duration delay;

  /// Error codes that should trigger a retry.
  final Set<int> retryableCodes;

  int _currentAttempt = 0;

  RetryMiddleware({
    this.maxRetries = 3,
    this.delay = const Duration(seconds: 1),
    this.retryableCodes = const {-32000, -32603}, // Server error, internal error
  });

  @override
  Future<void> onError(Exception error) async {
    _currentAttempt++;
    if (_currentAttempt < maxRetries) {
      await Future<void>.delayed(delay * _currentAttempt);
    }
  }

  /// Whether a retry should be attempted.
  bool shouldRetry() => _currentAttempt < maxRetries;

  /// Resets the retry counter.
  void reset() => _currentAttempt = 0;
}

/// Middleware that logs requests and responses.
class LoggingMiddleware extends Middleware {
  /// Whether to log requests.
  final bool logRequests;

  /// Whether to log responses.
  final bool logResponses;

  /// Custom log function.
  final void Function(String message)? logger;

  LoggingMiddleware({
    this.logRequests = true,
    this.logResponses = false,
    this.logger,
  });

  void _log(String message) {
    if (logger != null) {
      logger!(message);
    } else {
      print(message);
    }
  }

  @override
  Future<Map<String, dynamic>?> beforeRequest(String method, List<dynamic> params) async {
    if (logRequests) {
      _log('RPC Request: $method($params)');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> afterResponse(Map<String, dynamic> response) async {
    if (logResponses) {
      _log('RPC Response: $response');
    }
    return response;
  }

  @override
  Future<void> onError(Exception error) async {
    _log('RPC Error: $error');
  }
}

/// Middleware that caches responses.
class CacheMiddleware extends Middleware {
  /// Cache duration.
  final Duration cacheDuration;

  /// Methods that should be cached.
  final Set<String> cacheableMethods;

  final _cache = <String, _CacheEntry>{};

  CacheMiddleware({
    this.cacheDuration = const Duration(seconds: 30),
    this.cacheableMethods = const {
      'eth_chainId',
      'eth_blockNumber',
      'eth_gasPrice',
      'eth_getBalance',
      'eth_getCode',
    },
  });

  String _cacheKey(String method, List<dynamic> params) {
    return '$method:${params.join(',')}';
  }

  @override
  Future<Map<String, dynamic>?> beforeRequest(String method, List<dynamic> params) async {
    if (!cacheableMethods.contains(method)) return null;

    final key = _cacheKey(method, params);
    final entry = _cache[key];

    if (entry != null && !entry.isExpired) {
      return entry.response;
    }

    return null;
  }

  @override
  Future<Map<String, dynamic>> afterResponse(Map<String, dynamic> response) async {
    // Cache is populated by the provider after getting the response
    return response;
  }

  /// Caches a response.
  void cacheResponse(String method, List<dynamic> params, Map<String, dynamic> response) {
    if (!cacheableMethods.contains(method)) return;

    final key = _cacheKey(method, params);
    _cache[key] = _CacheEntry(response, DateTime.now().add(cacheDuration));
  }

  /// Clears the cache.
  void clear() => _cache.clear();
}

class _CacheEntry {
  final Map<String, dynamic> response;
  final DateTime expiresAt;

  _CacheEntry(this.response, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
