import 'dart:typed_data';
import 'solana_types.dart';

/// Solana Transaction
class SolanaTransaction {
  final List<String> signatures;
  final Message message;

  const SolanaTransaction({
    required this.signatures,
    required this.message,
  });

  Uint8List serialize() {
    // Serialization logic for Solana wire format
    return Uint8List(0);
  }
}

class Message {
  final List<SolanaAddress> accountKeys;
  final String recentBlockhash;
  final List<SolanaInstruction> instructions;

  const Message({
    required this.accountKeys,
    required this.recentBlockhash,
    required this.instructions,
  });
}
