import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_staking/web3_universal_staking.dart';

void main() async {
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/key',
    chain: Chains.ethereum,
  );

  // Initialize Staking service
  final staking = StakingService(publicClient: client);
  print('Staking service initialized: $staking');
}
