import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';

void main() async {
  // Initialize the Web3 client with an RPC URL
  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/your-api-key',
  );

  try {
    // Get the current block number
    final blockNumber = await client.getBlockNumber();
    print('Current block number: $blockNumber');

    // Get basic network info
    final chainId = await client.getChainId();
    print('Chain ID: $chainId');

    // Get balance of a specific address
    final address = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'; // vitalik.eth
    final balance = await client.getBalance(address);
    print('Balance of $address: ${balance.getValueInUnit(EthUnit.ether)} ETH');
  } finally {
    await client.dispose();
  }
}
