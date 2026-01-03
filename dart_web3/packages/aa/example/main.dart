import 'package:web3_universal_aa/web3_universal_aa.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_chains/web3_universal_chains.dart';

void main() async {
  final owner = PrivateKeySigner.createRandom(11155111); // Sepolia chain ID
  final client = ClientFactory.createPublicClient(
      rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/key',
      chain: Chains.sepolia,
  );
  
  // Initialize an Account Abstraction provider (e.g., Safe, Kernel)
  final smartAccount = SimpleSmartAccount(
    client: client,
    owner: owner,
    entryPoint: EthereumAddress.fromHex('0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'),
    factoryAddress: EthereumAddress.fromHex('0x9406Cc6185a346906296840746125a0E44976454'),
  );

  final address = await smartAccount.getAddress();
  print('Smart Account Address: $address');

  // Send a UserOperation
  // final userOp = await smartAccount.createUnsignedUserOp([
  //   Call(to: recipient, value: amount, data: data)
  // ]);
}
