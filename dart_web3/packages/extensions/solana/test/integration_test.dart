
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_web3_solana/dart_web3_solana.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Solana Mock Integration', () {
    test('getBalance returns correct value', () async {
      final mockClient = MockClient((request) async {
        final jsonBody = jsonDecode(request.body);
        expect(jsonBody['method'], 'getBalance');
        
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'result': {'context': {'slot': 1}, 'value': 123456789},
          'id': jsonBody['id'],
        }), 200,);
      });

      final client = SolanaClient('https://api.devnet.solana.com', httpClient: mockClient);
      final pubKey = PublicKey(Uint8List(32)); // Mock key
      
      final balance = await client.getBalance(pubKey);
      expect(balance, 123456789);
    });

    test('getAccountInfo returns account data', () async {
      final mockClient = MockClient((request) async {
        final jsonBody = jsonDecode(request.body);
        expect(jsonBody['method'], 'getAccountInfo');
        
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'result': {
            'context': {'slot': 1},
            'value': {
              'lamports': 1000,
              'owner': '11111111111111111111111111111111',
              'data': ['AAECAw==', 'base64'], // 00 01 02 03
              'executable': false,
              'rentEpoch': 0,
            },
          },
          'id': jsonBody['id'],
        }), 200,);
      });

      final client = SolanaClient('https://api.devnet.solana.com', httpClient: mockClient);
      final pubKey = PublicKey(Uint8List(32));
      
      final info = await client.getAccountInfo(pubKey);
      expect(info, isNotNull);
      expect(info!.lamports, 1000);
      expect(info.data, equals([0, 1, 2, 3]));
      expect(info.owner.toBase58(), '11111111111111111111111111111111');
    });
  });
}
