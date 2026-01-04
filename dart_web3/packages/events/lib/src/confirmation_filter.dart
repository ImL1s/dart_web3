import 'dart:async';

import 'package:web3_universal_client/web3_universal_client.dart';

import 'event_filter.dart';
import 'event_subscriber.dart';

/// Filters events based on block confirmations.
class ConfirmationFilter {

  ConfirmationFilter(
    this.subscriber, {
    this.requiredConfirmations = 12,
    this.checkInterval = const Duration(seconds: 30),
  });
  /// The event subscriber.
  final EventSubscriber subscriber;

  /// Required number of confirmations.
  final int requiredConfirmations;

  /// Pending logs waiting for confirmations.
  final Map<String, _PendingLog> _pendingLogs = {};

  /// Timer for checking confirmations.
  Timer? _confirmationTimer;

  /// Confirmation check interval.
  final Duration checkInterval;

  /// Filters events to only emit those with sufficient confirmations.
  /// 
  /// Returns a stream of logs that have at least [requiredConfirmations] confirmations.
  Stream<Log> filterByConfirmations(EventFilter filter) async* {
    final controller = StreamController<Log>();

    // Start confirmation checking timer
    _startConfirmationTimer(controller);

    // Subscribe to events
    final subscription = subscriber.subscribe(filter).listen((log) {
      _addPendingLog(log, controller);
    });

    try {
      await for (final log in controller.stream) {
        yield log;
      }
    } finally {
      unawaited(subscription.cancel());
      _stopConfirmationTimer();
    }
  }

  /// Filters events with custom confirmation requirements.
  /// 
  /// [filter] - The event filter
  /// [confirmations] - Required confirmations for this specific filter
  /// [onConfirmed] - Callback when a log is confirmed
  /// [onPending] - Optional callback for pending logs with confirmation count
  /// 
  /// Returns a subscription that can be cancelled.
  StreamSubscription<Log> filterWithCallback(
    EventFilter filter, {
    required void Function(Log) onConfirmed, int? confirmations,
    void Function(Log, int)? onPending,
  }) {
    final requiredConf = confirmations ?? requiredConfirmations;

    // Custom pending logs for this filter
    final pendingLogs = <String, _PendingLog>{};

    // Timer for this specific filter
    Timer? timer;

    Future<void> checkConfirmations() async {
      try {
        final currentBlock = await subscriber.publicClient.getBlockNumber();
        final confirmedKeys = <String>[];

        for (final entry in pendingLogs.entries) {
          final key = entry.key;
          final pendingLog = entry.value;
          final confirmationCount = (currentBlock - pendingLog.log.blockNumber).toInt();

          if (confirmationCount >= requiredConf) {
            // Log is confirmed
            onConfirmed(pendingLog.log);
            confirmedKeys.add(key);
          } else if (onPending != null) {
            // Log is still pending
            onPending(pendingLog.log, confirmationCount);
          }
        }

        // Remove confirmed logs
        for (final key in confirmedKeys) {
          pendingLogs.remove(key);
        }
      } on Exception catch (_) {
        // Continue on error
      }
    }

    // Start timer
    timer = Timer.periodic(checkInterval, (_) => checkConfirmations());

    // Subscribe to events
    final subscription = subscriber.subscribe(filter).listen((log) {
      final key = '${log.transactionHash}_${log.logIndex}';
      pendingLogs[key] = _PendingLog(log, DateTime.now());
    });

    // Return a custom subscription that cleans up properly
    return _CustomSubscription<Log>(
      onCancel: () async {
        await subscription.cancel();
        timer?.cancel();
        pendingLogs.clear();
      },
    );
  }

  /// Gets the current confirmation count for a log.
  Future<int> getConfirmationCount(Log log) async {
    final currentBlock = await subscriber.publicClient.getBlockNumber();
    return (currentBlock - log.blockNumber).toInt();
  }

  /// Checks if a log has sufficient confirmations.
  Future<bool> isConfirmed(Log log, {int? confirmations}) async {
    final requiredConf = confirmations ?? requiredConfirmations;
    final confirmationCount = await getConfirmationCount(log);
    return confirmationCount >= requiredConf;
  }

