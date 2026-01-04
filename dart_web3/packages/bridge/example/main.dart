import 'package:web3_universal_bridge/web3_universal_bridge.dart';

void main() async {
  // Initialize bridge service (e.g., Lifi, Stargate)
  final bridge = BridgeService(clients: {});
  print('Bridge service initialized: $bridge');
}
