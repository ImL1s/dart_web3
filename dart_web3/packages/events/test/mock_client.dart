import 'dart:async';
import 'dart:typed_data';

import 'package:dart_web3_chains/dart_web3_chains.dart';
import 'package:dart_web3_client/dart_web3_client.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:dart_web3_provider/dart_web3_provider.dart';

/// Mock RPC provider for testing.
class MockRpcProvider implements RpcProvider {
  final Map<String, dynamic> _responses = {};
  final List<Map<String, dynamic>> _requests = [];

  @override
  final Transport transport = _MockTransport();

  @override
  final List<Middleware> middlewares = [];

  void setResponse(String method, dynamic response) {
    _responses[method] = response;
  }

  List<Map<String, dynamic>> get requests => List.unmodifiable(_requests);

  @override
  Future<T> call<T>(String method, List<dynamic> params) async {
    _requests.add({'method': method, 'params': params});
    
    if (_responses.containsKey(method)) {
      return _responses[method] as T;
    }
    
    throw Exception('No mock response for method: $method');
  }

  @override
  Future<List<T>> batchCall<T>(List<RpcRequest> requests) async {
    final results = <T>[];
    for (final request in requests) {
      results.add(await call<T>(request.method, request.params));
    }
    return results;
  }

  @override
  Future<BigInt> getBalance(String address, [String block = 'latest']) async {
    return await call<BigInt>('eth_getBalance', [address, block]);
  }

  @override
  Future<Map<String, dynamic>?> getBlockByHash(String hash, [bool fullTx = false]) async {
    return await call<Map<String, dynamic>?>('eth_getBlockByHash', [hash, fullTx]);
  }

  @override
  Future<Map<String, dynamic>?> getBlockByNumber(String block, [bool fullTx = false]) async {
    return await call<Map<String, dynamic>?>('eth_getBlockByNumber', [block, fullTx]);
  }

  @override
  Future<BigInt> getBlockNumber() async {
    return await call<BigInt>('eth_blockNumber', []);
  }

  @override
  Future<Map<String, dynamic>?> getTransaction(String hash) async {
    return await call<Map<String, dynamic>?>('eth_getTransactionByHash', [hash]);
  }

  @override
  Future<Map<String, dynamic>?> getTransactionReceipt(String hash) async {
    return await call<Map<String, dynamic>?>('eth_getTransactionReceipt', [hash]);
  }

  @override
  Future<BigInt> getTransactionCount(String address, [String block = 'latest']) async {
    return await call<BigInt>('eth_getTransactionCount', [address, block]);
  }

  @override
  Future<String> ethCall(Map<String, dynamic> transaction, [String block = 'latest']) async {
    return await call<String>('eth_call', [transaction, block]);
  }

  @override
  Future<BigInt> estimateGas(Map<String, dynamic> transaction) async {
    return await call<BigInt>('eth_estimateGas', [transaction]);
  }

  @override
  Future<List<Map<String, dynamic>>> getLogs(Map<String, dynamic> filter) async {
    return await call<List<Map<String, dynamic>>>('eth_getLogs', [filter]);
  }

  @override
  Future<BigInt> getGasPrice() async {
    return await call<BigInt>('eth_gasPrice', []);
  }

  @override
  Future<int> getChainId() async {
    return await call<int>('eth_chainId', []);
  }

  @override
  Future<String> getCode(String address, [String block = 'latest']) async {
    return await call<String>('eth_getCode', [address, block]);
  }

  @override
  Future<String> sendRawTransaction(String signedTx) async {
    return await call<String>('eth_sendRawTransaction', [signedTx]);
  }

  @override
  Future<String> getStorageAt(String address, String position, [String block = 'latest']) async {
    return await call<String>('eth_getStorageAt', [address, position, block]);
  }

  @override
  void dispose() {
    // Nothing to dispose in mock
  }
}

/// Mock transport for testing.
class _MockTransport implements Transport {
  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    throw UnimplementedError('Mock transport');
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    throw UnimplementedError('Mock transport');
  }

  @override
  void dispose() {
    // Nothing to dispose
  }
}

/// Mock WebSocket transport for testing.
class MockWebSocketTransport implements WebSocketTransport {
  final StreamController<Map<String, dynamic>> _subscriptionController = StreamController.broadcast();
  final Map<String, String> _subscriptions = {};
  int _subscriptionId = 0;

  @override
  String get url => 'ws://localhost:8545';

  @override
  Duration get reconnectDelay => const Duration(seconds: 5);

  @override
  int get maxReconnectAttempts => 3;

  @override
  Future<void> connect() async {
    // Mock connection
  }

  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    if (method == 'eth_subscribe') {
      final subscriptionId = 'sub_${++_subscriptionId}';
      _subscriptions[subscriptionId] = params[0] as String;
      return {'result': subscriptionId};
    }
    
    if (method == 'eth_unsubscribe') {
      final subscriptionId = params[0] as String;
      _subscriptions.remove(subscriptionId);
      return {'result': true};
    }
    
    throw Exception('Unsupported method: $method');
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    final results = <Map<String, dynamic>>[];
    for (final request in requests) {
      results.add(await this.request(request.method, request.params));
    }
    return results;
  }

  @override
  Stream<Map<String, dynamic>> subscribe(String method, List<dynamic> params) async* {
    final response = await request(method, params);
    final subscriptionId = response['result'] as String;
    
    // Create a filtered stream for this subscription
    await for (final data in _subscriptionController.stream) {
      if (data['subscription'] == subscriptionId) {
        final result = data['result'];
        if (result is Map<String, dynamic>) {
          yield result;
        } else if (result is String) {
          // For pending transactions, wrap string in a map
          yield {'txHash': result};
        } else {
          yield {'data': result};
        }
      }
    }
  }

  @override
  Future<void> unsubscribe(String subscriptionId) async {
    await request('eth_unsubscribe', [subscriptionId]);
  }

  /// Emits a mock subscription event.
  void emitSubscriptionEvent(String subscriptionId, dynamic data) {
    // Use a timer to ensure the event is emitted after the subscription is set up
    Timer.run(() {
      _subscriptionController.add({
        'subscription': subscriptionId,
        'result': data,
      });
    });
  }

  @override
  void dispose() {
    _subscriptionController.close();
  }
}

/// Mock public client for testing.
class MockPublicClient extends PublicClient {
  final MockRpcProvider mockProvider;

  MockPublicClient()
      : mockProvider = MockRpcProvider(),
        super(
          provider: MockRpcProvider(),
          chain: Chains.ethereum,
        );

  @override
  RpcProvider get provider => mockProvider;
}