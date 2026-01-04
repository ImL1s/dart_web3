import 'dart:convert';
import 'package:web3_universal_abi/web3_universal_abi.dart';
import 'package:web3_universal_chains/web3_universal_chains.dart';
import 'package:web3_universal_client/web3_universal_client.dart';
import 'package:web3_universal_core/web3_universal_core.dart';
import 'package:web3_universal_provider/web3_universal_provider.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockTransport implements Transport {
  MockTransport();
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> request(
      String method, List<dynamic> params) async {
    callCount++;

    if (method == 'eth_call') {
      if (callCount == 1) {
        // Return OffchainLookup error
        // OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData)
        final sender = '0x1234567890123456789012345678901234567890';
        final urls = ['https://example.com/{sender}/{data}'];
        final callData = HexUtils.decode('0xabcdef');
        final callbackFunction = HexUtils.decode('0x906165d2');
        final extraData = HexUtils.decode('0x1122');

        final selector = '556f6e30';
        final types = [
          AbiAddress(),
          AbiArray(AbiString()),
          AbiBytes(),
          AbiFixedBytes(4),
          AbiBytes(),
        ];
        final encoded = AbiEncoder.encode(
            types, [sender, urls, callData, callbackFunction, extraData]);
        final errorHex =
            '0x$selector${HexUtils.encode(encoded, prefix: false)}';

        throw RpcError(3, 'execution reverted: OffchainLookup', errorHex);
      } else if (callCount == 2) {
        // Verify it's the callback call
        final callParams = params[0] as Map<String, dynamic>;
        final data = callParams['data'] as String;

        // callbackFunction(0x906165d2) + abi.encode(gatewayResponse(0x778899), extraData(0x1122))
        if (data.startsWith('0x906165d2')) {
          return {'jsonrpc': '2.0', 'id': 2, 'result': '0x445566'};
        }
      }
    }

    return {'jsonrpc': '2.0', 'id': 1, 'result': '0x'};
  }

  @override
  Future<List<Map<String, dynamic>>> batchRequest(
      List<RpcRequest> requests) async {
    return [];
  }

  @override
  void dispose() {}
}

class MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.toString() ==
        'https://example.com/0x1234567890123456789012345678901234567890/abcdef') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(json.encode({'data': '0x778899'}))),
        200,
      );
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }
}

void main() {
  group('CCIP-Read', () {
    test('should handle OffchainLookup correctly', () async {
      final mockTransport = MockTransport();
      final provider = RpcProvider(mockTransport);
      final client = PublicClient(
        provider: provider,
        chain: Chains.ethereum,
      );

      // Inject mock HTTP client
      final handler = CCIPReadHandler(client, httpClient: MockHttpClient());
      client.ccipHandler = handler;

      final result = await client.call(CallRequest(
        to: '0x1234567890123456789012345678901234567890',
        data: HexUtils.decode('0xabcdef'),
      ));

      expect(HexUtils.encode(result), equals('0x445566'));
      expect(mockTransport.callCount, equals(2));
    });
  });
}
