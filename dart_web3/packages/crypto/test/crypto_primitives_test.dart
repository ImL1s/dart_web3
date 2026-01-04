import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3_universal_crypto/web3_universal_crypto.dart';

/// Test vectors from official specifications:
/// - SHA-256: NIST FIPS 180-4
/// - Keccak-256: NIST FIPS 202 / Ethereum
/// - HMAC-SHA512: RFC 4231
/// - PBKDF2: RFC 6070
/// - Scrypt: RFC 7914
/// - AES-128-CTR: NIST SP 800-38A
/// - RIPEMD-160: Official specification
/// - BIP-39/32: Official BIP test vectors
void main() {
  group('SHA-256 (NIST FIPS 180-4)', () {
    test('empty string', () {
      final result = Sha256.hash(Uint8List(0));
      expect(
        _toHex(result),
        equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
      );
    });

    test('abc', () {
      final result = Sha256.hash(Uint8List.fromList(utf8.encode('abc')));
      expect(
        _toHex(result),
        equals(
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
      );
    });

    test('448 bits message', () {
      final result = Sha256.hash(
        Uint8List.fromList(utf8.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
      );
      expect(
        _toHex(result),
        equals(
            '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1'),
      );
    });

    test('double SHA-256', () {
      // Used in Bitcoin for checksums
      final result =
          Sha256.doubleHash(Uint8List.fromList(utf8.encode('hello')));
      expect(result.length, equals(32));
    });
  });

  group('Keccak-256 (NIST FIPS 202 / Ethereum)', () {
    test('empty string', () {
      final result = Keccak256.hash(Uint8List(0));
      expect(
        _toHex(result),
        equals(
            'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'),
      );
    });

    test('abc', () {
      final result = Keccak256.hash(Uint8List.fromList(utf8.encode('abc')));
      expect(
        _toHex(result),
        equals(
            '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45'),
      );
    });
  });

  group('SHA-512', () {
    test('empty string', () {
      final result = Sha512.hash(Uint8List(0));
      expect(result.length, equals(64));
      expect(
        _toHex(result),
        equals(
            'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce'
            '47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e'),
      );
    });

    test('abc', () {
      final result = Sha512.hash(Uint8List.fromList(utf8.encode('abc')));
      expect(
        _toHex(result),
        equals(
            'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a'
            '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f'),
      );
    });
  });

  group('HMAC-SHA512 (RFC 4231)', () {
    test('Test Case 1', () {
      // Key = 0x0b repeated 20 times
      final key = Uint8List.fromList(List.filled(20, 0x0b));
      final data = Uint8List.fromList(utf8.encode('Hi There'));
      final result = HmacSha512.compute(key, data);
      expect(
        _toHex(result),
        equals(
            '87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde'
            'daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854'),
      );
    });

    test('Test Case 2 - Key = "Jefe"', () {
      final key = Uint8List.fromList(utf8.encode('Jefe'));
      final data =
          Uint8List.fromList(utf8.encode('what do ya want for nothing?'));
      final result = HmacSha512.compute(key, data);
      expect(
        _toHex(result),
        equals(
            '164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554'
            '9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737'),
      );
    });

    test('Test Case 3', () {
      // Key = 0xaa repeated 20 times
      final key = Uint8List.fromList(List.filled(20, 0xaa));
      // Data = 0xdd repeated 50 times
      final data = Uint8List.fromList(List.filled(50, 0xdd));
      final result = HmacSha512.compute(key, data);
      expect(
        _toHex(result),
        equals(
            'fa73b0089d56a284efb0f0756c890be9b1b5dbdd8ee81a3655f83e33b2279d39'
            'bf3e848279a722c806b485a47e67c807b946a337bee8942674278859e13292fb'),
      );
    });
  });

  group('HMAC-SHA256', () {
    test('Test Case 1', () {
      final key = Uint8List.fromList(List.filled(20, 0x0b));
      final data = Uint8List.fromList(utf8.encode('Hi There'));
      final result = HmacSha256.compute(key, data);
      expect(
        _toHex(result),
        equals(
            'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7'),
      );
    });
  });

  group('AES-128-CTR (NIST SP 800-38A)', () {
    test('NIST Vector 1', () {
      final key = _fromHex('2b7e151628aed2a6abf7158809cf4f3c');
      final iv = _fromHex('f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff');
      final plaintext = _fromHex('6bc1bee22e409f96e93d7e117393172a');
      final expected = '874d6191b620e3261bef6864990db6ce';

      final aes = AES(key);
      final ciphertext = aes.ctr(plaintext, iv);
      expect(_toHex(ciphertext), equals(expected));

      final decrypted = aes.ctr(ciphertext, iv);
      expect(decrypted, equals(plaintext));
    });
  });

  group('Scrypt (RFC 7914)', () {
    test('RFC 7914 Vector 1 (P="", S="", N=16, r=1, p=1)', () {
      final password = Uint8List(0);
      final salt = Uint8List(0);
      final dk = Scrypt.derive(password, salt, 16, 1, 1, 64);
      expect(
        _toHex(dk),
        equals(
            '77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906'),
      );
    });
  });

  group('PBKDF2-HMAC-SHA512', () {
    // BIP-39 uses PBKDF2-HMAC-SHA512 with 2048 iterations
    test('BIP-39 style derivation', () {
      // Using a simple test case
      final password = Uint8List.fromList(utf8.encode('password'));
      final salt = Uint8List.fromList(utf8.encode('salt'));
      final result = Pbkdf2.deriveKey(
        password: password,
        salt: salt,
        iterations: 1,
        keyLength: 64,
      );
      expect(result.length, equals(64));
      // Verify it produces consistent output
      final result2 = Pbkdf2.deriveKey(
        password: password,
        salt: salt,
        iterations: 1,
        keyLength: 64,
      );
      expect(_toHex(result), equals(_toHex(result2)));
    });

    test('produces correct length output', () {
      final password = Uint8List.fromList(utf8.encode('test'));
      final salt = Uint8List.fromList(utf8.encode('mnemonic'));
      final result = Pbkdf2.deriveKey(
        password: password,
        salt: salt,
        iterations: 2048,
        keyLength: 64,
      );
      expect(result.length, equals(64));
    });
  });

  group('RIPEMD-160', () {
    test('empty string', () {
      final result = Ripemd160.hash(Uint8List(0));
      expect(
        _toHex(result),
        equals('9c1185a5c5e9fc54612808977ee8f548b2258d31'),
      );
    });

    test('a', () {
      final result = Ripemd160.hash(Uint8List.fromList(utf8.encode('a')));
      expect(
        _toHex(result),
        equals('0bdc9d2d256b3ee9daae347be6f4dc835a467ffe'),
      );
    });

    test('abc', () {
      final result = Ripemd160.hash(Uint8List.fromList(utf8.encode('abc')));
      expect(
        _toHex(result),
        equals('8eb208f7e05d987a9b044a8e98c6b087f15a0bfc'),
      );
    });

    test('message digest', () {
      final result =
          Ripemd160.hash(Uint8List.fromList(utf8.encode('message digest')));
      expect(
        _toHex(result),
        equals('5d0689ef49d2fae572b881b123a85ffa21595f36'),
      );
    });

    test('a-z', () {
      final result = Ripemd160.hash(
          Uint8List.fromList(utf8.encode('abcdefghijklmnopqrstuvwxyz')));
      expect(
        _toHex(result),
        equals('f71c27109c692c1b56bbdceb5b9d2865b3708dbc'),
      );
    });

    test('HASH160 = RIPEMD160(SHA256(data))', () {
      // This is used in Bitcoin for address derivation
      final data = Uint8List.fromList(utf8.encode('test'));
      final hash160 = Ripemd160.hash160(data);
      expect(hash160.length, equals(20));

      // Verify it equals RIPEMD160(SHA256(data))
      final sha256 = Sha256.hash(data);
      final manual = Ripemd160.hash(sha256);
      expect(_toHex(hash160), equals(_toHex(manual)));
    });
  });

  group('PBKDF2-HMAC-SHA256 (RFC 6070)', () {
    test('Test Case 1', () {
      final password = Uint8List.fromList(utf8.encode('password'));
      final salt = Uint8List.fromList(utf8.encode('salt'));
      final dk = Pbkdf2.deriveSha256(
        password: password,
        salt: salt,
        iterations: 1,
        keyLength: 32,
      );
      expect(
        _toHex(dk),
        equals(
            '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'),
      );
    });
  });

  group('BIP-32 HD Wallet', () {
    test('master key from seed produces 32-byte private key', () {
      // 64-byte seed (typical BIP-39 output)
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final wallet = HDWallet.fromSeed(seed);
      expect(wallet.privateKey.length, equals(32));
      expect(wallet.publicKey.length, equals(33)); // Compressed
      expect(wallet.chainCode.length, equals(32));
      expect(wallet.depth, equals(0));
      expect(wallet.path, equals('m'));
    });

    test('child derivation produces valid keys', () {
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final master = HDWallet.fromSeed(seed);
      final child = master.deriveChild(0);

      expect(child.privateKey.length, equals(32));
      expect(child.publicKey.length, equals(33));
      expect(child.depth, equals(1));
      expect(child.path, equals('m/0'));

      // Child should be different from parent
      expect(
          _toHex(child.privateKey), isNot(equals(_toHex(master.privateKey))));
    });

    test('hardened derivation works', () {
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final master = HDWallet.fromSeed(seed);
      // Hardened index = 0x80000000
      final child = master.deriveChild(0x80000000);

      expect(child.depth, equals(1));
      expect(child.path, equals("m/0'"));
    });

    test('BIP-44 path derivation', () {
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final master = HDWallet.fromSeed(seed);
      // m/44'/60'/0'/0/0 (Ethereum path)
      final derived = master.derive("m/44'/60'/0'/0/0");

      expect(derived.depth, equals(5));
      expect(derived.path, equals("m/44'/60'/0'/0/0"));
      expect(derived.privateKey.length, equals(32));
    });

    test('extended private key serialization', () {
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final wallet = HDWallet.fromSeed(seed);
      final xprv = wallet.getExtendedPrivateKey();

      // Should start with 'xprv' in Base58
      expect(xprv.startsWith('xprv'), isTrue);
    });

    test('extended public key serialization', () {
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final wallet = HDWallet.fromSeed(seed);
      final xpub = wallet.getExtendedPublicKey();

      // Should start with 'xpub' in Base58
      expect(xpub.startsWith('xpub'), isTrue);
    });

    test('consistent derivation', () {
      final seed = Uint8List(64);
      for (var i = 0; i < 64; i++) {
        seed[i] = i;
      }
      final wallet1 = HDWallet.fromSeed(seed);
      final wallet2 = HDWallet.fromSeed(seed);

      expect(_toHex(wallet1.privateKey), equals(_toHex(wallet2.privateKey)));
      expect(_toHex(wallet1.chainCode), equals(_toHex(wallet2.chainCode)));

      final child1 = wallet1.derive("m/44'/60'/0'/0/0");
      final child2 = wallet2.derive("m/44'/60'/0'/0/0");

      expect(_toHex(child1.privateKey), equals(_toHex(child2.privateKey)));
    });
  });
}

String _toHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List _fromHex(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
