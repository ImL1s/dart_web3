import 'dart:typed_data';

import 'package:web3_universal_crypto/web3_universal_crypto.dart';
import 'package:web3_universal_solana/web3_universal_solana.dart';
import 'package:test/test.dart';

void main() {
  group('Solana Models', () {
    test('PublicKey from base58', () {
      final key = PublicKey.fromString('11111111111111111111111111111111');
      expect(key.bytes, equals(Uint8List(32)));
      expect(key.toBase58(), equals('11111111111111111111111111111111'));
    });

    test('Message compilation and serialization', () {
      final payer = PublicKey(Uint8List(32)..[0] = 1); // Mock payer key
      final programId = PublicKey(Uint8List(32)..[0] = 2); // Mock program
      final account1 = PublicKey(Uint8List(32)..[0] = 3);

      final ix = TransactionInstruction(
        programId: programId,
        keys: [
          AccountMeta.writable(account1),
        ],
        data: Uint8List.fromList([1, 2, 3]),
      );

      final message = Message.compile(
        instructions: [ix],
        payer: payer,
        recentBlockhash: '11111111111111111111111111111111',
      );

      // Verify accounts order: Payer (Signer, Writable) -> Account1 (Writable) -> ProgramId (Readonly)
      expect(message.accountKeys.length, equals(3));
      expect(message.accountKeys[0], equals(payer));

      // Serialize
      final bytes = message.serialize();
      expect(bytes.length, greaterThan(0));
    });

    test('Transaction signing', () {
      final kp = Ed25519.generateKeyPair();
      final payer = PublicKey(kp.publicKey);

      final message = Message.compile(
        instructions: [],
        payer: payer,
        recentBlockhash: '11111111111111111111111111111111',
      );

      final tx = SolanaTransaction(message: message);
      final signedTx = tx.signAndCreate([kp]);

      expect(signedTx.signatures.length, equals(1));

      // Verify signature
      final isValid = Ed25519()
          .verify(signedTx.signatures[0], message.serialize(), kp.publicKey);
      expect(isValid, isTrue);
    });
  });
}
