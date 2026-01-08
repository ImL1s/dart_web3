/// Cosmos blockchain integration tests.
///
/// Tests the Cosmos extension package with mock HTTP responses.
@TestOn('vm')
library;

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

    test('getAccount returns account details', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/cosmos/auth/v1beta1/accounts/'));

        return http.Response(
          jsonEncode({
            'account': {
              '@type': '/cosmos.auth.v1beta1.BaseAccount',
              'address': 'cosmos1test',
              'account_number': '12345',
              'sequence': '42',
            },
          }),
          200,
        );
      });

      final client =
          CosmosClient('https://api.cosmos.network', httpClient: mockClient);
      final account = await client.getAccount('cosmos1test');

      expect(account.address, 'cosmos1test');
      expect(account.accountNumber, 12345);
      expect(account.sequence, 42);
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
              'txhash': 'F6C123GENUINEHASH',
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
      expect(txHash, 'F6C123GENUINEHASH');
    });
  });

  group('CosmosAddress', () {
    test('creates from string', () {
      final address = CosmosAddress.fromString(
        'cosmos1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqnrql8a',
      );
      expect(address.hrp, 'cosmos');
    });

    test('creates from string with different hrp', () {
      final address = CosmosAddress.fromString(
        'osmo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqmcn030',
      );
      expect(address.hrp, 'osmo');
    });

    test('converts to string', () {
      final address = CosmosAddress.fromString(
        'cosmos1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqnrql8a',
      );
      expect(address.toString(), startsWith('cosmos1'));
    });

    test('throws on invalid address', () {
      expect(
        () => CosmosAddress.fromString('invalid'),
        throwsException,
      );
    });

    test('throws on empty address', () {
      expect(
        () => CosmosAddress.fromString(''),
        throwsException,
      );
    });
  });

  group('Coin', () {
    test('creates with denom and amount', () {
      final coin = Coin(denom: 'uatom', amount: '1000000');
      expect(coin.denom, 'uatom');
      expect(coin.amount, '1000000');
    });

    test('toProto returns valid protobuf', () {
      final coin = Coin(denom: 'uatom', amount: '1000000');
      final proto = coin.toProto();
      expect(proto.toBytes(), isNotEmpty);
    });
  });

  group('Fee', () {
    test('creates with amount and gas limit', () {
      final fee = Fee(
        amount: [Coin(denom: 'uatom', amount: '5000')],
        gasLimit: 200000,
      );
      expect(fee.gasLimit, 200000);
      expect(fee.amount.length, 1);
    });

    test('creates with multiple coins', () {
      final fee = Fee(
        amount: [
          Coin(denom: 'uatom', amount: '5000'),
          Coin(denom: 'uosmo', amount: '3000'),
        ],
        gasLimit: 400000,
      );
      expect(fee.amount.length, 2);
    });

    test('toProto returns valid protobuf', () {
      final fee = Fee(
        amount: [Coin(denom: 'uatom', amount: '5000')],
        gasLimit: 200000,
      );
      final proto = fee.toProto();
      expect(proto.toBytes(), isNotEmpty);
    });
  });

  group('MsgSend', () {
    test('creates with addresses and amount', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      expect(msg.fromAddress, 'cosmos1sender');
      expect(msg.toAddress, 'cosmos1receiver');
      expect(msg.amount.length, 1);
    });

    test('toAny returns correct type URL', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final any = msg.toAny();
      expect(any.typeUrl, '/cosmos.bank.v1beta1.MsgSend');
    });

    test('creates with multiple coins', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [
          Coin(denom: 'uatom', amount: '1000000'),
          Coin(denom: 'uosmo', amount: '500000'),
        ],
      );
      expect(msg.amount.length, 2);
    });
  });

  group('TxBody', () {
    test('creates with messages', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final body = TxBody(messages: [msg.toAny()]);
      expect(body.messages.length, 1);
    });

    test('creates with memo', () {
      final body = TxBody(
        messages: [],
        memo: 'test memo',
      );
      expect(body.memo, 'test memo');
    });

    test('creates with timeout height', () {
      final body = TxBody(
        messages: [],
        timeoutHeight: 1000000,
      );
      expect(body.timeoutHeight, 1000000);
    });

    test('toBytes returns valid protobuf', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final body = TxBody(messages: [msg.toAny()]);
      expect(body.toBytes(), isNotEmpty);
    });
  });

  group('AuthInfo', () {
    test('creates with signer infos and fee', () {
      final authInfo = AuthInfo(
        signerInfos: [],
        fee: Fee(amount: [], gasLimit: 200000),
      );
      expect(authInfo.signerInfos, isEmpty);
      expect(authInfo.fee.gasLimit, 200000);
    });

    test('toBytes returns valid protobuf', () {
      final authInfo = AuthInfo(
        signerInfos: [],
        fee: Fee(amount: [], gasLimit: 200000),
      );
      expect(authInfo.toBytes(), isNotEmpty);
    });
  });

  group('CosmosTx', () {
    test('creates complete transaction', () {
      final tx = CosmosTx(
        body: TxBody(messages: []),
        authInfo: AuthInfo(
          signerInfos: [],
          fee: Fee(amount: [], gasLimit: 200000),
        ),
        signatures: [],
      );
      expect(tx.body, isNotNull);
      expect(tx.authInfo, isNotNull);
    });

    test('serialize returns valid bytes', () {
      final tx = CosmosTx(
        body: TxBody(messages: []),
        authInfo: AuthInfo(
          signerInfos: [],
          fee: Fee(amount: [], gasLimit: 200000),
        ),
        signatures: [],
      );
      final bytes = tx.serialize();
      expect(bytes, isNotEmpty);
    });
  });

  group('SignDoc', () {
    test('creates with required fields', () {
      final signDoc = SignDoc(
        bodyBytes: TxBody(messages: []).toBytes(),
        authInfoBytes: AuthInfo(
          signerInfos: [],
          fee: Fee(amount: [], gasLimit: 200000),
        ).toBytes(),
        chainId: 'cosmoshub-4',
        accountNumber: 12345,
      );
      expect(signDoc.chainId, 'cosmoshub-4');
      expect(signDoc.accountNumber, 12345);
    });

    test('serialize returns valid bytes', () {
      final signDoc = SignDoc(
        bodyBytes: TxBody(messages: []).toBytes(),
        authInfoBytes: AuthInfo(
          signerInfos: [],
          fee: Fee(amount: [], gasLimit: 200000),
        ).toBytes(),
        chainId: 'cosmoshub-4',
        accountNumber: 12345,
      );
      final bytes = signDoc.serialize();
      expect(bytes, isNotEmpty);
    });
  });

  group('GoogleAny', () {
    test('creates with type URL and value', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final any = msg.toAny();
      expect(any.typeUrl, '/cosmos.bank.v1beta1.MsgSend');
      expect(any.value, isNotEmpty);
    });

    test('toProto returns valid protobuf', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final any = msg.toAny();
      final proto = any.toProto();
      expect(proto.toBytes(), isNotEmpty);
    });
  });

  group('SignerInfo', () {
    test('creates with required fields', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final info = SignerInfo(
        publicKey: msg.toAny(),
        modeInfo: ModeInfo.single(1),
        sequence: 0,
      );
      expect(info.sequence, 0);
    });

    test('toProto returns valid protobuf', () {
      final msg = MsgSend(
        fromAddress: 'cosmos1sender',
        toAddress: 'cosmos1receiver',
        amount: [Coin(denom: 'uatom', amount: '1000000')],
      );
      final info = SignerInfo(
        publicKey: msg.toAny(),
        modeInfo: ModeInfo.single(1),
        sequence: 42,
      );
      final proto = info.toProto();
      expect(proto.toBytes(), isNotEmpty);
    });
  });

  group('ModeInfo', () {
    test('creates single mode', () {
      final mode = ModeInfo.single(1);
      expect(mode.singleMode, 1);
    });

    test('toProto returns valid protobuf', () {
      final mode = ModeInfo.single(1);
      final proto = mode.toProto();
      expect(proto.toBytes(), isNotEmpty);
    });
  });

  group('Error Handling', () {
    test('getBalances throws on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "not found"}', 404);
      });

      final client =
          CosmosClient('https://api.cosmos.network', httpClient: mockClient);

      expect(
        () => client.getBalances('cosmos1notfound'),
        throwsException,
      );
    });

    test('getAccount throws on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "not found"}', 404);
      });

      final client =
          CosmosClient('https://api.cosmos.network', httpClient: mockClient);

      expect(
        () => client.getAccount('cosmos1notfound'),
        throwsException,
      );
    });

    test('broadcastTx throws on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "broadcast failed"}', 500);
      });

      final client =
          CosmosClient('https://api.cosmos.network', httpClient: mockClient);

      final tx = CosmosTx(
        body: TxBody(messages: []),
        authInfo: AuthInfo(
          signerInfos: [],
          fee: Fee(amount: [], gasLimit: 200000),
        ),
        signatures: [],
      );

      expect(
        () => client.broadcastTx(tx),
        throwsException,
      );
    });
  });
}
