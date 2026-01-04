import 'package:test/test.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'dart:typed_data';

void main() {
  group('KeystoreV3', () {
    final password = 'testpassword';
    final privateKey = Uint8List.fromList(List.generate(32, (i) => i));

    test('Encrypt and decrypt (Scrypt)', () async {
      // Use low n, r, p for fast testing
      final keystore =
          KeystoreV3.encrypt(privateKey, password, n: 1024, r: 8, p: 1);

      expect(keystore['version'], 3);
      expect(keystore['crypto']['kdf'], 'scrypt');

      final decrypted = KeystoreV3.decrypt(keystore, password);
      expect(decrypted, privateKey);
    });

    test('Encrypt and decrypt (PBKDF2)', () {
      final keystore =
          KeystoreV3.encrypt(privateKey, password, useScrypt: false);

      expect(keystore['version'], 3);
      expect(keystore['crypto']['kdf'], 'pbkdf2');

      final decrypted = KeystoreV3.decrypt(keystore, password);
      expect(decrypted, privateKey);
    });

    test('Decrypt with wrong password fails', () {
      final keystore =
          KeystoreV3.encrypt(privateKey, password, n: 1024, r: 8, p: 1);

      expect(() => KeystoreV3.decrypt(keystore, 'wrongpassword'),
          throwsA(isA<StateError>()));
    });

    group('Official Ethereum KeyStoreTests', () {
      test('Test 1 (PBKDF2)', () {
        final json = {
          "crypto": {
            "cipher": "aes-128-ctr",
            "cipherparams": {"iv": "6087dab2f9fdbbfaddc31a909735c1e6"},
            "ciphertext":
                "5318b4d5bcd28de64ee5559e671353e16f075ecae9f99c7a79a38af5f869aa46",
            "kdf": "pbkdf2",
            "kdfparams": {
              "c": 262144,
              "dklen": 32,
              "prf": "hmac-sha256",
              "salt":
                  "ae3cd4e7013836a3df6bd7241b12db061dbe2c6785853cce422d148a624ce0bd"
            },
            "mac":
                "517ead924a9d0dc3124507e3393d175ce3ff7c1e96529c6c555ce9e51205e9b2"
          },
          "id": "3198bc9c-6672-5ab3-d995-4942343ae5b6",
          "version": 3
        };
        final expectedPriv =
            "7a28b5ba57c53603b0b07b56bba752f7784bf506fa95edc395f5cf6c7514fe9d";

        final decrypted = KeystoreV3.decrypt(json, 'testpassword');
        expect(_toHex(decrypted), equals(expectedPriv));
      });

      test('Test 2 (Scrypt)', () {
        final json = {
          "crypto": {
            "cipher": "aes-128-ctr",
            "cipherparams": {"iv": "83dbcc02d8ccb40e466191a123791e0e"},
            "ciphertext":
                "d172bf743a674da9cdad04534d56926ef8358534d458fffccd4e6ad2fbde479c",
            "kdf": "scrypt",
            "kdfparams": {
              "dklen": 32,
              "n": 262144,
              "r": 1,
              "p": 8,
              "salt":
                  "ab0c7876052600dd703518d6fc3fe8984592145b591fc8fb5c6d43190334ba19"
            },
            "mac":
                "2103ac29920d71da29f15d75b4a16dbe95cfd7ff8faea1056c33131d846e3097"
          },
          "id": "3198bc9c-6672-5ab3-d995-4942343ae5b6",
          "version": 3
        };
        final expectedPriv =
            "7a28b5ba57c53603b0b07b56bba752f7784bf506fa95edc395f5cf6c7514fe9d";

        final decrypted = KeystoreV3.decrypt(json, 'testpassword');
        expect(_toHex(decrypted), equals(expectedPriv));
      });
    });
  });
}

String _toHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
}
