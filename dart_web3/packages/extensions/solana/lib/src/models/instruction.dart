import 'dart:typed_data';

import 'public_key.dart';

class AccountMeta {
  AccountMeta({required this.publicKey, required this.isSigner, required this.isWritable});

  final PublicKey publicKey;
  final bool isSigner;
  final bool isWritable;
  
  static AccountMeta writable(PublicKey publicKey, {bool isSigner = false}) {
      return AccountMeta(publicKey: publicKey, isSigner: isSigner, isWritable: true);
  }
  
  static AccountMeta readonly(PublicKey publicKey, {bool isSigner = false}) {
      return AccountMeta(publicKey: publicKey, isSigner: isSigner, isWritable: false);
  }
}

class TransactionInstruction {
  TransactionInstruction({
    required this.programId,
    required this.keys,
    required this.data,
  });

  final PublicKey programId;
  final List<AccountMeta> keys;
  final Uint8List data;
}
