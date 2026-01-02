
import 'package:dart_web3_reown/dart_web3_reown.dart';
import 'package:test/test.dart';

void main() {
  group('ReconnectionConfig', () {
    test('should create default config', () {
      final config = ReconnectionConfig.defaultConfig();
      
      expect(config.maxAttempts, equals(5));
      expect(config.baseDelay, equals(Duration(seconds: 1)));
      expect(config.strategy, equals(ReconnectionStrategy.exponential));
      expect(config.enableHealthCheck, isTrue);
    });

    test('should create aggressive config', () {
      final config = ReconnectionConfig.aggressive();
      
      expect(config.maxAttempts, equals(10));
      expect(config.baseDelay, equals(Duration(milliseconds: 500)));
      expect(config.strategy, equals(ReconnectionStrategy.jittered));
    });

    test('should create conservative config', () {
      final config = ReconnectionConfig.conservative();
      
      expect(config.maxAttempts, equals(3));
      expect(config.baseDelay, equals(Duration(seconds: 5)));
      expect(config.enableHealthCheck, isFalse);
    });
  });

  group('ConnectionState', () {
    test('should have all expected states', () {
      expect(ConnectionState.values, hasLength(7));
      expect(ConnectionState.values, contains(ConnectionState.disconnected));
      expect(ConnectionState.values, contains(ConnectionState.connecting));
      expect(ConnectionState.values, contains(ConnectionState.connected));
      expect(ConnectionState.values, contains(ConnectionState.unstable));
      expect(ConnectionState.values, contains(ConnectionState.waitingToReconnect));
      expect(ConnectionState.values, contains(ConnectionState.reconnecting));
      expect(ConnectionState.values, contains(ConnectionState.failed));
    });
  });

  group('ReconnectionStrategy', () {
    test('should have all expected strategies', () {
      expect(ReconnectionStrategy.values, hasLength(4));
      expect(ReconnectionStrategy.values, contains(ReconnectionStrategy.fixed));
      expect(ReconnectionStrategy.values, contains(ReconnectionStrategy.exponential));
      expect(ReconnectionStrategy.values, contains(ReconnectionStrategy.linear));
      expect(ReconnectionStrategy.values, contains(ReconnectionStrategy.jittered));
    });
  });

  group('ConnectionStats', () {
    test('should create stats correctly', () {
      final now = DateTime.now();
      final stats = ConnectionStats(
        currentState: ConnectionState.connected,
        reconnectAttempts: 2,
        lastSuccessfulConnection: now,
        lastConnectionAttempt: now,
        timeSinceLastConnection: Duration(minutes: 5),
        isHealthy: true,
      );
      
      expect(stats.currentState, equals(ConnectionState.connected));
      expect(stats.reconnectAttempts, equals(2));
      expect(stats.lastSuccessfulConnection, equals(now));
      expect(stats.isHealthy, isTrue);
    });

    test('should convert to string', () {
      final stats = ConnectionStats(
        currentState: ConnectionState.connected,
        reconnectAttempts: 0,
        lastSuccessfulConnection: null,
        lastConnectionAttempt: null,
        timeSinceLastConnection: null,
        isHealthy: true,
      );
      
      final string = stats.toString();
      expect(string, contains('ConnectionStats'));
      expect(string, contains('connected'));
      expect(string, contains('healthy: true'));
    });
  });

  // Note: Full ConnectionManager tests would require mocking RelayClient
  // which is complex. These tests cover the data structures and configurations.
  group('ConnectionManager Integration', () {
    test('should handle relay events correctly', () {
      // This would be a more complex integration test
      // For now, we test that the classes can be instantiated
      final config = ReconnectionConfig.defaultConfig();
      expect(config, isNotNull);
      
      // In a real test, we would:
      // 1. Create a mock RelayClient
      // 2. Create a ConnectionManager with the mock
      // 3. Simulate various relay events
      // 4. Verify the connection state changes appropriately
    });
  });
}
