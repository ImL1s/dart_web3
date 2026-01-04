import 'package:web3_universal_multicall/web3_universal_multicall.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() async {
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/key',
    chain: Chains.ethereum,
  );
  
  final multicall = Multicall(
    publicClient: client,
    contractAddress: '0xcA11bde05977b3631167028862bE2a173976CA11',
  );

  // Batch multiple contract calls
  // final results = await multicall.aggregate([
  //   contract1.function('balanceOf').call([address1]),
  //   contract2.function('totalSupply').call([]),
  // ]);
  
  print('Multicall initialized: $multicall');
}
