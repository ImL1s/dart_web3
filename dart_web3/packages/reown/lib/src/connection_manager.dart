/// Connection management with advanced reconnection logic for Reown/WalletConnect v2.
library;

import 'dart:async';
import 'dart:math';

import 'relay_client.dart';

/// Manages connection state and implements advanced reconnection strategies.
class ConnectionManager {
  final RelayClient relayClient;
  final ReconnectionConfig config;
  
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastConnectionAttempt;
  bool _isManuallyDisconnected = false;
  
  final StreamController<ConnectionState> _stateController = StreamController.broadcast();
  ConnectionState _currentState = ConnectionState.disconnected;
  
  late StreamSubscription _relaySubscription;

  ConnectionManager({
    required this.relayClient,
    ReconnectionConfig? config,
  }) : config = config ?? ReconnectionConfig.defaultConfig() {
    _relaySubscription = relayClient.events.listen(_handleRelayEvent);
  }

  /// Stream of connection state changes.
  Stream<ConnectionState> get stateChanges => _stateController.stream;

  /// Current connection state.
  ConnectionState get state => _currentState;

  /// Whether the connection is healthy.
  bool get isHealthy => _currentState == ConnectionState.connected;

  /// Time since last successful connection.
  Duration? get timeSinceLastConnection {
    if (_lastSuccessfulConnection == null) return null;
    return DateTime.now().difference(_lastSuccessfulConnection!);
  }

  /// Connects with automatic reconnection enabled.
  Future<void> connect() async {
    _isManuallyDisconnected = false;
    _setState(ConnectionState.connecting);
    
    try {
      await relayClient.connect();
      _onConnectionSuccess();
    } catch (e) {
      _onConnectionFailure(e);
    }
  }

  /// Disconnects and disables automatic reconnection.
  Future<void> disconnect() async {
    _isManuallyDisconnected = true;
    _stopReconnection();
    _stopHealthCheck();
    
    await relayClient.disconnect();
    _setState(ConnectionState.disconnected);
  }

  /// Forces a reconnection attempt.
  Future<void> reconnect() async {
    if (_currentState == ConnectionState.connecting) return;
    
    _setState(ConnectionState.reconnecting);
    
    try {
      await relayClient.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      await relayClient.connect();
      _onConnectionSuccess();
    } catch (e) {
      _onConnectionFailure(e);
    }
  }

  /// Handles relay events.
  void _handleRelayEvent(RelayEvent event) {
    switch (event.type) {
      case RelayEventType.connected:
        _onConnectionSuccess();
        break;
      case RelayEventType.disconnected:
        _onDisconnection();
        break;
      case RelayEventType.error:
        _onConnectionError(event.error);
        break;
      case RelayEventType.message:
        // Connection is healthy if we're receiving messages
        _onMessageReceived();
        break;
    }
  }

  /// Handles successful connection.
  void _onConnectionSuccess() {
    _reconnectAttempts = 0;
    _lastSuccessfulConnection = DateTime.now();
    _lastConnectionAttempt = DateTime.now();
    _stopReconnection();
    _startHealthCheck();
    _setState(ConnectionState.connected);
  }

  /// Handles connection failure.
  void _onConnectionFailure(dynamic error) {
    _lastConnectionAttempt = DateTime.now();
    
    if (_isManuallyDisconnected) {
      _setState(ConnectionState.disconnected);
      return;
    }

    _setState(ConnectionState.failed);
    _scheduleReconnection();
  }

  /// Handles disconnection.
  void _onDisconnection() {
    _stopHealthCheck();
    
    if (_isManuallyDisconnected) {
      _setState(ConnectionState.disconnected);
      return;
    }

    _setState(ConnectionState.disconnected);
    _scheduleReconnection();
  }

  /// Handles connection errors.
  void _onConnectionError(dynamic error) {
    if (_currentState == ConnectionState.connected) {
      // Connection was healthy but encountered an error
      _setState(ConnectionState.unstable);
    }
  }

