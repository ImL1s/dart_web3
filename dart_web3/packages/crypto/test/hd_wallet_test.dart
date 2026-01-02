import 'dart:typed_data';

import 'package:dart_web3_crypto/dart_web3_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('HDWallet', () {
    group('fromSeed', () {
      test('creates wallet from 64-byte seed', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }

        final wallet = HDWallet.fromSeed(seed);
        expect(wallet.privateKey.length, equals(32));
        // Compressed public key is 33 bytes
        expect(wallet.publicKey.length, equals(33));
        expect(wallet.chainCode.length, equals(32));
        expect(wallet.depth, equals(0));
        expect(wallet.path, equals('m'));
      });

      test('creates wallet from 32-byte seed', () {
        final seed = Uint8List(32);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i + 1; // Non-zero seed
        }
        final wallet = HDWallet.fromSeed(seed);
        expect(wallet.privateKey.length, equals(32));
      });

      test('throws on seed too short', () {
        expect(() => HDWallet.fromSeed(Uint8List(15)), throwsA(isA<ArgumentError>()));
      });

      test('throws on seed too long', () {
        expect(() => HDWallet.fromSeed(Uint8List(65)), throwsA(isA<ArgumentError>()));
      });

      test('produces consistent wallet from same seed', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }

        final wallet1 = HDWallet.fromSeed(seed);
        final wallet2 = HDWallet.fromSeed(seed);

        expect(wallet1.privateKey, equals(wallet2.privateKey));
        expect(wallet1.publicKey, equals(wallet2.publicKey));
        expect(wallet1.chainCode, equals(wallet2.chainCode));
      });
    });

    group('derive', () {
      late Uint8List testSeed;
      
      setUp(() {
        testSeed = Uint8List(64);
        for (var i = 0; i < testSeed.length; i++) {
          testSeed[i] = i;
        }
      });

      test('derives child at path', () {
        final master = HDWallet.fromSeed(testSeed);

        final child = master.derive("m/44'/60'/0'/0/0");
        expect(child.depth, equals(5));
        expect(child.path, equals("m/44'/60'/0'/0/0"));
      });

      test('throws on invalid path', () {
        final master = HDWallet.fromSeed(testSeed);

        expect(() => master.derive('44/60/0'), throwsA(isA<ArgumentError>()));
      });

      test('produces consistent derivation', () {
        final master = HDWallet.fromSeed(testSeed);

        final child1 = master.derive("m/44'/60'/0'/0/0");
        final child2 = master.derive("m/44'/60'/0'/0/0");

        expect(child1.privateKey, equals(child2.privateKey));
      });

      test('produces different keys for different paths', () {
        final master = HDWallet.fromSeed(testSeed);

        final child1 = master.derive("m/44'/60'/0'/0/0");
        final child2 = master.derive("m/44'/60'/0'/0/1");

        expect(child1.privateKey, isNot(equals(child2.privateKey)));
      });
    });

    group('deriveChild', () {
      late Uint8List testSeed;
      
      setUp(() {
        testSeed = Uint8List(64);
        for (var i = 0; i < testSeed.length; i++) {
          testSeed[i] = i;
        }
      });

      test('derives normal child', () {
        final master = HDWallet.fromSeed(testSeed);

        final child = master.deriveChild(0);
        expect(child.depth, equals(1));
        expect(child.path, equals('m/0'));
      });

      test('derives hardened child using index >= 2^31', () {
        final master = HDWallet.fromSeed(testSeed);

        // Hardened derivation uses index >= 2^31
        final hardenedIndex = 0x80000000; // 2^31
        final child = master.deriveChild(hardenedIndex);
        expect(child.depth, equals(1));
        expect(child.path, equals("m/0'"));
      });

      test('throws on negative index', () {
        final master = HDWallet.fromSeed(testSeed);

        expect(() => master.deriveChild(-1), throwsA(isA<ArgumentError>()));
      });
    });

    group('getAddress', () {
      test('returns valid Ethereum address', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }
        final wallet = HDWallet.fromSeed(seed);

        final address = wallet.getAddress();
        expect(address.bytes.length, equals(20));
      });

      test('returns consistent address', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }
        final wallet = HDWallet.fromSeed(seed);

        final addr1 = wallet.getAddress();
        final addr2 = wallet.getAddress();

        expect(addr1.hex, equals(addr2.hex));
      });
    });

    group('getPrivateKey', () {
      test('returns 32-byte private key', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }
        final wallet = HDWallet.fromSeed(seed);

        final pk = wallet.getPrivateKey();
        expect(pk.length, equals(32));
      });

      test('returns copy of private key', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }
        final wallet = HDWallet.fromSeed(seed);

        final pk1 = wallet.getPrivateKey();
        final pk2 = wallet.getPrivateKey();

        expect(pk1, equals(pk2));
        expect(identical(pk1, pk2), isFalse);
      });
    });

    group('derivation consistency', () {
      test('same seed produces same derived addresses', () {
        final seed = Uint8List(64);
        for (var i = 0; i < seed.length; i++) {
          seed[i] = i;
        }

        final wallet1 = HDWallet.fromSeed(seed).derive("m/44'/60'/0'/0/0");
        final wallet2 = HDWallet.fromSeed(seed).derive("m/44'/60'/0'/0/0");

        expect(wallet1.getAddress().hex, equals(wallet2.getAddress().hex));
      });
    });
  });
}
