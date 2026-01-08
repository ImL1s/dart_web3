import 'dart:async';

import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'package:test/test.dart';

/// Mock transport for testing.
class MockTransport implements Transport {
  final String name;
  final bool shouldFail;
  final Duration delay;
  int requestCount = 0;

  MockTransport(this.name, {this.shouldFail = false, this.delay = Duration.zero});

  @override
  Future<Map<String, dynamic>> request(String method, List<dynamic> params) async {
    requestCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldFail) {
      throw RpcError(-32000, '$name failed');
    }
    return {'jsonrpc': '2.0', 'id': 1, 'result': '$name:$method'};
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(List<RpcRequest> requests) async {
    return [await request(requests.first.method, requests.first.params)];
  }

  @override
  void dispose() {}
}

void main() {
  group('FallbackTransport', () {
    test('uses first transport when healthy', () async {
      final transport1 = MockTransport('transport1');
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport([
        FallbackTransportConfig(transport: transport1),
        FallbackTransportConfig(transport: transport2),
      ]);

      final result = await fallback.request('eth_blockNumber', []);
      expect(result['result'], equals('transport1:eth_blockNumber'));
      expect(transport1.requestCount, equals(1));
      expect(transport2.requestCount, equals(0));

      fallback.dispose();
    });

    test('falls back to second transport on failure', () async {
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport([
        FallbackTransportConfig(transport: transport1),
        FallbackTransportConfig(transport: transport2),
      ]);

      final result = await fallback.request('eth_blockNumber', []);
      expect(result['result'], equals('transport2:eth_blockNumber'));
      expect(transport1.requestCount, equals(1));
      expect(transport2.requestCount, equals(1));

      fallback.dispose();
    });

    test('throws when all transports fail', () async {
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2', shouldFail: true);

      final fallback = FallbackTransport(
        [
          FallbackTransportConfig(transport: transport1),
          FallbackTransportConfig(transport: transport2),
        ],
        options: FallbackTransportOptions(retryCount: 0),
      );

      expect(
        () => fallback.request('eth_blockNumber', []),
        throwsA(isA<RpcError>()),
      );

      fallback.dispose();
    });

    test('marks transport as unhealthy after threshold failures', () async {
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport(
        [
          FallbackTransportConfig(transport: transport1),
          FallbackTransportConfig(transport: transport2),
        ],
        options: FallbackTransportOptions(
          failureThreshold: 2,
          retryCount: 0,
        ),
      );

      // First request - transport1 fails (count=1), fallback to transport2
      await fallback.request('eth_blockNumber', []);
      expect(fallback.getHealthStatus()[0].isHealthy, isTrue);

      // Second request - transport1 fails again (count=2), now unhealthy
      await fallback.request('eth_blockNumber', []);
      expect(fallback.getHealthStatus()[0].isHealthy, isFalse);

      fallback.dispose();
    });

    test('emits switch events when changing transports', () async {
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport([
        FallbackTransportConfig(transport: transport1),
        FallbackTransportConfig(transport: transport2),
      ]);

      final eventCompleter = Completer<TransportSwitchEvent>();
      fallback.onSwitch.listen((event) {
        if (!eventCompleter.isCompleted) {
          eventCompleter.complete(event);
        }
      });

      await fallback.request('eth_blockNumber', []);

      // Wait briefly for the async event
      final event = await eventCompleter.future.timeout(
        Duration(milliseconds: 100),
        onTimeout: () => throw StateError('No switch event received'),
      );

      expect(event.fromIndex, equals(0));
      expect(event.toIndex, equals(1));

      fallback.dispose();
    });

    test('respects priority weights', () async {
      final transport1 = MockTransport('transport1');
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport([
        FallbackTransportConfig(transport: transport1, priority: 1),
        FallbackTransportConfig(transport: transport2, priority: 10),
      ]);

      final health = fallback.getHealthStatus();
      expect(health[0].priority, equals(1));
      expect(health[1].priority, equals(10));

      fallback.dispose();
    });

    test('fromTransports creates fallback correctly', () async {
      final transport1 = MockTransport('transport1');
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport.fromTransports([transport1, transport2]);

      final result = await fallback.request('eth_blockNumber', []);
      expect(result['result'], equals('transport1:eth_blockNumber'));

      fallback.dispose();
    });

    test('tracks fromIndex correctly through multiple switches', () async {
      // Start with transport1 failing, so we switch to transport2
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2');
      final transport3 = MockTransport('transport3');

      final fallback = FallbackTransport([
        FallbackTransportConfig(transport: transport1),
        FallbackTransportConfig(transport: transport2),
        FallbackTransportConfig(transport: transport3),
      ]);

      final events = <TransportSwitchEvent>[];
      fallback.onSwitch.listen(events.add);

      // First request: should switch from 0 to 1
      await fallback.request('eth_blockNumber', []);

      // Wait for events
      await Future.delayed(Duration(milliseconds: 50));
      expect(events.length, equals(1));
      expect(events[0].fromIndex, equals(0));
      expect(events[0].toIndex, equals(1));

      fallback.dispose();
    });

    test('batchRequest uses cooldown like single request', () async {
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport(
        [
          FallbackTransportConfig(transport: transport1),
          FallbackTransportConfig(transport: transport2),
        ],
        options: FallbackTransportOptions(
          failureThreshold: 1,
          failureCooldown: Duration(seconds: 60),
          retryCount: 0,
        ),
      );

      // First batch request - transport1 fails, fallback to transport2
      await fallback.batchRequest([RpcRequest('eth_blockNumber', [])]);

      // Transport1 should now be unhealthy
      expect(fallback.getHealthStatus()[0].isHealthy, isFalse);

      // Second batch request - should skip transport1 due to cooldown
      transport1.requestCount = 0;
      await fallback.batchRequest([RpcRequest('eth_blockNumber', [])]);

      // Transport1 shouldn't have been called due to cooldown
      expect(transport1.requestCount, equals(0));

      fallback.dispose();
    });

    test('resets health status correctly', () async {
      final transport1 = MockTransport('transport1', shouldFail: true);
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport(
        [
          FallbackTransportConfig(transport: transport1),
          FallbackTransportConfig(transport: transport2),
        ],
        options: FallbackTransportOptions(failureThreshold: 1, retryCount: 0),
      );

      // Make transport1 unhealthy
      await fallback.request('eth_blockNumber', []);
      expect(fallback.getHealthStatus()[0].isHealthy, isFalse);

      // Reset health
      fallback.resetHealth();
      expect(fallback.getHealthStatus()[0].isHealthy, isTrue);
      expect(fallback.getHealthStatus()[0].failureCount, equals(0));

      fallback.dispose();
    });

    test('manually marking transport as unhealthy works', () async {
      final transport1 = MockTransport('transport1');
      final transport2 = MockTransport('transport2');

      final fallback = FallbackTransport([
        FallbackTransportConfig(transport: transport1),
        FallbackTransportConfig(transport: transport2),
      ]);

      // Initially healthy
      expect(fallback.getHealthStatus()[0].isHealthy, isTrue);

      // Manually mark as unhealthy
      fallback.markUnhealthy(0);
      expect(fallback.getHealthStatus()[0].isHealthy, isFalse);

      fallback.dispose();
    });
  });
}