  /// Gets all pending logs and their confirmation counts.
  Future<Map<Log, int>> getPendingLogsWithConfirmations() async {
    final result = <Log, int>{};
    final currentBlock = await subscriber.publicClient.getBlockNumber();

    for (final pendingLog in _pendingLogs.values) {
      final confirmationCount = (currentBlock - pendingLog.log.blockNumber).toInt();
      result[pendingLog.log] = confirmationCount;
    }

    return result;
  }

  /// Gets the number of pending logs.
  int get pendingLogCount => _pendingLogs.length;

  /// Gets all pending logs.
  List<Log> get pendingLogs => _pendingLogs.values.map((p) => p.log).toList();

  /// Clears all pending logs.
  void clearPendingLogs() {
    _pendingLogs.clear();
  }

  /// Adds a log to the pending list.
  void _addPendingLog(Log log, StreamController<Log> controller) {
    final key = '${log.transactionHash}_${log.logIndex}';
    _pendingLogs[key] = _PendingLog(log, DateTime.now());
  }

  /// Starts the confirmation checking timer.
  void _startConfirmationTimer(StreamController<Log> controller) {
    _confirmationTimer = Timer.periodic(checkInterval, (_) async {
      await _checkConfirmations(controller);
    });
  }

  /// Stops the confirmation checking timer.
  void _stopConfirmationTimer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
  }

  /// Checks confirmations for all pending logs.
  Future<void> _checkConfirmations(StreamController<Log> controller) async {
    try {
      final currentBlock = await subscriber.publicClient.getBlockNumber();
      final confirmedKeys = <String>[];

      for (final entry in _pendingLogs.entries) {
        final key = entry.key;
        final pendingLog = entry.value;
        final confirmationCount = (currentBlock - pendingLog.log.blockNumber).toInt();

        if (confirmationCount >= requiredConfirmations) {
          // Log is confirmed
          controller.add(pendingLog.log);
          confirmedKeys.add(key);
        }
      }

      // Remove confirmed logs
      for (final key in confirmedKeys) {
        _pendingLogs.remove(key);
      }
    } on Exception catch (_) {
      // Continue on error
    }
  }

  /// Disposes of the filter and cleans up resources.
  void dispose() {
    _stopConfirmationTimer();
    _pendingLogs.clear();
  }
}

/// Represents a log waiting for confirmations.
class _PendingLog {

  _PendingLog(this.log, this.timestamp);
  /// The log.
  final Log log;

  /// When the log was first seen.
  final DateTime timestamp;
}

/// Configuration for confirmation filtering.
class ConfirmationConfig {

  const ConfirmationConfig({
    this.confirmations = 12,
    this.checkInterval = const Duration(seconds: 30),
    this.timeout,
  });
  /// Required number of confirmations.
  final int confirmations;

  /// How often to check for confirmations.
  final Duration checkInterval;

  /// Maximum time to wait for confirmations before timing out.
  final Duration? timeout;

  /// Configuration for fast confirmations (suitable for testnets).
  static const fast = ConfirmationConfig(
    confirmations: 3,
    checkInterval: Duration(seconds: 10),
  );

  /// Configuration for standard confirmations (mainnet).
  static const standard = ConfirmationConfig(
    
  );

  /// Configuration for high security confirmations.
  static const secure = ConfirmationConfig(
    confirmations: 20,
    checkInterval: Duration(seconds: 60),
  );
}

/// Custom subscription implementation for confirmation filtering.
class _CustomSubscription<T> implements StreamSubscription<T> {

  _CustomSubscription({Future<void> Function()? onCancel}) : _onCancel = onCancel;
  final Future<void> Function()? _onCancel;
  bool _isPaused = false;
  bool _isCanceled = false;

  @override
  Future<void> cancel() async {
    if (_isCanceled) return;
    _isCanceled = true;
    await _onCancel?.call();
  }

  @override
  void onData(void Function(T data)? handleData) {
    // Not used in this implementation
  }

  @override
  void onError(Function? handleError) {
    // Not used in this implementation
  }

  @override
  void onDone(void Function()? handleDone) {
    // Not used in this implementation
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _isPaused = true;
    resumeSignal?.then((_) => resume());
  }

  @override
  void resume() {
    _isPaused = false;
  }

  @override
  bool get isPaused => _isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    throw UnsupportedError('asFuture not supported');
  }
}
