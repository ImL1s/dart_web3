import 'package:dart_web3_compat/dart_web3_compat.dart';
import 'package:test/test.dart';
import 'dart:math';
import 'dart:typed_data';

void main() {
  group('Wallet Compatibility', () {
    final seed = Uint8List.fromList(List.generate(32, (i) => i));
    final credentials = EthPrivateKey(seed);
    final password = 'password123';
    final random = Random.secure();

    test('Round-trip Wallet (Scrypt)', () async {
      final json =
          await Wallet.createNew(credentials, password, random, n: 1024);
      expect(json, contains('scrypt'));

      final wallet = await Wallet.fromJson(json, password);
      expect(wallet.privateKey.address.hex, credentials.address.hex);
      expect(wallet.privateKey.privateKey, credentials.privateKey);
    });

    test('Round-trip Wallet (PBKDF2)', () async {
      final json = await Wallet.createNew(credentials, password, random,
          useScrypt: false);
      expect(json, contains('pbkdf2'));

      final wallet = await Wallet.fromJson(json, password);
      expect(wallet.privateKey.address.hex, credentials.address.hex);
    });

    test('toJson and fromJson consistency', () async {
      final wallet = await Wallet.fromJson(
          await Wallet.createNew(credentials, password, random, n: 1024),
          password);

      final secondJson = await wallet.toJson(password);
      final secondWallet = await Wallet.fromJson(secondJson, password);

      expect(
          secondWallet.privateKey.address.hex, wallet.privateKey.address.hex);
    });
  });
}
