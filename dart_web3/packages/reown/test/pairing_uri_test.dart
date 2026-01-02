import 'package:dart_web3_reown/dart_web3_reown.dart';
import 'package:test/test.dart';

void main() {
  group('PairingUri', () {
    test('should generate valid pairing URI', () {
      final uri = PairingUri.generate();
      
      expect(uri.topic, hasLength(64)); // 32 bytes hex = 64 chars
      expect(uri.symKey, hasLength(64)); // 32 bytes hex = 64 chars
      expect(uri.relay, equals('wss://relay.walletconnect.com'));
      expect(uri.expiryTimestamp, isNull);
    });

    test('should generate pairing URI with expiry', () {
      final expiry = Duration(minutes: 5);
      final uri = PairingUri.generate(expiry: expiry);
      
      expect(uri.expiryTimestamp, isNotNull);
      expect(uri.timeUntilExpiry, isNotNull);
      expect(uri.timeUntilExpiry!.inMinutes, lessThanOrEqualTo(5));
    });

    test('should convert to URI string format', () {
      final uri = PairingUri(
        topic: 'a' * 64,
        symKey: 'b' * 64,
        relay: 'wss://relay.walletconnect.com',
      );
      
      final uriString = uri.toUri();
      
      expect(uriString, startsWith('wc:'));
      expect(uriString, contains('@2?'));
      expect(uriString, contains('relay-protocol='));
      expect(uriString, contains('symKey='));
    });

    test('should parse URI string correctly', () {
      final originalUri = PairingUri.generate();
      final uriString = originalUri.toUri();
      final parsedUri = PairingUri.parse(uriString);
      
      expect(parsedUri.topic, equals(originalUri.topic));
      expect(parsedUri.symKey, equals(originalUri.symKey));
      expect(parsedUri.relay, equals(originalUri.relay));
    });

    test('should throw on invalid URI format', () {
      expect(() => PairingUri.parse('invalid'), throwsArgumentError);
      expect(() => PairingUri.parse('wc:topic'), throwsArgumentError);
      expect(() => PairingUri.parse('wc:topic@1?params'), throwsArgumentError);
    });

    test('should detect expired URIs', () {
      final expiredUri = PairingUri(
        topic: 'topic',
        symKey: 'symkey',
        relay: 'relay',
        expiryTimestamp: DateTime.now().subtract(Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
      );
      
      expect(expiredUri.isExpired, isTrue);
      expect(expiredUri.timeUntilExpiry, equals(Duration.zero));
    });

    test('should handle URIs without expiry', () {
      final uri = PairingUri(
        topic: 'topic',
        symKey: 'symkey',
        relay: 'relay',
      );
      
      expect(uri.isExpired, isFalse);
      expect(uri.timeUntilExpiry, isNull);
    });
  });
}
