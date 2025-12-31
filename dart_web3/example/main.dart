import 'package:dart_web3/dart_web3.dart';

void main() async {
  print('--- Dart Web3 SDK Comprehensive Example ---');

  // 1. Core Utilities
  final address = EthereumAddress.fromHex('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
  print('Address: ${address.toChecksum((data) => Keccak256.hash(data))}');

  // 2. Crypto & Wallets
  final mnemonic = Bip39.generate();
  print('Mnemonic: ${mnemonic.join(" ")}');
  final wallet = HDWallet.fromMnemonic(mnemonic);
  print('Wallet Address: ${wallet.getAddress()}');

  // 3. RPC Client
  final publicClient = ClientFactory.createPublicClient(
    rpcUrl: 'https://eth.llamarpc.com',
    chain: Chains.ethereum,
  );
  
  try {
    final blockNumber = await publicClient.getBlockNumber();
    print('Current Block: $blockNumber');
  } catch (e) {
    print('RPC Error: $e');
  }

  // 4. Smart Contract (ERC-20)
  final usdc = ERC20Contract(
    address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eb48',
    publicClient: publicClient,
  );
  print('USDC Symbol: ${await usdc.symbol()}');

  // 5. Account Abstraction (ERC-4337)
  final signer = PrivateKeySigner(wallet.getPrivateKey(), 1);
  final smartAccount = SimpleAccount(
    owner: signer,
    factoryAddress: '0x...', // Factory address
  );
  print('Smart Account Address: ${smartAccount.address}');

  // 6. Multi-chain (Solana)
  final solAddress = SolanaAddress.fromBase58('vines1vzrYbzLMRdu58GRt1zx9S6SBBZLRCCmWW9ZSP');
  print('Solana Address: $solAddress');

  print('--- Example Execution Finished ---');
}
