import 'middleware.dart';
import 'transport.dart';

/// High-level RPC provider with middleware support.
class RpcProvider {

  RpcProvider(this.transport, {this.middlewares = const []});
  /// The underlying transport.
  final Transport transport;

  /// Middleware chain.
  final List<Middleware> middlewares;

  /// Sends an RPC request.
  Future<T> call<T>(String method, List<dynamic> params) async {
    // Run beforeRequest middlewares
    for (final middleware in middlewares) {
      final cached = await middleware.beforeRequest(method, params);
      if (cached != null) {
        return cached['result'] as T;
      }
    }

    try {
      var response = await transport.request(method, params);

      // Run afterResponse middlewares
      for (final middleware in middlewares) {
        response = await middleware.afterResponse(response);
      }

      // Cache response if applicable
      for (final middleware in middlewares) {
        if (middleware is CacheMiddleware) {
          middleware.cacheResponse(method, params, response);
        }
      }

      return response['result'] as T;
    } catch (e) {
      // Run onError middlewares
      for (final middleware in middlewares) {
        await middleware.onError(e as Exception);
      }
      rethrow;
    }
  }

  /// Sends multiple RPC requests in a batch.
  Future<List<T>> batchCall<T>(List<RpcRequest> requests) async {
    final responses = await transport.batchRequest(requests);
    return responses.map((r) => r['result'] as T).toList();
  }

  // Common RPC methods

  /// Gets the chain ID.
  Future<int> getChainId() async {
    final result = await call<String>('eth_chainId', []);
    return int.parse(result.substring(2), radix: 16);
  }

  /// Gets the current block number.
  Future<BigInt> getBlockNumber() async {
    final result = await call<String>('eth_blockNumber', []);
    return BigInt.parse(result.substring(2), radix: 16);
  }

  /// Gets the balance of an address.
  Future<BigInt> getBalance(String address, [String block = 'latest']) async {
    final result = await call<String>('eth_getBalance', [address, block]);
    return BigInt.parse(result.substring(2), radix: 16);
  }

  /// Gets a block by hash.
  Future<Map<String, dynamic>?> getBlockByHash(String hash, [bool fullTx = false]) async {
    return call<Map<String, dynamic>?>('eth_getBlockByHash', [hash, fullTx]);
  }

  /// Gets a block by number.
  Future<Map<String, dynamic>?> getBlockByNumber(String block, [bool fullTx = false]) async {
    return call<Map<String, dynamic>?>('eth_getBlockByNumber', [block, fullTx]);
  }

  /// Gets a transaction by hash.
  Future<Map<String, dynamic>?> getTransaction(String hash) async {
    return call<Map<String, dynamic>?>('eth_getTransactionByHash', [hash]);
  }

  /// Gets a transaction receipt.
  Future<Map<String, dynamic>?> getTransactionReceipt(String hash) async {
    return call<Map<String, dynamic>?>('eth_getTransactionReceipt', [hash]);
  }

  /// Gets the transaction count (nonce) for an address.
  Future<BigInt> getTransactionCount(String address, [String block = 'latest']) async {
    final result = await call<String>('eth_getTransactionCount', [address, block]);
    return BigInt.parse(result.substring(2), radix: 16);
  }

  /// Gets the current gas price.
  Future<BigInt> getGasPrice() async {
    final result = await call<String>('eth_gasPrice', []);
    return BigInt.parse(result.substring(2), radix: 16);
  }

  /// Estimates gas for a transaction.
  Future<BigInt> estimateGas(Map<String, dynamic> tx) async {
    final result = await call<String>('eth_estimateGas', [tx]);
    return BigInt.parse(result.substring(2), radix: 16);
  }

  /// Executes a call without creating a transaction.
  Future<String> ethCall(Map<String, dynamic> tx, [String block = 'latest']) async {
    return call<String>('eth_call', [tx, block]);
  }

  /// Sends a raw signed transaction.
  Future<String> sendRawTransaction(String signedTx) async {
    return call<String>('eth_sendRawTransaction', [signedTx]);
  }

  /// Gets logs matching a filter.
  Future<List<Map<String, dynamic>>> getLogs(Map<String, dynamic> filter) async {
    final result = await call<List<dynamic>>('eth_getLogs', [filter]);
    return result.cast<Map<String, dynamic>>();
  }

  /// Gets the code at an address.
  Future<String> getCode(String address, [String block = 'latest']) async {
    return call<String>('eth_getCode', [address, block]);
  }

  /// Gets storage at a position.
  Future<String> getStorageAt(String address, String position, [String block = 'latest']) async {
    return call<String>('eth_getStorageAt', [address, position, block]);
  }

  /// Disposes of the provider.
  void dispose() {
    transport.dispose();
  }
}
