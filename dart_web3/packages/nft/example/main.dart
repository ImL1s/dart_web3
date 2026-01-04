import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_nft/web3_universal_nft.dart';

void main() async {
  // 1. Initialize Public Client
  final publicClient = ClientFactory.createPublicClient(
    chain: Chains.ethereum,
    rpcUrl: 'https://eth.llamarpc.com',
  );

  // 2. Initialize NFT service
  final nftService = NftService(publicClient: publicClient);
  print('NFT service initialized: $nftService');
}
