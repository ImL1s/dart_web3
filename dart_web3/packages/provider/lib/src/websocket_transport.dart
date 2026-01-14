import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'transport.dart';

/// WebSocket transport for JSON-RPC communication with subscription support.
class WebSocketTransport implements Transport {
  WebSocketTransport(
    this.url, {
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 3,
  });

  /// The WebSocket endpoint URL.
  final String url;

  /// Delay between reconnection attempts.
  final Duration reconnectDelay;

  /// Maximum number of reconnection attempts.
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  final _pendingRequests = <int, Completer<Map<String, dynamic>>>{};
  final _subscriptions = <String, StreamController<Map<String, dynamic>>>{};
  int _requestId = 0;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  /// Connects to the WebSocket server.
  Future<void> connect() async {
    if (_disposed) return;

    _channel = WebSocketChannel.connect(Uri.parse(url));
    _reconnectAttempts = 0;

    _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  void _handleMessage(dynamic message) {
    final data = json.decode(message as String) as Map<String, dynamic>;

    // Check if it's a subscription notification
    if (data.containsKey('method') && data['method'] == 'eth_subscription') {
      final params = data['params'] as Map<String, dynamic>;
      final subscriptionId = params['subscription'] as String;
      // ignore: close_sinks
      final controller = _subscriptions[subscriptionId];
      // ignore: close_sinks
      if (controller != null) {
        controller.add(params['result'] as Map<String, dynamic>);
      }
      return;
    }

    // Regular response
    final id = data['id'] as int?;
    if (id != null) {
      final completer = _pendingRequests.remove(id);
      if (completer != null) {
        if (data.containsKey('error')) {
          completer.completeError(
              RpcError.fromJson(data['error'] as Map<String, dynamic>));
        } else {
          completer.complete(data);
        }
      }
    }
  }

  void _handleError(Object error) {
    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      completer.completeError(error);
    }
    _pendingRequests.clear();
  }

  void _handleDone() {
    if (_disposed) return;

    // Attempt reconnection
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      Future<void>.delayed(reconnectDelay, connect);
    }
  }

  @override
  Future<Map<String, dynamic>> request(
      String method, List<dynamic> params) async {
    if (_channel == null) {
      await connect();
    }

    final requestId = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    final body = json.encode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
      'params': params,
    });

    _channel!.sink.add(body);

    return completer.future;
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(
      List<RpcRequest> requests) async {
    // WebSocket doesn't typically support batch requests
    // Execute sequentially
    final results = <Map<String, dynamic>>[];
    for (final req in requests) {
      results.add(await request(req.method, req.params));
    }
    return results;
  }

  /// Subscribes to a topic and returns a stream of notifications.
  Stream<Map<String, dynamic>> subscribe(
      String method, List<dynamic> params) async* {
    final response = await request(method, params);
    final subscriptionId = response['result'] as String;

    // ignore: close_sinks
    final controller = StreamController<Map<String, dynamic>>();
    _subscriptions[subscriptionId] = controller;

    try {
      await for (final data in controller.stream) {
        yield data;
      }
    } finally {
      await unsubscribe(subscriptionId);
    }
  }

  /// Unsubscribes from a subscription.
  Future<void> unsubscribe(String subscriptionId) async {
    await _subscriptions.remove(subscriptionId)?.close();
    await request('eth_unsubscribe', [subscriptionId]);
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    for (final controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
    for (final completer in _pendingRequests.values) {
      completer.completeError(StateError('Transport disposed'));
    }
    _pendingRequests.clear();
  }
}
