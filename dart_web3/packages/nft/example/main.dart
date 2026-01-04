import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_nft/web3_universal_nft.dart';

void main() async {
  // 1. Initialize Public Client
  final publicClient = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth.llamarpc.com',
  );

  // 2. Initialize NFT service
  final nftService = NftService(publicClient: publicClient);

  // Fetch NFT metadata
  // final metadata = await nftService.getMetadata(
  //   address: '0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d', // BAYC
  //   tokenId: '1',
  // );

  print('NFT service initialized');
}
