import 'package:web3_universal_solana/web3_universal_solana.dart';

void main() async {
  print('--- Web3 Universal Solana Example ---');

  // 1. PublicKey & PDA Derivation
  final programId = PublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');
  final seeds = [
    PublicKey.fromBase58('9v88s2pJw47uL7zW2s6S6S6S6S6S6S6S6S6S6S6S').toBytes(),
  ];
  final pda = PublicKey.findProgramAddress(seeds, programId);
  print('Derived PDA: ${pda.address.toBase58()} with bump ${pda.bump}');

  // 2. Client Interaction (Mock URL example)
  final _ = SolanaClient('https://api.devnet.solana.com');
  
  // Note: These would normally be awaited in a real network environment
  print('Ready to fetch account info and broadcast transactions...');

  // 3. Instruction Building
  final transferInstruction = SystemProgram.transfer(
    fromPublicKey: PublicKey.fromBase58('H78F6J6vM...'),
    toPublicKey: PublicKey.fromBase58('H78F6J6vM...'),
    lamports: 1000000, // 0.001 SOL
  );
  print('Created transfer instruction for ${transferInstruction.programId.toBase58()}');
}
