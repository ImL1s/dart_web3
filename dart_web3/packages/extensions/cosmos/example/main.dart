import 'package:web3_universal_cosmos/web3_universal_cosmos.dart';

void main() async {
  print('--- Web3 Universal Cosmos Example ---');

  // 1. Cosmos Address Generation
  const addressStr = 'cosmos1qypqxpqxpqxpqxpqxpqxpqxpqxpqxpqxpq';
  final address = CosmosAddress.fromString(addressStr);
  print('Parsed Address: ${address.address}');

  // 2. Client Interaction (Mock URL example)
  final client = CosmosClient('https://rest.cosmos.directory/cosmoshub');
  print('Ready to query bank balances and broadcast transactions...');

  // 3. Message Building
  final sendMsg = MsgSend(
    fromAddress: addressStr,
    toAddress: 'cosmos1...',
    amount: [
      Coin(denom: 'uatom', amount: '1000000'), // 1 ATOM
    ],
  );
  print('Created MsgSend for ${sendMsg.amount[0].amount} ${sendMsg.amount[0].denom}');
}
