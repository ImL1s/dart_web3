import 'package:web3_universal_multicall/web3_universal_multicall.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_contract/web3_universal_contract.dart';

void main() async {
  final client = Web3Client('https://eth-mainnet.g.alchemy.com/v2/key');
  final multicall = Multicall(client: client);

  // Batch multiple contract calls
  // final results = await multicall.aggregate([
  //   contract1.function('balanceOf').call([address1]),
  //   contract2.function('totalSupply').call([]),
  // ]);
  
  print('Multicall initialized');
}
