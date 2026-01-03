import 'package:web3_universal_ens/web3_universal_ens.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_chains/web3_universal_chains.dart';

void main() async {
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/key',
    chain: Chains.mainnet,
  );
  final ens = ENSClient(client: client);

  // Resolve name to address
  final address = await ens.resolveName('vitalik.eth');
  print('vitalik.eth: $address');

  // Reverse resolve address to name
  final name = await ens.resolveAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
  print('Name for 0xd8da...: $name');
}
