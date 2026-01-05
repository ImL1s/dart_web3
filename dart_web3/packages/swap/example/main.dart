import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_signer/web3_universal_signer.dart';
import 'package:web3_universal_swap/web3_universal_swap.dart';

void main() async {
  // 1. Initialize Wallet
  final walletClient = ClientFactory.createWalletClient(
    signer: PrivateKeySigner.createRandom(1),
    chain: Chains.ethereum,
    rpcUrl: 'https://eth.llamarpc.com',
  );

  // Initialize swap service
  final swap = SwapService(walletClient: walletClient);
  print('Swap service initialized: $swap');
}