  /// Handles message reception (indicates healthy connection).
  void _onMessageReceived() {
    if (_currentState == ConnectionState.unstable) {
      _setState(ConnectionState.connected);
    }
  }

  /// Schedules a reconnection attempt.
  void _scheduleReconnection() {
    if (_isManuallyDisconnected || _reconnectAttempts >= config.maxAttempts) {
      _setState(ConnectionState.failed);
      return;
    }

    _reconnectAttempts++;
    final delay = _calculateReconnectDelay();
    
    _setState(ConnectionState.waitingToReconnect);
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isManuallyDisconnected) {
        _attemptReconnection();
      }
    });
  }

  /// Attempts reconnection.
  Future<void> _attemptReconnection() async {
    if (_isManuallyDisconnected) return;
    
    _setState(ConnectionState.reconnecting);
    
    try {
      await relayClient.connect();
      _onConnectionSuccess();
    } catch (e) {
      _onConnectionFailure(e);
    }
  }

  /// Calculates the delay for the next reconnection attempt.
  Duration _calculateReconnectDelay() {
    switch (config.strategy) {
      case ReconnectionStrategy.fixed:
        return config.baseDelay;
      
      case ReconnectionStrategy.exponential:
        final delay = config.baseDelay.inMilliseconds * 
                     pow(config.backoffMultiplier, _reconnectAttempts - 1);
        return Duration(milliseconds: min(delay.toInt(), config.maxDelay.inMilliseconds));
      
      case ReconnectionStrategy.linear:
        final delay = config.baseDelay.inMilliseconds * _reconnectAttempts;
        return Duration(milliseconds: min(delay, config.maxDelay.inMilliseconds));
      
      case ReconnectionStrategy.jittered:
        final baseDelay = config.baseDelay.inMilliseconds * 
                         pow(config.backoffMultiplier, _reconnectAttempts - 1);
        final jitter = Random().nextDouble() * config.jitterRange.inMilliseconds;
        final totalDelay = baseDelay + jitter;
        return Duration(milliseconds: min(totalDelay.toInt(), config.maxDelay.inMilliseconds));
    }
  }

  /// Starts health check timer.
  void _startHealthCheck() {
    if (!config.enableHealthCheck) return;
    
    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(config.healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Stops health check timer.
  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Performs a health check.
  void _performHealthCheck() {
    if (!relayClient.isConnected) {
      _onDisconnection();
      return;
    }

    // Check if we haven't received any messages recently
    final timeSinceLastMessage = timeSinceLastConnection;
    if (timeSinceLastMessage != null && 
        timeSinceLastMessage > config.healthCheckTimeout) {
      _setState(ConnectionState.unstable);
      
      // Trigger a ping to test connectivity
      _sendPing();
    }
  }

  /// Sends a ping to test connectivity.
  void _sendPing() {
    // The RelayClient already handles pings in its heartbeat
    // This is a placeholder for additional health check logic
  }

  /// Stops reconnection attempts.
  void _stopReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Sets the connection state and notifies listeners.
  void _setState(ConnectionState newState) {
    if (_currentState != newState) {
      final oldState = _currentState;
      _currentState = newState;
      _stateController.add(newState);
      
      // Log state changes for debugging
      print('Connection state changed: $oldState -> $newState');
    }
  }

  /// Gets connection statistics.
  ConnectionStats getStats() {
    return ConnectionStats(
      currentState: _currentState,
      reconnectAttempts: _reconnectAttempts,
      lastSuccessfulConnection: _lastSuccessfulConnection,
      lastConnectionAttempt: _lastConnectionAttempt,
      timeSinceLastConnection: timeSinceLastConnection,
      isHealthy: isHealthy,
    );
  }

  /// Disposes the connection manager.
  void dispose() {
    _stopReconnection();
    _stopHealthCheck();
    _relaySubscription.cancel();
    _stateController.close();
  }
}

/// Connection states.
enum ConnectionState {
  /// Not connected and not attempting to connect.
  disconnected,
  
  /// Attempting initial connection.
  connecting,
  
  /// Successfully connected and healthy.
  connected,
  
  /// Connected but experiencing issues.
  unstable,
  
  /// Waiting before attempting reconnection.
  waitingToReconnect,
  
  /// Attempting to reconnect.
  reconnecting,
  
  /// Connection failed and no more attempts will be made.
  failed,
}

/// Reconnection strategies.
enum ReconnectionStrategy {
  /// Fixed delay between attempts.
  fixed,
  
  /// Exponentially increasing delay.
  exponential,
  
  /// Linearly increasing delay.
  linear,
  
  /// Exponential with random jitter.
  jittered,
}

/// Configuration for reconnection behavior.
class ReconnectionConfig {
  /// Maximum number of reconnection attempts.
  final int maxAttempts;
  
  /// Base delay between attempts.
  final Duration baseDelay;
  
  /// Maximum delay between attempts.
  final Duration maxDelay;
  
  /// Backoff multiplier for exponential strategy.
  final double backoffMultiplier;
  
  /// Reconnection strategy to use.
  final ReconnectionStrategy strategy;
  
  /// Random jitter range for jittered strategy.
  final Duration jitterRange;
  
  /// Whether to enable health checks.
  final bool enableHealthCheck;
  
  /// Interval between health checks.
  final Duration healthCheckInterval;
  
  /// Timeout for health check responses.
  final Duration healthCheckTimeout;

  ReconnectionConfig({
    required this.maxAttempts,
    required this.baseDelay,
    required this.maxDelay,
    required this.backoffMultiplier,
    required this.strategy,
    required this.jitterRange,
    required this.enableHealthCheck,
    required this.healthCheckInterval,
    required this.healthCheckTimeout,
  });

  /// Default configuration with reasonable values.
  factory ReconnectionConfig.defaultConfig() {
    return ReconnectionConfig(
      maxAttempts: 5,
      baseDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 30),
      backoffMultiplier: 2.0,
      strategy: ReconnectionStrategy.exponential,
      jitterRange: const Duration(milliseconds: 1000),
      enableHealthCheck: true,
      healthCheckInterval: const Duration(seconds: 30),
      healthCheckTimeout: const Duration(seconds: 60),
    );
  }

  /// Aggressive reconnection for critical connections.
  factory ReconnectionConfig.aggressive() {
    return ReconnectionConfig(
      maxAttempts: 10,
      baseDelay: const Duration(milliseconds: 500),
      maxDelay: const Duration(seconds: 10),
      backoffMultiplier: 1.5,
      strategy: ReconnectionStrategy.jittered,
      jitterRange: const Duration(milliseconds: 500),
      enableHealthCheck: true,
      healthCheckInterval: const Duration(seconds: 15),
      healthCheckTimeout: const Duration(seconds: 30),
    );
  }

  /// Conservative reconnection for stable connections.
  factory ReconnectionConfig.conservative() {
    return ReconnectionConfig(
      maxAttempts: 3,
      baseDelay: const Duration(seconds: 5),
      maxDelay: const Duration(minutes: 2),
      backoffMultiplier: 3.0,
      strategy: ReconnectionStrategy.exponential,
      jitterRange: const Duration(seconds: 2),
      enableHealthCheck: false,
      healthCheckInterval: const Duration(minutes: 1),
      healthCheckTimeout: const Duration(minutes: 2),
    );
  }
}

/// Connection statistics.
class ConnectionStats {
  final ConnectionState currentState;
  final int reconnectAttempts;
  final DateTime? lastSuccessfulConnection;
  final DateTime? lastConnectionAttempt;
  final Duration? timeSinceLastConnection;
  final bool isHealthy;

  ConnectionStats({
    required this.currentState,
    required this.reconnectAttempts,
    required this.lastSuccessfulConnection,
    required this.lastConnectionAttempt,
    required this.timeSinceLastConnection,
    required this.isHealthy,
  });

  @override
  String toString() {
    return 'ConnectionStats('
           'state: $currentState, '
           'attempts: $reconnectAttempts, '
           'lastConnection: $lastSuccessfulConnection, '
           'timeSince: $timeSinceLastConnection, '
           'healthy: $isHealthy)';
  }
}