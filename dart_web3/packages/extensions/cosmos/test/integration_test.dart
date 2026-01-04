import 'dart:convert';
import 'package:web3_universal_cosmos/web3_universal_cosmos.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Cosmos Mock Integration', () {
    test('getBalances returns correct amounts', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path,
            contains('/cosmos/bank/v1beta1/balances/cosmos1address'));

        return http.Response(
          jsonEncode({
            'balances': [
              {'denom': 'uatom', 'amount': '1000000'},
              {'denom': 'stake', 'amount': '500'},
            ],
            'pagination': {'total': '2'},
          }),
          200,
        );
      });

      final client =
          CosmosClient('https://api.cosmos.network', httpClient: mockClient);
      final balances = await client.getBalances('cosmos1address');

      expect(balances.length, 2);
      expect(balances[0].denom, 'uatom');
      expect(balances[0].amount, '1000000');
    });

    test('broadcastTx posts correct data', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/cosmos/tx/v1beta1/txs'));
        expect(request.method, 'POST');

        final body = jsonDecode(request.body);
        expect(body['mode'], 'BROADCAST_MODE_SYNC');
        expect(body['tx_bytes'], isNotNull);

        return http.Response(
          jsonEncode({
            'tx_response': {
              'height': '1234',
              'txhash': 'F6C...GENUINEHASH',
              'code': 0,
              'raw_log': '[]',
            },
          }),
          200,
        );
      });

      final client =
          CosmosClient('https://api.cosmos.network', httpClient: mockClient);

      // Minimal mock Tx
      final tx = CosmosTx(
        body: TxBody(messages: []),
        authInfo:
            AuthInfo(signerInfos: [], fee: Fee(amount: [], gasLimit: 200000)),
        signatures: [],
      );

      final txHash = await client.broadcastTx(tx);
      expect(txHash, 'F6C...GENUINEHASH');
    });
  });
}
