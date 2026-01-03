import 'package:web3_universal_aa/web3_universal_aa.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:web3_universal_client/web3_universal_client.dart';

void main() async {
  final owner = EthPrivateKey.createRandom();
  final client = Web3Client('https://eth-sepolia.g.alchemy.com/v2/key');
  
  // Initialize an Account Abstraction provider (e.g., Safe, Kernel)
  final smartAccount = SimpleSmartAccount(
    client: client,
    owner: owner,
    entryPoint: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
    factoryAddress: '0x9406Cc6185a346906296840746125a0E44976454',
  );

  final address = await smartAccount.getAddress();
  print('Smart Account Address: $address');

  // Send a UserOperation
  // final userOp = await smartAccount.createUnsignedUserOp([
  //   Call(to: recipient, value: amount, data: data)
  // ]);
}
