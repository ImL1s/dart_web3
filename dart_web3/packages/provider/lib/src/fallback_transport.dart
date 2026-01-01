import 'dart:async';
import 'dart:math';

import 'transport.dart';

/// Configuration for a transport in the fallback chain.
class FallbackTransportConfig {
  /// The transport instance.
  final Transport transport;

  /// Priority weight (higher = preferred). Default: 1
  final int priority;

  /// Timeout for this specific transport.
  final Duration? timeout;

  /// Number of consecutive failures.
  int failureCount = 0;

  /// Last recorded latency in milliseconds.
  int? latencyMs;

  /// Whether this transport is currently marked as unhealthy.
  bool isHealthy = true;

  /// Last health check time.
  DateTime? lastHealthCheck;

  FallbackTransportConfig({
    required this.transport,
    this.priority = 1,
    this.timeout,
  });
}

/// Options for the fallback transport.
class FallbackTransportOptions {
  /// Whether to automatically rank transports based on latency and stability.
  /// When enabled, the transport will periodically ping all providers and
  /// reorder them based on performance.
  final bool enableRanking;

  /// Interval for ranking health checks.
  final Duration rankingInterval;

  /// Number of samples to use for ranking calculation.
  final int sampleCount;

  /// Timeout for ranking ping requests.
  final Duration rankingTimeout;

  /// Weight for latency in ranking (0.0 - 1.0).
  final double latencyWeight;

  /// Weight for stability in ranking (0.0 - 1.0).
  final double stabilityWeight;

  /// Maximum number of retry attempts across all transports.
  final int retryCount;

  /// Base delay between retries (uses exponential backoff).
  final Duration retryDelay;

  /// Duration to wait before retrying a failed transport.
  final Duration failureCooldown;

  /// Number of consecutive failures before marking transport as unhealthy.
  final int failureThreshold;

  /// Method to use for health check pings.
  final String pingMethod;

  const FallbackTransportOptions({
    this.enableRanking = false,
    this.rankingInterval = const Duration(minutes: 1),
    this.sampleCount = 10,
    this.rankingTimeout = const Duration(seconds: 1),
    this.latencyWeight = 0.3,
    this.stabilityWeight = 0.7,
    this.retryCount = 3,
    this.retryDelay = const Duration(milliseconds: 150),
    this.failureCooldown = const Duration(seconds: 30),
    this.failureThreshold = 3,
    this.pingMethod = 'net_listening',
  });
}

/// Fallback transport that tries multiple transports in order.
///
/// Based on viem's fallback transport implementation:
/// - Tries transports in order until one succeeds
/// - Supports automatic ranking based on latency and stability
/// - Implements exponential backoff for retries
/// - Marks unhealthy transports and skips them temporarily
///
/// Example:
/// ```dart
/// final transport = FallbackTransport([
///   FallbackTransportConfig(transport: HttpTransport('https://rpc1.example.com')),
///   FallbackTransportConfig(transport: HttpTransport('https://rpc2.example.com')),
/// ], options: FallbackTransportOptions(enableRanking: true));
/// ```
class FallbackTransport implements Transport {
  final List<FallbackTransportConfig> _configs;
  final FallbackTransportOptions options;

  Timer? _rankingTimer;
  final List<List<int>> _latencySamples = [];
  bool _disposed = false;

  /// Stream of transport switch events.
  final _switchController = StreamController<TransportSwitchEvent>.broadcast();

  /// Stream that emits when the active transport changes.
  Stream<TransportSwitchEvent> get onSwitch => _switchController.stream;

  FallbackTransport(
    List<FallbackTransportConfig> configs, {
    this.options = const FallbackTransportOptions(),
  }) : _configs = List.from(configs) {
    // Initialize latency samples
    for (var i = 0; i < _configs.length; i++) {
      _latencySamples.add([]);
    }

    // Start ranking if enabled
    if (options.enableRanking) {
      _startRanking();
    }
  }

  /// Creates a fallback transport from a list of transports.
  factory FallbackTransport.fromTransports(
    List<Transport> transports, {
    FallbackTransportOptions options = const FallbackTransportOptions(),
  }) {
    return FallbackTransport(
      transports.map((t) => FallbackTransportConfig(transport: t)).toList(),
      options: options,
    );
  }

  void _startRanking() {
    _rankingTimer = Timer.periodic(options.rankingInterval, (_) => _performRanking());
    // Perform initial ranking
    _performRanking();
  }

  Future<void> _performRanking() async {
    if (_disposed) return;

    final futures = <Future<void>>[];

    for (var i = 0; i < _configs.length; i++) {
      futures.add(_pingTransport(i));
    }

    await Future.wait(futures);

    // Sort transports by score
    _reorderTransports();
  }

  Future<void> _pingTransport(int index) async {
    final config = _configs[index];
    final stopwatch = Stopwatch()..start();

    try {
      await config.transport
          .request(options.pingMethod, []).timeout(options.rankingTimeout);

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      // Record sample
      _latencySamples[index].add(latency);
      if (_latencySamples[index].length > options.sampleCount) {
        _latencySamples[index].removeAt(0);
      }

      config.latencyMs = latency;
      config.isHealthy = true;
      config.failureCount = 0;
      config.lastHealthCheck = DateTime.now();
    } catch (e) {
      stopwatch.stop();
      config.failureCount++;

      if (config.failureCount >= options.failureThreshold) {
        config.isHealthy = false;
      }
    }
  }

