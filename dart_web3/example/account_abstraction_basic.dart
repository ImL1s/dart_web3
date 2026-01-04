import 'package:web3_universal/web3_universal.dart';

void main() async {
  print('--- ERC-4337 Account Abstraction Basics ---');

  // 1. Setup Owner (Standard EOA)
  final ownerSigner = PrivateKeySigner.fromHex(
    '0x0000000000000000000000000000000000000000000000000000000000000001',
    Chains.ethereum.chainId,
  );
  print('Owner Address: ${ownerSigner.address}');

  // 2. Define Smart Account Configuration
  // Using a standard SimpleAccount factory (e.g., from Alchemy or Stackup)
  const factoryAddress = '0x9406Cc6185a346906296840746125a0E44976454';

  // 3. Initialize the Smart Account
  // This calculates the counterfactual address (address before deployment)
  final smartAccount = SimpleAccount(
    owner: ownerSigner,
    factoryAddress: factoryAddress,
    index: BigInt.zero,
  );

  print('Smart Account Address (Counterfactual): ${smartAccount.address}');

  // 4. Setup Bundler Client
  final bundlerClient = BundlerClient(
    rpcUrl: 'https://api.stackup.sh/v1/node/YOUR_API_KEY',
  );

  // 5. Create a UserOperation
  /*
  final userOp = await smartAccount.createUnsignedUserOp(
    callData: smartAccount.encodeExecute(
      to: '0xRecipient...',
      value: EthUnit.ether('0.01'),
      data: Uint8List(0),
    ),
  );

  // 6. Sign and Send
  final signedOp = await smartAccount.signUserOp(userOp);
  final userOpHash = await bundlerClient.sendUserOperation(signedOp);
  print('UserOperation Hash: $userOpHash');
  */

  print('\nDetailed UserOperation construction requires a valid Bundler RPC.');
}
