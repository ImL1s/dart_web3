import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

void main() {
  group('Secp256k1', () {
    // Test private key (32 bytes)
    final testPrivateKey = HexUtils.decode(
      '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
    );

    group('getPublicKey', () {
      test('derives public key from private key', () {
        final publicKey = Secp256k1.getPublicKey(testPrivateKey);
        // Uncompressed public key: 0x04 + 32 bytes x + 32 bytes y = 65 bytes
        expect(publicKey.length, equals(65));
        expect(publicKey[0], equals(0x04)); // Uncompressed prefix
      });

      test('derives compressed public key', () {
        final publicKey =
            Secp256k1.getPublicKey(testPrivateKey, compressed: true);
        // Compressed public key: 0x02 or 0x03 + 32 bytes x = 33 bytes
        expect(publicKey.length, equals(33));
        expect(publicKey[0], anyOf(equals(0x02), equals(0x03)));
      });

      test('throws on invalid private key length', () {
        expect(
          () => Secp256k1.getPublicKey(Uint8List(31)),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => Secp256k1.getPublicKey(Uint8List(33)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on zero private key', () {
        expect(
          () => Secp256k1.getPublicKey(Uint8List(32)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('produces consistent public key', () {
        final pk1 = Secp256k1.getPublicKey(testPrivateKey);
        final pk2 = Secp256k1.getPublicKey(testPrivateKey);
        expect(pk1, equals(pk2));
      });

      test('produces different public keys for different private keys', () {
        final pk1 = Secp256k1.getPublicKey(testPrivateKey);

        final otherPrivateKey = HexUtils.decode(
          '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',
        );
        final pk2 = Secp256k1.getPublicKey(otherPrivateKey);

        expect(pk1, isNot(equals(pk2)));
      });
    });

    group('sign', () {
      test('signs a message hash', () {
        final messageHash =
            Keccak256.hash(Uint8List.fromList('hello'.codeUnits));
        final signature = Secp256k1.sign(messageHash, testPrivateKey);
        expect(signature.length, equals(65));
      });

      test('throws on invalid message hash length', () {
        expect(
          () => Secp256k1.sign(Uint8List(31), testPrivateKey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on invalid private key length', () {
        final messageHash = Uint8List(32);
        expect(
          () => Secp256k1.sign(messageHash, Uint8List(31)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('produces different signatures for different messages', () {
        final hash1 = Keccak256.hash(Uint8List.fromList('message1'.codeUnits));
        final hash2 = Keccak256.hash(Uint8List.fromList('message2'.codeUnits));

        final sig1 = Secp256k1.sign(hash1, testPrivateKey);
        final sig2 = Secp256k1.sign(hash2, testPrivateKey);

        // r and s should be different
        expect(sig1, isNot(equals(sig2)));
      });
    });

    group('recover', () {
      test('recover recovers public key from signature with correct v', () {
        final messageHash =
            Keccak256.hash(Uint8List.fromList('hello'.codeUnits));
        final signature = Secp256k1.sign(messageHash, testPrivateKey);
        final rAndS = signature.sublist(0, 64);
        final v = signature[64];
        final expectedPubKey = Secp256k1.getPublicKey(testPrivateKey);

        final recoveredPubKey = Secp256k1.recover(rAndS, messageHash, v);
        expect(_uint8ListEquals(recoveredPubKey, expectedPubKey), isTrue);
      });

      test('throws on invalid signature length', () {
        expect(
          () => Secp256k1.recover(Uint8List(63), Uint8List(32), 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on invalid message hash length', () {
        expect(
          () => Secp256k1.recover(Uint8List(64), Uint8List(31), 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on invalid v value', () {
        expect(
          () => Secp256k1.recover(Uint8List(64), Uint8List(32), 4),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => Secp256k1.recover(Uint8List(64), Uint8List(32), -1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('verify', () {
      test('verifies valid signature', () {
        final messageHash =
            Keccak256.hash(Uint8List.fromList('hello'.codeUnits));
        final publicKey = Secp256k1.getPublicKey(testPrivateKey);
        final signature = Secp256k1.sign(messageHash, testPrivateKey);
        final rAndS = signature.sublist(0, 64);
        expect(Secp256k1.verify(rAndS, messageHash, publicKey), isTrue);
      });

      test('rejects signature with wrong message', () {
        final messageHash1 =
            Keccak256.hash(Uint8List.fromList('hello'.codeUnits));
        final messageHash2 =
            Keccak256.hash(Uint8List.fromList('world'.codeUnits));
        final publicKey = Secp256k1.getPublicKey(testPrivateKey);
        final signature = Secp256k1.sign(messageHash1, testPrivateKey);

        expect(Secp256k1.verify(signature, messageHash2, publicKey), isFalse);
      });

      test('verifies valid signature with wrong public key', () {
        final messageHash =
            Keccak256.hash(Uint8List.fromList('hello'.codeUnits));
        final signature = Secp256k1.sign(messageHash, testPrivateKey);
        final rAndS = signature.sublist(0, 64);
        final otherPrivateKey = Uint8List(32)..fillRange(0, 32, 1); // Mock key
        final wrongPublicKey = Secp256k1.getPublicKey(otherPrivateKey);

        expect(Secp256k1.verify(rAndS, messageHash, wrongPublicKey), isFalse);
      });
    });

    group('sign-verify round trip', () {
      test('sign then verify returns true', () {
        final messages = [
          'hello',
          'world',
          'ethereum',
          'test message with spaces',
          '0x1234567890abcdef',
        ];

        final publicKey = Secp256k1.getPublicKey(testPrivateKey);

        for (final message in messages) {
          final messageHash =
              Keccak256.hash(Uint8List.fromList(message.codeUnits));
          final signature = Secp256k1.sign(messageHash, testPrivateKey);
          final rAndS = signature.sublist(0, 64);

          expect(
            Secp256k1.verify(rAndS, messageHash, publicKey),
            isTrue,
            reason: 'Failed for message: $message',
          );
        }
      });
    });
  });
}

bool _uint8ListEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
