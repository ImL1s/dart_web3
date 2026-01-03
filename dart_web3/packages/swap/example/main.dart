import 'package:web3_universal_swap/web3_universal_swap.dart';

void main() async {
  // Initialize swap aggregator (e.g., 1inch, Kyber)
  final swap = SwapService.oneInch(apiKey: 'YOUR_API_KEY');

  // Find the best swap rate
  // final result = await swap.getQuote(
  //   chainId: 1,
  //   fromToken: '0x...',
  //   toToken: '0x...',
  //   amount: BigInt.from(1000000),
  // );

  print('Swap service initialized');
}
