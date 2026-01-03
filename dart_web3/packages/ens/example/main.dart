import 'package:web3_universal_ens/web3_universal_ens.dart';
import 'package:web3_universal_client/web3_universal_client.dart';

void main() async {
  final client = Web3Client('https://eth-mainnet.g.alchemy.com/v2/key');
  final ens = Ens(client: client);

  // Resolve name to address
  final address = await ens.withName('vitalik.eth').getAddress();
  print('vitalik.eth: $address');

  // Reverse resolve address to name
  final name = await ens.withAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045').getName();
  print('Name for 0xd8da...: $name');
}
