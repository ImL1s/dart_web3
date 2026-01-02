import 'dart:typed_data';
import 'solana_types.dart';

/// Solana Transaction
class SolanaTransaction {

  const SolanaTransaction({
    required this.signatures,
    required this.message,
  });
  final List<String> signatures;
  final Message message;

  Uint8List serialize() {
    // Serialization logic for Solana wire format
    return Uint8List(0);
  }
}

class Message {

  const Message({
    required this.accountKeys,
    required this.recentBlockhash,
    required this.instructions,
  });
  final List<SolanaAddress> accountKeys;
  final String recentBlockhash;
  final List<SolanaInstruction> instructions;
}
