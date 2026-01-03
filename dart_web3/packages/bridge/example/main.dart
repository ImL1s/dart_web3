import 'package:web3_universal_bridge/web3_universal_bridge.dart';

void main() async {
  // Initialize bridge service (e.g., Lifi, Stargate)
  final bridge = BridgeService(clients: {});

  // Get a bridge quote
  // final quote = await bridge.getQuote(
  //   fromChain: 1, // Ethereum
  //   toChain: 137, // Polygon
  //   fromToken: '0x...', 
  //   toToken: '0x...',
  //   amount: BigInt.from(1000000),
  // );

  print('Bridge service initialized');
}
