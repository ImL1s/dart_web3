import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'package:web3_universal_client/web3_universal_client.dart';

void main() async {
  // Use a fallback provider for resilience
  final provider = FallbackProvider([
    StaticJsonRpcProvider('https://eth-mainnet.g.alchemy.com/v2/key'),
    StaticJsonRpcProvider('https://mainnet.infura.io/v3/key'),
  ]);

  final client = Web3Client.fromProvider(provider);

  try {
    final block = await client.getBlockNumber();
    print('Block via fallback: $block');
  } finally {
    await client.dispose();
  }
}
