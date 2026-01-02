import 'package:dart_web3_reown/dart_web3_reown.dart';
import 'package:test/test.dart';

void main() {
  group('SiweMessage', () {
    test('should create SIWE message correctly', () {
      final message = SiweMessage(
        domain: 'example.com',
        address: '0x1234567890123456789012345678901234567890',
        statement: 'Sign in to the application',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'randomnonce',
        issuedAt: DateTime.parse('2023-01-01T00:00:00Z'),
      );
      
      expect(message.domain, equals('example.com'));
      expect(message.address, equals('0x1234567890123456789012345678901234567890'));
      expect(message.statement, equals('Sign in to the application'));
      expect(message.chainId, equals(1));
    });

    test('should convert to message string format', () {
      final message = SiweMessage(
        domain: 'example.com',
        address: '0x1234567890123456789012345678901234567890',
        statement: 'Sign in to the application',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'randomnonce',
        issuedAt: DateTime.parse('2023-01-01T00:00:00Z'),
      );
      
      final messageString = message.toMessage();
      
      expect(messageString, contains('example.com wants you to sign in'));
      expect(messageString, contains('0x1234567890123456789012345678901234567890'));
      expect(messageString, contains('Sign in to the application'));
      expect(messageString, contains('URI: https://example.com'));
      expect(messageString, contains('Version: 1'));
      expect(messageString, contains('Chain ID: 1'));
      expect(messageString, contains('Nonce: randomnonce'));
    });

    test('should parse message string correctly', () {
      final messageString = '''
example.com wants you to sign in with your Ethereum account:
0x1234567890123456789012345678901234567890

Sign in to the application

URI: https://example.com
Version: 1
Chain ID: 1
Nonce: randomnonce
Issued At: 2023-01-01T00:00:00.000Z''';
      
      final message = SiweMessage.parse(messageString);
      
      expect(message.domain, equals('example.com'));
      expect(message.address, equals('0x1234567890123456789012345678901234567890'));
      expect(message.statement, equals('Sign in to the application'));
      expect(message.uri, equals('https://example.com'));
      expect(message.version, equals('1'));
      expect(message.chainId, equals(1));
      expect(message.nonce, equals('randomnonce'));
    });

    test('should convert to and from JSON', () {
      final message = SiweMessage(
        domain: 'example.com',
        address: '0x1234567890123456789012345678901234567890',
        statement: 'Sign in to the application',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'randomnonce',
        issuedAt: DateTime.parse('2023-01-01T00:00:00Z'),
      );
      
      final json = message.toJson();
      final restored = SiweMessage.fromJson(json);
      
      expect(restored.domain, equals(message.domain));
      expect(restored.address, equals(message.address));
      expect(restored.statement, equals(message.statement));
      expect(restored.chainId, equals(message.chainId));
      expect(restored.nonce, equals(message.nonce));
    });

    test('should validate message timing correctly', () {
      final now = DateTime.now();
      
      // Valid message
      final validMessage = SiweMessage(
        domain: 'example.com',
        address: '0x123',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'nonce',
        issuedAt: now,
        expirationTime: now.add(Duration(hours: 1)),
      );
      
      expect(validMessage.isValid, isTrue);
      
      // Expired message
      final expiredMessage = SiweMessage(
        domain: 'example.com',
        address: '0x123',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'nonce',
        issuedAt: now,
        expirationTime: now.subtract(Duration(hours: 1)),
      );
      
      expect(expiredMessage.isValid, isFalse);
      
      // Not yet valid message
      final futureMessage = SiweMessage(
        domain: 'example.com',
        address: '0x123',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'nonce',
        issuedAt: now,
        notBefore: now.add(Duration(hours: 1)),
      );
      
      expect(futureMessage.isValid, isFalse);
    });

    test('should handle message without statement', () {
      final messageString = '''
example.com wants you to sign in with your Ethereum account:
0x1234567890123456789012345678901234567890

URI: https://example.com
Version: 1
Chain ID: 1
Nonce: randomnonce
Issued At: 2023-01-01T00:00:00.000Z''';
      
      final message = SiweMessage.parse(messageString);
      
      expect(message.domain, equals('example.com'));
      expect(message.statement, isNull);
    });

    test('should throw on invalid message format', () {
      expect(() => SiweMessage.parse('invalid message'), throwsArgumentError);
      expect(() => SiweMessage.parse('not a siwe message\nformat'), throwsArgumentError);
    });
  });

  group('SiweConfig', () {
    test('should create default config', () {
      final config = SiweConfig.defaultConfig();
      
      expect(config.domain, equals('localhost:3000'));
      expect(config.uri, equals('http://localhost:3000'));
      expect(config.chainId, equals(1));
      expect(config.expirationTime, isNotNull);
    });

    test('should create custom config', () {
      final config = SiweConfig(
        domain: 'myapp.com',
        statement: 'Custom statement',
        uri: 'https://myapp.com',
        chainId: 137,
        expirationTime: Duration(hours: 12),
      );
      
      expect(config.domain, equals('myapp.com'));
      expect(config.statement, equals('Custom statement'));
      expect(config.chainId, equals(137));
      expect(config.expirationTime, equals(Duration(hours: 12)));
    });
  });

  group('SiweAuthResult', () {
    test('should create auth result correctly', () {
      final siweMessage = SiweMessage(
        domain: 'example.com',
        address: '0x123',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'nonce',
        issuedAt: DateTime.now(),
      );
      
      final result = SiweAuthResult(
        siweMessage: siweMessage,
        signature: '0xsignature',
        isAuthenticated: true,
      );
      
      expect(result.siweMessage, equals(siweMessage));
      expect(result.signature, equals('0xsignature'));
      expect(result.isAuthenticated, isTrue);
      expect(result.isComplete, isTrue);
    });

    test('should determine completion status', () {
      final siweMessage = SiweMessage(
        domain: 'example.com',
        address: '0x123',
        uri: 'https://example.com',
        version: '1',
        chainId: 1,
        nonce: 'nonce',
        issuedAt: DateTime.now(),
      );
      
      // Incomplete result
      final incompleteResult = SiweAuthResult(
        siweMessage: siweMessage,
      );
      
      expect(incompleteResult.isComplete, isFalse);
      
      // Complete result
      final completeResult = SiweAuthResult(
        siweMessage: siweMessage,
        signature: '0xsignature',
        isAuthenticated: true,
      );
      
      expect(completeResult.isComplete, isTrue);
    });
  });
}