  void _reorderTransports() {
    // Calculate scores for each transport
    final scores = <int, double>{};

    for (var i = 0; i < _configs.length; i++) {
      final config = _configs[i];
      final samples = _latencySamples[i];

      if (samples.isEmpty || !config.isHealthy) {
        scores[i] = double.infinity;
        continue;
      }

      // Calculate average latency
      final avgLatency = samples.reduce((a, b) => a + b) / samples.length;

      // Calculate stability (lower variance = more stable)
      final variance = samples.map((s) => pow(s - avgLatency, 2)).reduce((a, b) => a + b) / samples.length;
      final stability = 1.0 / (1.0 + sqrt(variance));

      // Combined score (lower is better)
      final latencyScore = avgLatency * options.latencyWeight;
      final stabilityScore = (1.0 - stability) * 1000 * options.stabilityWeight;

      scores[i] = (latencyScore + stabilityScore) / config.priority;
    }

    // Sort by score
    final indices = List.generate(_configs.length, (i) => i);
    indices.sort((a, b) => scores[a]!.compareTo(scores[b]!));

    // Reorder configs
    final newConfigs = indices.map((i) => _configs[i]).toList();
    final newSamples = indices.map((i) => _latencySamples[i]).toList();

    _configs.clear();
    _configs.addAll(newConfigs);

    _latencySamples.clear();
    _latencySamples.addAll(newSamples);
  }

  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    Exception? lastError;
    int retryAttempt = 0;

    while (retryAttempt <= options.retryCount) {
      for (var i = 0; i < _configs.length; i++) {
        final config = _configs[i];

        // Skip unhealthy transports unless all are unhealthy
        if (!config.isHealthy && _configs.any((c) => c.isHealthy)) {
          // Check if cooldown has passed
          if (config.lastHealthCheck != null) {
            final elapsed = DateTime.now().difference(config.lastHealthCheck!);
            if (elapsed < options.failureCooldown) {
              continue;
            }
          }
        }

        try {
          final stopwatch = Stopwatch()..start();
          final result = await config.transport.request(method, params);
          stopwatch.stop();

          // Update latency
          config.latencyMs = stopwatch.elapsedMilliseconds;
          config.isHealthy = true;
          config.failureCount = 0;

          // Emit switch event if not first transport
          if (i > 0) {
            _switchController.add(TransportSwitchEvent(
              fromIndex: 0,
              toIndex: i,
              reason: 'Fallback due to primary failure',
            ));
          }

          return result;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          config.failureCount++;

          if (config.failureCount >= options.failureThreshold) {
            config.isHealthy = false;
            config.lastHealthCheck = DateTime.now();
          }

          // Continue to next transport
          continue;
        }
      }

      // All transports failed, apply exponential backoff and retry
      retryAttempt++;
      if (retryAttempt <= options.retryCount) {
        final delay = options.retryDelay * pow(2, retryAttempt - 1).toInt();
        await Future.delayed(delay);
      }
    }

    throw lastError ?? RpcError(-32000, 'All transports failed');
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    Exception? lastError;
    int retryAttempt = 0;

    while (retryAttempt <= options.retryCount) {
      for (final config in _configs) {
        if (!config.isHealthy && _configs.any((c) => c.isHealthy)) {
          continue;
        }

        try {
          return await config.transport.batchRequest(requests);
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          config.failureCount++;

          if (config.failureCount >= options.failureThreshold) {
            config.isHealthy = false;
            config.lastHealthCheck = DateTime.now();
          }
        }
      }

      retryAttempt++;
      if (retryAttempt <= options.retryCount) {
        final delay = options.retryDelay * pow(2, retryAttempt - 1).toInt();
        await Future.delayed(delay);
      }
    }

    throw lastError ?? RpcError(-32000, 'All transports failed');
  }

  /// Gets the current transport health status.
  List<TransportHealth> getHealthStatus() {
    return _configs.map((c) => TransportHealth(
      isHealthy: c.isHealthy,
      latencyMs: c.latencyMs,
      failureCount: c.failureCount,
      priority: c.priority,
    )).toList();
  }

  /// Manually marks a transport as unhealthy.
  void markUnhealthy(int index) {
    if (index >= 0 && index < _configs.length) {
      _configs[index].isHealthy = false;
      _configs[index].lastHealthCheck = DateTime.now();
    }
  }

  /// Resets all transports to healthy state.
  void resetHealth() {
    for (final config in _configs) {
      config.isHealthy = true;
      config.failureCount = 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rankingTimer?.cancel();
    _switchController.close();

    for (final config in _configs) {
      config.transport.dispose();
    }
  }
}

/// Event emitted when the active transport changes.
class TransportSwitchEvent {
  /// Index of the previous transport.
  final int fromIndex;

  /// Index of the new transport.
  final int toIndex;

  /// Reason for the switch.
  final String reason;

  TransportSwitchEvent({
    required this.fromIndex,
    required this.toIndex,
    required this.reason,
  });
}

/// Health status of a transport.
class TransportHealth {
  /// Whether the transport is currently healthy.
  final bool isHealthy;

  /// Last recorded latency in milliseconds.
  final int? latencyMs;

  /// Number of consecutive failures.
  final int failureCount;

  /// Priority weight.
  final int priority;

  TransportHealth({
    required this.isHealthy,
    this.latencyMs,
    required this.failureCount,
    required this.priority,
  });

  @override
  String toString() => 'TransportHealth(healthy: $isHealthy, latency: ${latencyMs}ms, failures: $failureCount)';
}
