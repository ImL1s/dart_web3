
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:web3_wallet_app/core/services/rpc_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late RpcService rpcService;
  late MockHttpClient mockHttpClient;
  final uri = Uri.parse('https://example.com/rpc');

  setUp(() {
    mockHttpClient = MockHttpClient();
    // Register fallback value for Uri if needed
    registerFallbackValue(Uri());
    
    // Inject mock client into the service
    // Note: RpcService might need refactoring to accept a client via DI.
    // Assuming we can modify RpcService or use an override if supported.
    // For now, testing the logic assuming we can inject or mocking behavior if RpcService allows.
    // If RpcService uses a static client or internal client, we might need to adjust.
    // Let's assume for this test we are testing the public API and logic.
    
    // Actually, looking at typical RpcService implementations, they often create their own client.
    // If RpcService doesn't accept a client, we can't easily mock it without changes.
    // Let's create the test assuming dependency injection principle or we'll modify RpcService next.
    rpcService = RpcService('https://example.com/rpc', client: mockHttpClient);
  });

  group('RpcService', () {
    test('call returns result on success', () async {
      final responseBody = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'result': '0x123',
      });

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await rpcService.call('eth_blockNumber', []);

      expect(result, '0x123');
      verify(() => mockHttpClient.post(uri, headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
    });

    test('call throws exception on HTTP error', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      expect(
        () => rpcService.call('eth_blockNumber', []),
        throwsException,
      );
    });

    test('call throws exception on RPC error', () async {
      final responseBody = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32601, 'message': 'Method not found'},
      });

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(responseBody, 200));

      expect(
        () => rpcService.call('eth_blockNumber', []),
        throwsException,
      );
    });

    test('getBalance returns BigInt', () async {
       final responseBody = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'result': '0x100', // 256 in hex
      });

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(responseBody, 200));

      final balance = await rpcService.getBalance('0xAddress');
      expect(balance, BigInt.from(256));
    });
  });
}
