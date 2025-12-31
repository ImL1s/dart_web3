import 'package:dart_web3/dart_web3.dart';

void main() async {
  print('Dart Web3 SDK Example');

  // Core utilities
  final address = EthereumAddress.fromHex('0x1234567890123456789012345678901234567890');
  print('Address: ${address.toChecksum()}');

  // Crypto
  final mnemonic = Mnemonic.generate();
  print('Generated Mnemonic: ${mnemonic.join(" ")}');

  // Clients
  final publicClient = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth.llamarpc.com',
    chain: Chains.ethereum,
  );
  print('Chain ID: ${publicClient.chain.chainId}');

  // NFT Service
  final nftService = NftService(publicClient: publicClient);
  final metadata = await nftService.parseMetadata('ipfs://QmTest');
  print('Parsed Metadata: $metadata');
}
