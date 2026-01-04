import 'dart:typed_data';

/// Solana address (Base58 encoded)
class SolanaAddress {
  const SolanaAddress(this.bytes);

  factory SolanaAddress.fromBase58() {
    // In a real implementation, we'd use a Base58 library
    // For now, we simulate with 32 bytes
    return SolanaAddress(Uint8List(32));
  }
  final Uint8List bytes;

  String toBase58() {
    // Placeholder
    return 'SolanaAddressPlaceholder';
  }

  @override
  String toString() => toBase58();
}

/// Solana Instruction
class SolanaInstruction {
  const SolanaInstruction({
    required this.programId,
    required this.keys,
    required this.data,
  });
  final SolanaAddress programId;
  final List<SolanaAccountMeta> keys;
  final Uint8List data;
}

class SolanaAccountMeta {
  const SolanaAccountMeta({
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
  });
  final SolanaAddress pubkey;
  final bool isSigner;
  final bool isWritable;
}
