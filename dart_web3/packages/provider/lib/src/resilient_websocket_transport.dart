import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'transport.dart';

/// Configuration for WebSocket reconnection behavior.
class WebSocketReconnectConfig {
  /// Whether to enable automatic reconnection.
  final bool enabled;

  /// Maximum number of reconnection attempts. Set to -1 for unlimited.
  final int maxAttempts;

  /// Initial delay between reconnection attempts.
  final Duration initialDelay;

  /// Maximum delay between reconnection attempts.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Whether to add random jitter to delays.
  final bool useJitter;

  const WebSocketReconnectConfig({
    this.enabled = true,
    this.maxAttempts = 10,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  /// Disabled reconnection config.
  static const disabled = WebSocketReconnectConfig(enabled: false);
}

/// Configuration for keep-alive ping messages.
class WebSocketKeepAliveConfig {
  /// Whether to enable keep-alive pings.
  final bool enabled;

  /// Interval between ping messages.
  final Duration interval;

  /// Timeout for ping response.
  final Duration timeout;

  const WebSocketKeepAliveConfig({
    this.enabled = true,
    this.interval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 10),
  });

  /// Disabled keep-alive config.
  static const disabled = WebSocketKeepAliveConfig(enabled: false);
}

/// Connection state for the WebSocket transport.
enum WebSocketConnectionState {
  /// Not connected.
  disconnected,

  /// Currently connecting.
  connecting,

  /// Connected and ready.
  connected,

  /// Attempting to reconnect.
  reconnecting,

  /// Failed to connect after all attempts.
  failed,
}

/// Event for connection state changes.
class WebSocketStateEvent {
  final WebSocketConnectionState previousState;
  final WebSocketConnectionState currentState;
  final String? error;
  final int? reconnectAttempt;

  WebSocketStateEvent({
    required this.previousState,
    required this.currentState,
    this.error,
    this.reconnectAttempt,
  });
}

/// Resilient WebSocket transport with automatic reconnection.
///
/// Features based on viem's WebSocket transport:
/// - Automatic reconnection with exponential backoff
/// - Keep-alive ping messages
/// - Subscription restoration after reconnect
/// - Connection state events
///
/// Example:
/// ```dart
/// final transport = ResilientWebSocketTransport(
///   'wss://mainnet.infura.io/ws/v3/YOUR_KEY',
///   reconnect: WebSocketReconnectConfig(
///     maxAttempts: 10,
///     initialDelay: Duration(seconds: 1),
///   ),
///   keepAlive: WebSocketKeepAliveConfig(
///     interval: Duration(seconds: 30),
///   ),
/// );
///
/// transport.onStateChange.listen((event) {
///   print('Connection state: ${event.currentState}');
/// });
/// ```
class ResilientWebSocketTransport implements Transport {
  /// The WebSocket endpoint URL.
  final String url;

  /// Reconnection configuration.
  final WebSocketReconnectConfig reconnect;

  /// Keep-alive configuration.
  final WebSocketKeepAliveConfig keepAlive;

  /// Request timeout.
  final Duration timeout;

  WebSocketChannel? _channel;
  final _pendingRequests = <int, Completer<Map<String, dynamic>>>{};
  final _subscriptions = <String, _SubscriptionInfo>{};
  int _requestId = 0;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  Completer<void>? _connectCompleter; // Prevents concurrent connect() calls
  bool _intentionalClose = false;

  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  final _stateController = StreamController<WebSocketStateEvent>.broadcast();
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  final _random = Random();

  /// Stream of connection state changes.
  Stream<WebSocketStateEvent> get onStateChange => _stateController.stream;

  /// Current connection state.
  WebSocketConnectionState get state => _state;

  /// Whether the transport is currently connected.
  bool get isConnected => _state == WebSocketConnectionState.connected;

  ResilientWebSocketTransport(
    this.url, {
    this.reconnect = const WebSocketReconnectConfig(),
    this.keepAlive = const WebSocketKeepAliveConfig(),
    this.timeout = const Duration(seconds: 30),
  });

  void _setState(WebSocketConnectionState newState, {String? error, int? attempt}) {
    final previous = _state;
    _state = newState;
    _stateController.add(WebSocketStateEvent(
      previousState: previous,
      currentState: newState,
      error: error,
      reconnectAttempt: attempt,
    ));
  }

  /// Connects to the WebSocket server.
  Future<void> connect() async {
    if (_disposed) return;

    // If already connected, return immediately
    if (_state == WebSocketConnectionState.connected) {
      return;
    }

    // If connection is in progress, wait for it to complete
    if (_connectCompleter != null) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<void>();
    _setState(WebSocketConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Wait for connection to establish
      await _channel!.ready;

      _reconnectAttempts = 0;
      _setState(WebSocketConnectionState.connected);

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      // Start keep-alive
      _startKeepAlive();

      // Restore subscriptions
      await _restoreSubscriptions();

      _connectCompleter!.complete();
    } catch (e) {
      _setState(WebSocketConnectionState.disconnected, error: e.toString());
      _connectCompleter!.completeError(e);
      _scheduleReconnect();
    } finally {
      _connectCompleter = null;
    }
  }

  void _startKeepAlive() {
    if (!keepAlive.enabled) return;

    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(keepAlive.interval, (_) => _sendPing());
  }

  Future<void> _sendPing() async {
    if (!isConnected) return;

    try {
      await request('net_listening', []).timeout(keepAlive.timeout);
    } catch (e) {
      // Ping failed, connection might be dead
      _handleDone();
    }
  }

