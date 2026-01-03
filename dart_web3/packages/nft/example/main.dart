import 'package:web3_universal_nft/web3_universal_nft.dart';

void main() async {
  // Initialize NFT service
  final nftService = NftService();

  // Fetch NFT metadata
  // final metadata = await nftService.getMetadata(
  //   address: '0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d', // BAYC
  //   tokenId: '1',
  // );

  print('NFT service initialized');
}
