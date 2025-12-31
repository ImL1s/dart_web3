import 'dart:typed_data';
import 'package:dart_web3_core/dart_web3_core.dart';

/// Solana address (Base58 encoded)
class SolanaAddress {
  final Uint8List bytes;

  const SolanaAddress(this.bytes);

  factory SolanaAddress.fromBase58(String address) {
    // In a real implementation, we'd use a Base58 library
    // For now, we simulate with 32 bytes
    return SolanaAddress(Uint8List(32));
  }

  String toBase58() {
    // Placeholder
    return 'SolanaAddressPlaceholder';
  }

  @override
  String toString() => toBase58();
}

/// Solana Instruction
class SolanaInstruction {
  final SolanaAddress programId;
  final List<SolanaAccountMeta> keys;
  final Uint8List data;

  const SolanaInstruction({
    required this.programId,
    required this.keys,
    required this.data,
  });
}

class SolanaAccountMeta {
  final SolanaAddress pubkey;
  final bool isSigner;
  final bool isWritable;

  const SolanaAccountMeta({
    required this.pubkey,
    required this.isSigner,
    required this.isWritable,
  });
}
