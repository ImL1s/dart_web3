import 'dart:convert';
import 'package:web3_universal_contract/web3_universal_contract.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_client/web3_universal_client.dart';

void main() async {
  // ERC20 ABI snippet for balancing
  const abi = [
    {
      "constant": true,
      "inputs": [{"name": "_owner", "type": "address"}],
      "name": "balanceOf",
      "outputs": [{"name": "balance", "type": "uint256"}],
      "type": "function"
    }
  ];

  final client = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/your-api-key',
  );
  final contractAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7'; // USDT

  // Initialize the contract
  final contract = Contract(
    address: contractAddress,
    abi: jsonEncode(abi),
    publicClient: client,
  );

  // Prepare the call
  // For typed call we might need TypedContract or similar, 
  // but Contract.read works with function name.
  final vitalik = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

  // Execute call
  final result = await contract.read('balanceOf', [vitalik]);

  print('USDT Balance: ${result.first}');
  
  await client.dispose();
}
