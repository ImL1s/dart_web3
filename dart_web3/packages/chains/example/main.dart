import 'package:web3_universal_chains/web3_universal_chains.dart';

void main() {
  // Access chain configurations
  final ethereum = Chains.ethereum;
  print('Ethereum Chain ID: ${ethereum.chainId}');
  print('Ethereum Native Currency: ${ethereum.nativeCurrency.symbol}');

  final solana = Chains.solana;
  print('Solana Genesis Hash: ${solana.extra['genesisHash']}');

  // List all supported chains
  print('Supported chains: ${Chains.all.length}');
}
