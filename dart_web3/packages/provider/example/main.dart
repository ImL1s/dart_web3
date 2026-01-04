import 'package:web3_universal_provider/web3_universal_provider.dart';

void main() async {
  // Create an HTTP transport
  final transport = HttpTransport(
    'https://eth-mainnet.g.alchemy.com/v2/your-api-key',
    headers: {'Content-Type': 'application/json'},
  );

  // Send a raw request
  // final blockNumber = await transport.request(
  //   method: 'eth_blockNumber',
  //   params: [],
  // );

  print('Transport initialized: $transport');
}
