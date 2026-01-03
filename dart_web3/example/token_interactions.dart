import 'package:web3_universal/web3_universal.dart';

void main() async {
  print('--- ERC-20 Token Interactions ---');

  // Setup client for Polygon (fast and cheap for testing)
  final publicClient = ClientFactory.createPublicClient(
    rpcUrl: 'https://polygon-rpc.com',
    chain: Chains.polygon,
  );

  // Example: USDC on Polygon
  const usdcAddress = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  const myAddress = '0x0000000000000000000000000000000000000000'; // Replace with real address

  // 1. Initialize Contract Instance
  final usdc = ERC20Contract(
    address: usdcAddress,
    publicClient: publicClient,
  );

  try {
    // 2. Read Basic Info
    final name = await usdc.name();
    final symbol = await usdc.symbol();
    final decimals = await usdc.decimals();
    print('Token: $name ($symbol)');

    // 3. Check Balance
    final balance = await usdc.balanceOf(myAddress);
    final formattedBalance = EthUnit.formatUnit(balance, decimals);
    print('Balance of $myAddress: $formattedBalance $symbol');

    // 4. Prepare a Transfer (Simulated/Ready to sign)
    // In a real app, you would use a WalletClient
    /*
    final signer = PrivateKeySigner.fromHex('YOUR_PRIVATE_KEY', Chains.polygon.chainId);
    final walletClient = ClientFactory.createWalletClient(
      rpcUrl: '...',
      chain: Chains.polygon,
      signer: signer,
    );
    
    final txHash = await usdc.transfer(
      to: '0xRecipient...',
      amount: EthUnit.parseUnit('10.5', decimals), // 10.5 USDC
      walletClient: walletClient,
    );
    print('Transfer TX: $txHash');
    */
    
    print('\nUse a WalletClient to execute transfers on-chain.');

  } catch (e) {
    print('Error: $e');
  }
}
