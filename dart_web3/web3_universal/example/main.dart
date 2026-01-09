import 'package:web3_universal/web3_universal.dart';
import 'package:web3_universal_solana/web3_universal_solana.dart';

void main() async {
  print('--- Dart Web3 SDK Comprehensive Example ---');

  // 1. Core Utilities
  final address = EthereumAddress.fromHex(
    '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
  );
  print('Address: ${address.toChecksum(Keccak256.hash)}');

  // 2. Crypto & Wallets
  // Note: Using hardcoded key for demo as full BIP39 wordlist is truncated in MVP source
  // final mnemonic = Bip39.generate();
  // print('Mnemonic: ${mnemonic.join(" ")}');
  // final wallet = HDWallet.fromMnemonic(mnemonic);

  final privateKeyHex =
      '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
  final signer = PrivateKeySigner.fromHex(privateKeyHex, 1);
  print('Wallet Address: ${signer.address}');

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
  try {
    print('USDC Symbol: ${await usdc.symbol()}');
  } catch (e) {
    print('Contract Error: $e');
  }

  // 5. Account Abstraction (ERC-4337)
  // final signer = PrivateKeySigner(wallet.getPrivateKey(), 1); // Already created above
  final smartAccount = SimpleAccount(
    owner: signer,
    factoryAddress:
        '0x9406Cc6185a346906296840746125a0E44976454', // SimpleAccountFactory
    publicClient: publicClient,
    entryPointAddress:
        '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789', // EntryPoint v0.6
  );
  print('Smart Account Address: ${await smartAccount.getAddress()}');

  // 6. Multi-chain (Solana)
  final solAddress = PublicKey.fromBase58(
    'vines1vzrYbzLMRdu58GRt1zx9S6SBBZLRCCmWW9ZSP',
  );
  print('Solana Address: $solAddress');

  print('--- Example Execution Finished ---');
}
