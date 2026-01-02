/// Relay client for WalletConnect v2 protocol communication.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Relay protocol client for WalletConnect v2.
class RelayClient {

  RelayClient({
    required this.relayUrl,
    required this.projectId,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 3,
  });
  final String relayUrl;
  final String projectId;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;

  WebSocket? _socket;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final Map<String, StreamController<Map<String, dynamic>>> _subscriptions = {};
  final StreamController<RelayEvent> _eventController = StreamController.broadcast();
  
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _requestId = 0;

  /// Stream of relay events.
  Stream<RelayEvent> get events => _eventController.stream;

  /// Whether the client is connected.
  bool get isConnected => _socket != null;

  /// Connects to the relay server.
  Future<void> connect() async {
    if (_isConnecting || isConnected) return;
    
    _isConnecting = true;
    _shouldReconnect = true;

    try {
      final uri = Uri.parse('$relayUrl?projectId=$projectId');
      _socket = await WebSocket.connect(uri.toString());
      
      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _reconnectAttempts = 0;
      _isConnecting = false;
      _startHeartbeat();
      
      _eventController.add(RelayEvent.connected());
    } on Object catch (e) {
      _isConnecting = false;
      _handleError(e);
    }
  }

  /// Disconnects from the relay server.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    await _socket?.close();
    _socket = null;
    
    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection closed'));
      }
    }
    _pendingRequests.clear();
    
    // Close all subscriptions
    for (final controller in _subscriptions.values) {
      await controller.close();
    }
    _subscriptions.clear();
    
    _eventController.add(RelayEvent.disconnected());
  }

  /// Publishes a message to a topic.
  Future<void> publish({
    required String topic,
    required Map<String, dynamic> message,
    int? ttl,
    bool? prompt,
    String? tag,
  }) async {
    if (!isConnected) {
      throw Exception('Not connected to relay');
    }

    final request = {
      'id': ++_requestId,
      'jsonrpc': '2.0',
      'method': 'irn_publish',
      'params': {
        'topic': topic,
        'message': base64Encode(utf8.encode(jsonEncode(message))),
        'ttl': ttl ?? 86400, // 24 hours default
        if (prompt != null) 'prompt': prompt,
        if (tag != null) 'tag': tag,
      },
    };

    await _sendRequest(request);
  }

  /// Subscribes to a topic.
  Future<String> subscribe(String topic) async {
    if (!isConnected) {
      throw Exception('Not connected to relay');
    }

    final request = {
      'id': ++_requestId,
      'jsonrpc': '2.0',
      'method': 'irn_subscribe',
      'params': {
        'topic': topic,
      },
    };

    final response = await _sendRequest(request);
    final subscriptionId = response['result'] as String;
    
    // Create stream controller for this subscription
    _subscriptions[subscriptionId] = StreamController<Map<String, dynamic>>.broadcast();
    
    return subscriptionId;
  }

  /// Unsubscribes from a topic.
  Future<void> unsubscribe(String subscriptionId) async {
    if (!isConnected) {
      throw Exception('Not connected to relay');
    }

    final request = {
      'id': ++_requestId,
      'jsonrpc': '2.0',
      'method': 'irn_unsubscribe',
      'params': {
        'id': subscriptionId,
      },
    };

    await _sendRequest(request);
    
    // Close and remove subscription
    await _subscriptions[subscriptionId]?.close();
    _subscriptions.remove(subscriptionId);
  }

  /// Gets messages for a subscription.
  Stream<Map<String, dynamic>> getSubscription(String subscriptionId) {
    // ignore: close_sinks
    final controller = _subscriptions[subscriptionId];
    if (controller == null) {
      throw Exception('Subscription not found: $subscriptionId');
    }
    // Controller is closed in unsubscribe or dispose
    return controller.stream;
  }

  /// Sends a request and waits for response.
  Future<Map<String, dynamic>> _sendRequest(Map<String, dynamic> request) async {
    if (!isConnected) {
      throw Exception('Not connected to relay');
    }

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[request['id'].toString()] = completer;

    _socket!.add(jsonEncode(request));

    // Set timeout for request
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        _pendingRequests.remove(request['id'].toString());
        completer.completeError(TimeoutException('Request timeout', const Duration(seconds: 30)));
      }
    });

    return completer.future;
  }

  /// Handles incoming messages.
  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      
      if (message.containsKey('id')) {
        // Response to a request
        final id = message['id'].toString();
        final completer = _pendingRequests.remove(id);
        
        if (completer != null && !completer.isCompleted) {
          if (message.containsKey('error')) {
            completer.completeError(RelayError.fromJson(message['error'] as Map<String, dynamic>));
          } else {
            completer.complete(message);
          }
        }
      } else if (message['method'] == 'irn_subscription') {
        // Subscription message
        final params = message['params'] as Map<String, dynamic>;
        final subscriptionId = params['id'] as String;
        final data = params['data'] as Map<String, dynamic>;
        
        // Decode message
        final encodedMessage = data['message'] as String;
        final decodedBytes = base64Decode(encodedMessage);
        final decodedMessage = jsonDecode(utf8.decode(decodedBytes)) as Map<String, dynamic>;
        
        // ignore: close_sinks
        final controller = _subscriptions[subscriptionId];
        if (controller != null && !controller.isClosed) {
          controller.add(decodedMessage);
        }
        
        _eventController.add(RelayEvent.message(
          topic: data['topic'] as String,
          message: decodedMessage,
        ),);
      }
    } on Object catch (e) {
      _eventController.add(RelayEvent.error(e));
    }
  }

  /// Handles connection errors.
  void _handleError(dynamic error) {
    _eventController.add(RelayEvent.error(error));
    
    if (_shouldReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  /// Handles disconnection.
  void _handleDisconnect() {
    _socket = null;
    _heartbeatTimer?.cancel();
    
    if (_shouldReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      _eventController.add(RelayEvent.disconnected());
    }
  }

  /// Schedules a reconnection attempt.
  void _scheduleReconnect() {
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_shouldReconnect) {
        connect();
      }
    });
  }

  /// Starts heartbeat to keep connection alive.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected) {
        _socket!.add(jsonEncode({
          'id': ++_requestId,
          'jsonrpc': '2.0',
          'method': 'irn_ping',
          'params': <String, dynamic>{},
        }),);
      }
    });
  }

  /// Disposes the client.
  void dispose() {
    for (final controller in _subscriptions.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _subscriptions.clear();
    
    disconnect();
    _eventController.close();
  }
}

/// Relay event types.
class RelayEvent {

  RelayEvent._(this.type, {this.topic, this.message, this.error});

  factory RelayEvent.connected() => RelayEvent._(RelayEventType.connected);
  factory RelayEvent.disconnected() => RelayEvent._(RelayEventType.disconnected);
  factory RelayEvent.message({required String topic, required Map<String, dynamic> message}) =>
      RelayEvent._(RelayEventType.message, topic: topic, message: message);
  factory RelayEvent.error(dynamic error) => RelayEvent._(RelayEventType.error, error: error);
  final RelayEventType type;
  final String? topic;
  final Map<String, dynamic>? message;
  final dynamic error;
}

enum RelayEventType {
  connected,
  disconnected,
  message,
  error,
}

/// Relay error.
class RelayError implements Exception {

  RelayError(this.code, this.message, [this.data]);

  factory RelayError.fromJson(Map<String, dynamic> json) {
    return RelayError(
      json['code'] as int,
      json['message'] as String,
      json['data'],
    );
  }
  final int code;
  final String message;
  final dynamic data;

  @override
  String toString() => 'RelayError($code): $message';
}
