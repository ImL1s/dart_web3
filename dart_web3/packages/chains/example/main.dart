import 'package:web3_universal_chains/web3_universal_chains.dart';

void main() {
  // Access chain configurations
  final ethereum = Chains.ethereum;
  print('Ethereum Chain ID: ${ethereum.chainId}');
  print('Ethereum Native Currency: ${ethereum.symbol}');

  final sepolia = Chains.sepolia;
  print('Sepolia Native Currency: ${sepolia.symbol}');

  // List all supported chains
  print('Supported chains: ${Chains.getAllChains().length}');
}
