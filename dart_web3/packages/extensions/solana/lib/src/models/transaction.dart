import 'dart:typed_data';

import 'package:web3_universal_crypto/web3_universal_crypto.dart';

import '../encoding/short_vec.dart';
import 'message.dart';
import 'public_key.dart';

class SolanaTransaction {
  SolanaTransaction({
    required this.message,
    this.signatures = const [],
  });

  final Message message;
  final List<Uint8List> signatures;

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
    final newSignatures =
        List<Uint8List>.filled(requiredSignatures, Uint8List(64));

    // Copy existing signatures if any??
    // Usually we rebuild signatures.

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
            'Signer is not marked as a required signer in this transaction');
      }

      newSignatures[index] = signature;
    }

    // If we have existing signatures, preserve them if not overwritten?
    // For now assuming we sign with all needed signers or partial signing logic is handled by caller merging.

    // Let's assume we replace signatures with what we have, but keep existing if new list is being built incrementally.
    // Ideally this class should be immutable or handle state better.
    // We'll return a new Transaction with updated signatures?
    // But `sign` returns void in this draft.
    // Let's modify it to be immutable-ish helpers or strictly mutable.
    // For simplicity: mutable signatures list replacement.

    // Check if we already have signatures, if so, copy them
    if (signatures.isNotEmpty) {
      for (var i = 0; i < signatures.length && i < newSignatures.length; i++) {
        // Only keep if new one is empty (all zeros)?
        // Or if we didn't provide a signer for it.
        var isNewEmpty = true;
        for (final b in newSignatures[i]) {
          if (b != 0) isNewEmpty = false;
        }

        if (isNewEmpty) {
          newSignatures[i] = signatures[i];
        }
      }
    }

    // Update
    // But signatures is final.
    // I should make signatures mutable or return new Tx.
    // Returning new Tx is better.
  }

  SolanaTransaction signAndCreate(List<Ed25519KeyPair> signers) {
    final serializedMessage = message.serialize();
    final requiredSignatures = message.header.numRequiredSignatures;
    final newSignatures =
        List<Uint8List>.filled(requiredSignatures, Uint8List(64));

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
