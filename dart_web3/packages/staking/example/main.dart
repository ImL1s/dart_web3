import 'package:web3_universal_staking/web3_universal_staking.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_chains/web3_universal_chains.dart';

void main() async {
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/key',
    chain: Chains.ethereum,
  );

  // Initialize Staking service
  final staking = StakingService(publicClient: client);

  // Get staking APR
  // final apr = await staking.getApr();
  // print('Lido APR: $apr%');

}
