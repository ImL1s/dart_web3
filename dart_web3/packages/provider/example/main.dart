import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() async {
  // Use a fallback provider for resilience
  final provider = FallbackProvider([
    StaticJsonRpcProvider('https://eth-mainnet.g.alchemy.com/v2/key'),
    StaticJsonRpcProvider('https://mainnet.infura.io/v3/key'),
  ]);

  // PublicClient requires a chain configuration. 
  // Since provider package doesn't depend on chains, we might need to add it or create a dummy config if just testing provider logic.
  // But strictly, PublicClient needs it.
  // Assuming we added chains to dev_dependencies? (No, I didn't add it yet).
  // I will assume I need to add chains to provider dev_dependencies or use a mock.
  // Ideally, I add web3_universal_chains to provider dev_dependencies.
  
  // For now, I will use a minimal Chain configuration if I can import ChainConfig.
  // ChainConfig is in core? Yes.
  
  final chain = ChainConfig(
     chainId: 1,
     name: 'Ethereum Mainnet',
     nativeCurrency: NativeCurrency(name: 'Ether', symbol: 'ETH', decimals: 18),
     rpcUrls: ['https://eth-mainnet.g.alchemy.com/v2/key'],
     explorers: [],
  );

  final client = PublicClient(provider: provider, chain: chain);

  try {
    final block = await client.getBlockNumber();
    print('Block via fallback: $block');
  } finally {
    await client.dispose();
  }
}
