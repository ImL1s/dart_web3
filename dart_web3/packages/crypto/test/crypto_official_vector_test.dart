import 'dart:convert';
import 'dart:io';

import 'package:dart_web3_crypto/dart_web3_crypto.dart';
import 'package:dart_web3_core/dart_web3_core.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Official Crypto Test Vectors', () {
    
    group('BIP39 (Mnemonic to Seed)', () {
      final vectorsJson = File(p.join('test', 'vectors', 'bip39_vectors.json')).readAsStringSync();
      final List<dynamic> vectors = jsonDecode(vectorsJson);

      for (var i = 0; i < vectors.length; i++) {
        final vector = vectors[i];
        final mnemonic = vector['mnemonic'] as String;
        final passphrase = vector['passphrase'] as String;
        final expectedSeedHex = vector['seed'] as String;

        test('Vector #$i', () {
          final seed = Bip39.toSeed(mnemonic.split(' '), passphrase: passphrase);
          expect(HexUtils.encode(seed, prefix: false), equals(expectedSeedHex));
        });
      }
    });

    // Placeholder for BIP32 if added
  });
}
