import 'dart:typed_data';

import 'package:web3_universal_crypto/web3_universal_crypto.dart';

import '../encoding/short_vec.dart';
import 'message.dart';
import 'public_key.dart';

class SolanaTransaction {
  SolanaTransaction({required this.message, this.signatures = const []});

  final Message message;
  List<Uint8List> signatures;

  /// Signs the transaction with the given signers.
  ///
  /// The signers must match the order in `message.accountKeys` (the first N accounts are signers).
  /// This method updates [signatures] with new signatures.
  ///
  /// [signers] - List of KeyPairs.
  void sign(List<Ed25519KeyPair> signers) {
    // There must be enough signatures for required signers
    // The message.header.numRequiredSignatures tells us how many
    final serializedMessage = message.serialize();

    // We can populate the signatures list.
    // Usually we start with empty signatures (all zeros) for required signers.
    final requiredSignatures = message.header.numRequiredSignatures;
    final newSignatures = List<Uint8List>.filled(
      requiredSignatures,
      Uint8List(64),
    );

    // Fill with existing if present
    if (signatures.length == requiredSignatures) {
      for (var i = 0; i < requiredSignatures; i++) {
        newSignatures[i] = signatures[i];
      }
    }

    for (final signer in signers) {
      final signature = signer.sign(serializedMessage);

      // Find the index of this signer in accountKeys
      // It must be within the first numRequiredSignatures
      final index = message.accountKeys.indexOf(PublicKey(signer.publicKey));
      if (index == -1) {
        throw Exception('Signer not found in transaction accounts');
      }
      if (index >= requiredSignatures) {
        throw Exception(
          'Signer is not marked as a required signer in this transaction',
        );
      }

      newSignatures[index] = signature;
    }

    signatures = newSignatures;
  }

  SolanaTransaction signAndCreate(List<Ed25519KeyPair> signers) {
    final serializedMessage = message.serialize();
    final requiredSignatures = message.header.numRequiredSignatures;
    final newSignatures = List<Uint8List>.filled(
      requiredSignatures,
      Uint8List(64),
    );

    // Fill with existing if present
    if (signatures.length == requiredSignatures) {
      for (var i = 0; i < requiredSignatures; i++) {
        newSignatures[i] = signatures[i];
      }
    }

    for (final signer in signers) {
      final signature = signer.sign(serializedMessage);
      final index = message.accountKeys.indexOf(PublicKey(signer.publicKey));
      if (index == -1 || index >= requiredSignatures) {
        throw Exception('Invalid signer: ${signer.publicKey}');
      }
      newSignatures[index] = signature;
    }

    return SolanaTransaction(message: message, signatures: newSignatures);
  }

  Uint8List serialize() {
    final buffer = BytesBuilder();

    // 1. Signatures
    buffer.add(ShortVec.encodeLength(signatures.length));
    for (final sig in signatures) {
      buffer.add(sig);
    }

    // 2. Message
    buffer.add(message.serialize());

    return buffer.toBytes();
  }
}
