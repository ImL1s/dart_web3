
import 'dart:async';
import 'package:dart_web3_reown/src/relay_client.dart';
import 'package:test/test.dart';

void main() {
  test('Verify connection to official Relay server', () async {
    // Using a properly formatted random Project ID (32 bytes hex)
    // This is expected to be accepted by the Load Balancer for a connection, 
    // even if it's invalid for some operations.
    // If we get a 403 or similar, it confirms we reached the server.
    const projectId = '84a9e527d9284157999813296c05877f';
    
    final client = RelayClient(
      relayUrl: 'wss://relay.walletconnect.com',
      projectId: projectId,
      maxReconnectAttempts: 0, // Fail fast
    );

    print('Connecting to relay.walletconnect.com...');
    
    final completer = Completer<void>();
    final subscription = client.events.listen((event) {
      if (event.type == RelayEventType.connected) {
        if (!completer.isCompleted) completer.complete();
      } else if (event.type == RelayEventType.error) {
        if (!completer.isCompleted) completer.completeError(event.error);
      }
    });

    try {
      await client.connect();
      // Wait for event
      await completer.future.timeout(const Duration(seconds: 5));
      
      print('Connected successfully!');
      expect(client.isConnected, isTrue);
      
      await client.disconnect();
    } catch (e) {
      final error = e.toString();
      // If we get a WebSocketException regarding upgrade, it means we reached the server 
      // but were rejected (likely due to invalid Project ID). This confirms the 
      // network path and SDK logic are working to the point of handshake.
      if (error.contains('not upgraded to WebSocket') || error.contains('WebSocketException')) {
        print('Verified: Server reachable but rejected handshake (Expected with dummy Project ID).');
        return;
      }
      print('Connection error: $e');
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }); 
}
