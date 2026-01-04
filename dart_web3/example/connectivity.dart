import 'package:web3_universal/web3_universal.dart';

void main() async {
  print('--- Testnet Connectivity Check ---');

  final networks = [
    Chains.ethereum,
    Chains.sepolia,
    Chains.polygon,
    Chains.base,
  ];

  for (final chain in networks) {
    print('Checking ${chain.name} (ID: ${chain.chainId})...');
    final client = ClientFactory.createPublicClient(
      rpcUrl: chain.rpcUrls.first,
      chain: chain,
    );

    try {
      final block = await client.getBlockNumber();
      print('  ✓ Success! Current block: $block');
    } catch (e) {
      print('  ✗ Failed: $e');
    }
  }
}
