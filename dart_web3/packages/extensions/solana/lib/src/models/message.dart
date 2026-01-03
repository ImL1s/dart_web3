import 'dart:typed_data';

import 'package:web3_universal_crypto/web3_universal_crypto.dart';

import '../encoding/short_vec.dart';
import 'instruction.dart';
import 'public_key.dart';

class MessageHeader {
  MessageHeader({
    required this.numRequiredSignatures,
    required this.numReadonlySignedAccounts,
    required this.numReadonlyUnsignedAccounts,
  });

  final int numRequiredSignatures;
  final int numReadonlySignedAccounts;
  final int numReadonlyUnsignedAccounts;

  Uint8List toBytes() {
    return Uint8List.fromList([
      numRequiredSignatures,
      numReadonlySignedAccounts,
      numReadonlyUnsignedAccounts,
    ]);
  }
}

class CompiledInstruction {
  CompiledInstruction({
    required this.programIdIndex,
    required this.accounts,
    required this.data,
  });

  final int programIdIndex;
  final List<int> accounts;
  final Uint8List data;

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.addByte(programIdIndex);
    buffer.add(ShortVec.encodeLength(accounts.length));
    buffer.add(Uint8List.fromList(accounts));
    buffer.add(ShortVec.encodeLength(data.length));
    buffer.add(data);
    return buffer.toBytes();
  }
}

class Message {
  Message({
    required this.header,
    required this.accountKeys,
    required this.recentBlockhash,
    required this.instructions,
  });

  final MessageHeader header;
  final List<PublicKey> accountKeys;
  final String recentBlockhash;
  final List<CompiledInstruction> instructions;

  /// Serialization of the message (the data that gets signed).
  Uint8List serialize() {
    final buffer = BytesBuilder();
    
    // 1. Header
    buffer.add(header.toBytes());

    // 2. Account Keys
    buffer.add(ShortVec.encodeLength(accountKeys.length));
    for (final key in accountKeys) {
      buffer.add(key.bytes);
    }

    // 3. Recent Blockhash
    buffer.add(Base58.decode(recentBlockhash));

    // 4. Instructions
    buffer.add(ShortVec.encodeLength(instructions.length));
    for (final instruction in instructions) {
      buffer.add(instruction.toBytes());
    }

    return buffer.toBytes();
  }

  /// Compile instructions into a Message.
  static Message compile({
    required List<TransactionInstruction> instructions,
    required PublicKey payer,
    required String recentBlockhash,
  }) {
    // 1. Gather all unique accounts
    final accountMap = <PublicKey, AccountMeta>{};
    
    // Payer is always first, signer, writable
    accountMap[payer] = AccountMeta(publicKey: payer, isSigner: true, isWritable: true);

    for (final ix in instructions) {
      // Program ID is readonly unsigned (usually)
      if (!accountMap.containsKey(ix.programId)) {
        accountMap[ix.programId] = AccountMeta(publicKey: ix.programId, isSigner: false, isWritable: false);
      }
      for (final acc in ix.keys) {
        if (accountMap.containsKey(acc.publicKey)) {
          // Merge flags
          final existing = accountMap[acc.publicKey]!;
          accountMap[acc.publicKey] = AccountMeta(
            publicKey: acc.publicKey, 
            isSigner: existing.isSigner || acc.isSigner, 
            isWritable: existing.isWritable || acc.isWritable,
          );
        } else {
          accountMap[acc.publicKey] = acc;
        }
      }
    }

    // 2. Sort accounts:
    // - Signer, Writable
    // - Signer, Readonly
    // - Writable, Not Signer
    // - Readonly, Not Signer (Program IDs usually end up here)
    final writableSigners = <PublicKey>[];
    final readonlySigners = <PublicKey>[];
    final writableNonSigners = <PublicKey>[];
    final readonlyNonSigners = <PublicKey>[];

    for (final entry in accountMap.values) {
        if (entry.isSigner) {
            if (entry.isWritable) {
              writableSigners.add(entry.publicKey);
            } else {
              readonlySigners.add(entry.publicKey);
            }
        } else {
            if (entry.isWritable) {
              writableNonSigners.add(entry.publicKey);
            } else {
              readonlyNonSigners.add(entry.publicKey);
            }
        }
    }

    // Ensure payer is first in writableSigners? 
    // It should be by virtue of being added first if we preserve order, 
    // but standard sort order is by address or just defined by this bucketing? 
    // Solana requires payer to be the first account in the list.
    // Since we added payer first to accountMap, and if we iterate keys...
    // But we are bucketing. Payer is Writable+Signer.
    // We should ensure payer is at index 0.
    if (!writableSigners.contains(payer)) {
        // Should not happen as we added it
        throw Exception('Payer not present');
    }
    // Move payer to front if needed
    writableSigners.remove(payer);
    writableSigners.insert(0, payer);

    final accountKeys = [
        ...writableSigners,
        ...readonlySigners,
        ...writableNonSigners,
        ...readonlyNonSigners,
    ];

    final header = MessageHeader(
        numRequiredSignatures: writableSigners.length + readonlySigners.length,
        numReadonlySignedAccounts: readonlySigners.length,
        numReadonlyUnsignedAccounts: readonlyNonSigners.length,
    );

    // 3. Compile instructions
    final compiledInstructions = instructions.map((ix) {
        final programIdIndex = accountKeys.indexOf(ix.programId); // use indexWhere if == not working on object identity
        // But PublicKey has properly implemented ==
        if (programIdIndex == -1) throw Exception('Program ID not found in account keys');

        final accountIndices = ix.keys.map((acc) {
            final idx = accountKeys.indexOf(acc.publicKey);
            if (idx == -1) throw Exception('Account not found in account keys');
            return idx;
        }).toList();

        return CompiledInstruction(
            programIdIndex: programIdIndex,
            accounts: accountIndices,
            data: ix.data,
        );
    }).toList();

    return Message(
        header: header, 
        accountKeys: accountKeys, 
        recentBlockhash: recentBlockhash, 
        instructions: compiledInstructions,
    );
  }
}