  void _handleMessage(dynamic message) {
    // Handle both String and binary messages
    String messageStr;
    if (message is String) {
      messageStr = message;
    } else if (message is List<int>) {
      messageStr = String.fromCharCodes(message);
    } else {
      // Unknown message type, ignore
      return;
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(messageStr) as Map<String, dynamic>;
    } catch (e) {
      // Invalid JSON, ignore the message
      return;
    }

    // Check if it's a subscription notification
    if (data.containsKey('method') && data['method'] == 'eth_subscription') {
      final params = data['params'] as Map<String, dynamic>?;
      if (params != null) {
        final subscriptionId = params['subscription'] as String?;
        if (subscriptionId != null) {
          final info = _subscriptions[subscriptionId];
          if (info != null && params['result'] is Map<String, dynamic>) {
            info.controller.add(params['result'] as Map<String, dynamic>);
          }
        }
      }
      return;
    }

    // Regular response
    final id = data['id'] as int?;
    if (id != null) {
      final completer = _pendingRequests.remove(id);
      if (completer != null) {
        if (data.containsKey('error')) {
          completer.completeError(RpcError.fromJson(data['error'] as Map<String, dynamic>));
        } else {
          completer.complete(data);
        }
      }
    }
  }

  void _handleError(Object error) {
    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingRequests.clear();

    _setState(WebSocketConnectionState.disconnected, error: error.toString());
  }

  void _handleDone() {
    if (_disposed || _intentionalClose) return;

    _keepAliveTimer?.cancel();
    _setState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!reconnect.enabled || _disposed || _intentionalClose) return;

    if (reconnect.maxAttempts != -1 && _reconnectAttempts >= reconnect.maxAttempts) {
      _setState(WebSocketConnectionState.failed);
      // Complete pending requests with failure
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.completeError(RpcError(-32000, 'WebSocket connection failed after ${reconnect.maxAttempts} attempts'));
        }
      }
      _pendingRequests.clear();
      return;
    }

    _reconnectAttempts++;
    _setState(WebSocketConnectionState.reconnecting, attempt: _reconnectAttempts);

    // Calculate delay with exponential backoff
    var delay = reconnect.initialDelay.inMilliseconds *
        pow(reconnect.backoffMultiplier, _reconnectAttempts - 1).toInt();

    // Apply max delay cap
    delay = min(delay, reconnect.maxDelay.inMilliseconds);

    // Add jitter if enabled (±25%)
    if (reconnect.useJitter) {
      final jitter = (delay * 0.25 * (_random.nextDouble() * 2 - 1)).toInt();
      delay += jitter;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), connect);
  }

  Future<void> _restoreSubscriptions() async {
    if (_subscriptions.isEmpty) return;

    // Re-subscribe to all active subscriptions
    final entries = Map<String, _SubscriptionInfo>.from(_subscriptions);
    _subscriptions.clear();

    for (final entry in entries.entries) {
      try {
        final response = await request(entry.value.method, entry.value.params);
        final newSubId = response['result'] as String;
        _subscriptions[newSubId] = _SubscriptionInfo(
          method: entry.value.method,
          params: entry.value.params,
          controller: entry.value.controller,
        );
      } catch (e) {
        // Subscription restoration failed
        entry.value.controller.addError(e);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    if (_channel == null || !isConnected) {
      await connect();
    }

    if (_state == WebSocketConnectionState.failed) {
      throw RpcError(-32000, 'WebSocket connection failed');
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

    try {
      _channel!.sink.add(body);
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingRequests.remove(requestId);
      throw RpcError(-32000, 'Request timeout');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    // Execute sequentially for WebSocket
    final results = <Map<String, dynamic>>[];
    for (final req in requests) {
      results.add(await request(req.method, req.params));
    }
    return results;
  }

  /// Subscribes to a topic and returns a stream of notifications.
  ///
  /// The subscription will be automatically restored after reconnection.
  Stream<Map<String, dynamic>> subscribe(String method, List<dynamic> params) async* {
    final response = await request(method, params);
    final subscriptionId = response['result'] as String;

    final controller = StreamController<Map<String, dynamic>>();
    _subscriptions[subscriptionId] = _SubscriptionInfo(
      method: method,
      params: params,
      controller: controller,
    );

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
    final info = _subscriptions.remove(subscriptionId);
    info?.controller.close();

    if (isConnected) {
      try {
        await request('eth_unsubscribe', [subscriptionId]);
      } catch (_) {
        // Ignore errors during unsubscribe
      }
    }
  }

  /// Manually trigger a reconnection.
  Future<void> reconnectNow() async {
    _reconnectAttempts = 0;
    await _channel?.sink.close();
    await connect();
  }

  /// Gracefully close the connection.
  Future<void> close() async {
    _intentionalClose = true;
    await _channel?.sink.close();
    _setState(WebSocketConnectionState.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _intentionalClose = true;
    _keepAliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _stateController.close();
    _channel?.sink.close();

    for (final info in _subscriptions.values) {
      info.controller.close();
    }
    _subscriptions.clear();

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Transport disposed'));
      }
    }
    _pendingRequests.clear();
  }
}

/// Internal subscription info for restoration.
class _SubscriptionInfo {
  final String method;
  final List<dynamic> params;
  final StreamController<Map<String, dynamic>> controller;

  _SubscriptionInfo({
    required this.method,
    required this.params,
    required this.controller,
  });
}
