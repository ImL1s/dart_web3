import 'package:web3_universal_swap/web3_universal_swap.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';

void main() async {
  // 1. Initialize Wallet
  final walletClient = ClientFactory.createWalletClient(
    signer: PrivateKeySigner.createRandom(1),
    chain: Chains.ethereum,
    rpcUrl: 'https://eth.llamarpc.com',
  );

  // Initialize swap service
  final swap = SwapService(walletClient: walletClient);

  // Find the best swap rate
  // final result = await swap.getQuote(
  //   chainId: 1,
  //   fromToken: '0x...',
  //   toToken: '0x...',
  //   amount: BigInt.from(1000000),
  // );

  print('Swap service initialized');
}
