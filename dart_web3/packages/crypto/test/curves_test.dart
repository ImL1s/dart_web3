import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

void main() {
  group('CurveInterface', () {
    group('Ed25519', () {
      final ed25519 = Ed25519();

      test('metadata is correct', () {
        expect(ed25519.curveName, equals('Ed25519'));
        expect(ed25519.privateKeyLength, equals(32));
        expect(ed25519.publicKeyLength, equals(32));
        expect(ed25519.signatureLength, equals(64));
      });

      test('sign and verify round trip', () {
        final keyPair = Ed25519.generateKeyPair();
        final messageHash = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          messageHash[i] = i;
        }

        final signature = keyPair.sign(messageHash);
        expect(signature.length, equals(64));

        final isValid = keyPair.verify(signature, messageHash);
        expect(isValid, isTrue);
      });

      test('verify fails with wrong message', () {
        final keyPair = Ed25519.generateKeyPair();
        final messageHash1 = Uint8List(32);
        final messageHash2 = Uint8List(32);
        messageHash2[0] = 1;

        final signature = keyPair.sign(messageHash1);
        final isValid = keyPair.verify(signature, messageHash2);

        // Note: With the simplified implementation, this might pass if not careful
        // but let's test the interface contract
        // In a real implementation this MUST be false
        // For the simplified version, we just check it runs without error
        expect(isValid, isFalse);
      });
    });

    group('Sr25519', () {
      final sr25519 = Sr25519();

      test('metadata is correct', () {
        expect(sr25519.curveName, equals('Sr25519'));
        expect(sr25519.privateKeyLength, equals(32));
        expect(sr25519.publicKeyLength, equals(32));
        expect(sr25519.signatureLength, equals(64));
      });

      test('sign and verify round trip', () {
        final keyPair = Sr25519.generateKeyPair();
        final messageHash = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          messageHash[i] = i;
        }

        final signature = keyPair.sign(messageHash);
        expect(signature.length, equals(64));

        final isValid = keyPair.verify(signature, messageHash);
        expect(isValid, isTrue);
      });
    });

    group('CurveFactory', () {
      test('creates Ed25519', () {
        final curve = CurveFactory.createCurve('Ed25519');
        expect(curve, isA<Ed25519>());
      });

      test('creates Sr25519', () {
        final curve = CurveFactory.createCurve('Sr25519');
        expect(curve, isA<Sr25519>());
      });

      test('throws on unknown curve', () {
        expect(() => CurveFactory.createCurve('unknown'),
            throwsA(isA<ArgumentError>()));
      });
    });
  });
}
