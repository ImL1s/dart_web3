import 'dart:convert';
import 'dart:io';

import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_solana/web3_universal_solana.dart';
import 'package:test/test.dart';

void main() {
  group('Solana Vector Tests', () {
    final vectorsFile = File('test/vectors/solana_tx.json');
    final vectors = json.decode(vectorsFile.readAsStringSync()) as List;

    for (var i = 0; i < vectors.length; i++) {
        final vector = vectors[i] as Map<String, dynamic>;
        final description = vector['description'] as String;

        test('Vector #$i: $description', () {
            final payer = PublicKey.fromString(vector['payer'] as String);
            final recentBlockhash = vector['recentBlockhash'] as String;
            final instructionsList = vector['instructions'] as List;
            
            final instructions = instructionsList.map((ix) {
                final ixMap = ix as Map<String, dynamic>;
                final programId = PublicKey.fromString(ixMap['programId'] as String);
                final keysList = ixMap['keys'] as List;
                
                final keys = keysList.map((k) {
                    final kMap = k as Map<String, dynamic>;
                    return AccountMeta(
                        publicKey: PublicKey.fromString(kMap['pubkey'] as String),
                        isSigner: kMap['isSigner'] as bool,
                        isWritable: kMap['isWritable'] as bool,
                    );
                }).toList();
                final data = HexUtils.decode(ixMap['data'] as String);
                
                return TransactionInstruction(
                    programId: programId,
                    keys: keys,
                    data: data,
                );
            }).toList();

            final message = Message.compile(
                instructions: instructions,
                payer: payer,
                recentBlockhash: recentBlockhash,
            );

            final serialized = message.serialize();
            
            final expectedHeaderHex = vector['serializedHeader'] as String;
            final actualHeaderHex = HexUtils.encode(serialized.sublist(0, 3), prefix: false);
            expect(actualHeaderHex, equals(expectedHeaderHex), reason: 'Header mismatch');

            if (vector.containsKey('hex')) {
                expect(HexUtils.encode(serialized, prefix: false), equals(vector['hex'] as String));
            }
        });
    }

    group('Borsh Encoding Vectors', () {
        test('PublicKey Borsh Serialization', () {
            final pubKey = PublicKey.fromString('4u68Abtp6YF34T8uKktS9kFidQByx2hTFYJb5yF8KPBn');
            // Borsh for PublicKey is just the 32 bytes
            expect(pubKey.bytes.length, equals(32));
        });
    });
  });
}
